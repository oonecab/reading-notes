#!/usr/bin/env python3
"""Exercise real filesystem publication, failures, concurrency and HTTP(S) rollback locally."""
import argparse
import fcntl
import hashlib
import gzip
import http.client
import io
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import tarfile
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT/'deploy'), str(ROOT/'books/stochastic/deploy')]
from public_policy import inspect, sums, summary
from build_release import write_archive
from release_support import extract_release


def port():
    with socket.socket() as s:
        s.bind(('127.0.0.1',0))
        return s.getsockname()[1]


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--release-dir',type=Path,required=True)
    a=ap.parse_args()
    parent=ROOT/'tmp/publish-check';parent.mkdir(parents=True,exist_ok=True)
    work=Path(tempfile.mkdtemp(prefix=a.release_dir.name+'-',dir=parent))
    root=work/'srv';root.mkdir()
    evidence={'status':'running','checks':[],'root':str(root.relative_to(ROOT))}
    def passed(name, **extra):
        evidence['checks'].append({'test':name,'status':'passed',**extra})
        (work/'report.json').write_text(json.dumps(evidence,indent=2)+'\n')
    def publish(*args, expected=0, hook=None, target_root=None, crash=None):
        cmd=['bash',str(ROOT/'deploy/scripts/publish.sh'),'--root',str(target_root or root),'--dry-run',*map(str,args)]
        if hook: cmd+=['--service-hook',str(hook)]
        env = {k:v for k,v in os.environ.items() if k != 'READING_NOTES_TEST_CRASH'}
        if crash: env['READING_NOTES_TEST_CRASH']=crash
        result=subprocess.run(cmd,capture_output=True,text=True,env=env)
        with (work/'commands.log').open('a') as f:
            f.write(json.dumps({'command':cmd,'exit_code':result.returncode,'stdout':result.stdout,'stderr':result.stderr})+'\n')
        assert result.returncode==expected,(result.returncode,result.stderr[-2000:])
        return result
    original=json.loads((a.release_dir/'release.json').read_text())
    packages=[]
    for i in range(1,6):
        package=work/f'package-{i}';package.mkdir();packages.append(package)
        meta=json.loads(json.dumps(original));meta['release_id']=f'20990101T00000{i}'
        with tarfile.open(a.release_dir/'site.tar.gz') as archive:
            blobs={m.name:archive.extractfile(m).read() for m in archive.getmembers()}
        blobs['index.html']+=f'\n<!-- publication fixture {i} -->\n'.encode()
        if 'index.html.gz' in blobs: blobs['index.html.gz']=gzip.compress(blobs['index.html'],compresslevel=6,mtime=0)
        meta['files']=[{'path':n,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()} for n,b in sorted(blobs.items())]
        meta['total_bytes']=sum(row['bytes'] for row in meta['files'])
        write_archive(package/'site.tar.gz',blobs)
        meta['archive_sha256']=hashlib.sha256((package/'site.tar.gz').read_bytes()).hexdigest()
        (package/'release.json').write_text(json.dumps(meta))
        (package/'SHA256SUMS').write_text(sums(meta['files']))
    sys.path.insert(0,str(ROOT/'deploy/scripts'))
    from publish_release import verified
    subprocess.run([sys.executable,ROOT/'tools/test_publish_durability.py'],check=True)
    passed('durable file/directory barriers and atomic journal power-cut ordering model')
    for phase in ['unpack','rsync','rename','journal-temp','journal','switch']:
        crash_root=work/('crash-'+phase);crash_root.mkdir()
        publish('--release-dir',packages[0],target_root=crash_root)
        old=os.readlink(crash_root/'current')
        publish('--release-dir',packages[1],target_root=crash_root,crash=phase,expected=-signal.SIGKILL)
        active=os.readlink(crash_root/'current')
        assert active in {old,'releases/20990101T000002'}
        verified(crash_root/active)
        publish('--recover',target_root=crash_root)
        assert os.readlink(crash_root/'current')==old
        verified(crash_root/old)
        publish('--release-dir',packages[2],target_root=crash_root)
        verified(crash_root/os.readlink(crash_root/'current'))
        passed('SIGKILL at '+phase+' preserves a complete current and permits recovery/new publish')
    damaged_root=work/'damaged-journal';damaged_root.mkdir()
    publish('--release-dir',packages[0],target_root=damaged_root)
    journal=damaged_root/'.publish-transaction.json';journal.write_text('{"previous":')
    result=publish('--recover',target_root=damaged_root,expected=2)
    assert 'journal-damaged' in result.stderr and 'Traceback' not in result.stderr
    assert journal.read_text()=='{"previous":' and os.readlink(damaged_root/'current')=='releases/20990101T000001'
    publish('--recover','--restore-release','20990101T000001',target_root=damaged_root)
    assert not journal.exists() and len(list(damaged_root.glob('.publish-transaction.corrupt-*.json')))==1
    publish('--release-dir',packages[1],target_root=damaged_root)
    passed('truncated journal gives read-only diagnosis, controlled repair and unblocked next publication')
    # Independent allowlist failures: injected private path, symlink and raw summary.
    site=work/'policy-site';extract_release(a.release_dir,site)
    bad=site/'review';bad.mkdir();(bad/'private.json').write_text('{}')
    try: inspect(site);raise AssertionError('private path accepted')
    except ValueError: pass
    shutil.rmtree(bad)
    (site/'alias').symlink_to(site/'index.html')
    try: inspect(site);raise AssertionError('symlink accepted')
    except ValueError: pass
    (site/'alias').unlink()
    p=site/'csapp/notes/validation.json';old=p.read_bytes();p.write_text('{"private_baseline":"fixture"}')
    try: inspect(site);raise AssertionError('raw evidence accepted')
    except ValueError: pass
    p.write_bytes(old);inspect(site)
    passed('allowlist rejects private path, symlink and raw review JSON')
    publish('--release-dir',packages[0]);first=os.readlink(root/'current')
    passed('initial immutable release installation')
    publish('--release-dir',packages[0],expected=1)
    assert os.readlink(root/'current')==first
    passed('existing release refused without replacement')
    with (root/'.publish.lock').open('a') as held:
        fcntl.flock(held,fcntl.LOCK_EX|fcntl.LOCK_NB)
        publish('--release-dir',packages[1],expected=75)
    passed('concurrent publisher rejected by real flock')
    # Actual local Nginx with trusted fixed configuration and self-signed test CA.
    nginx=shutil.which('nginx');assert nginx,'Nginx required for this acceptance'
    cert,key=work/'cert.pem',work/'key.pem'
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost',
                    '-addext','subjectAltName=DNS:localhost','-keyout',key,'-out',cert],check=True,capture_output=True)
    key.chmod(0o600);https,http_port=port(),port()
    static=(a.release_dir/'nginx-static.inc').read_text().replace('root /srv/reading-notes/current/site;',f'root "{root}/current/site";')
    (work/'static.inc').write_text(static)
    config=work/'nginx.conf'
    config.write_text(f'''worker_processes 1;
pid "{work}/nginx.pid";
error_log "{work}/error.log";
events {{ worker_connections 128; }}
http {{ access_log "{work}/access.log";
server {{ listen 127.0.0.1:{http_port}; server_name localhost; return 301 https://localhost:{https}$request_uri; }}
server {{ listen 127.0.0.1:{https} ssl; server_name localhost;
ssl_certificate "{cert}"; ssl_certificate_key "{key}"; include "{work}/static.inc"; }} }}
''')
    nginx_args=[nginx,'-p',str(work)+'/', '-c',str(config)]
    subprocess.run([*nginx_args,'-t'],check=True,capture_output=True)
    hook=work/'service-hook.py'
    hook.write_text('#!/usr/bin/env python3\nimport subprocess,sys,json,os\nfrom pathlib import Path\nsys.path.insert(0,'+repr(str(ROOT/'deploy'))+')\nfrom http_checks import probe_release\nos.environ["SSL_CERT_FILE"]='+repr(str(cert))+'\nargs='+repr(nginx_args)+'\nif sys.argv[1]=="health":\n probe_release(json.loads(Path('+repr(str(root/'current/release.json'))+').read_text()),'+repr(f'https://localhost:{https}')+',"127.0.0.1")\nelse:\n raise SystemExit(subprocess.run(args+(["-t"] if sys.argv[1]=="test" else ["-s","reload"])).returncode)\n')
    hook.chmod(0o755)
    log=(work/'process.log').open('w')
    process=subprocess.Popen([*nginx_args,'-g','daemon off;'],stdout=log,stderr=log)
    context=ssl.create_default_context(cafile=str(cert))
    def get(path='/', headers=None):
        c=http.client.HTTPSConnection('localhost',https,context=context,timeout=10)
        c.request('GET',path,headers=headers or {})
        r=c.getresponse();v=(r.status,dict(r.getheaders()),r.read());c.close();return v
    try:
        for _ in range(100):
            try: get();break
            except OSError: time.sleep(.1)
        else: raise AssertionError('Nginx did not start')
        oldhash=hashlib.sha256(get()[2]).hexdigest()
        old_etag=get()[1]['ETag']
        stable='/stochastic/notes/chapter01_markov_chains.html'
        stable_etag=get(stable)[1]['ETag']
        stable_gzip_etag=get(stable,{'Accept-Encoding':'gzip'})[1]['ETag']
        c=http.client.HTTPConnection('127.0.0.1',http_port);c.request('GET','/csapp?proof=1');r=c.getresponse()
        assert r.status==301 and r.getheader('Location')==f'https://localhost:{https}/csapp?proof=1';r.read();c.close()
        status,headers,body=get('/index.html',{'Accept-Encoding':'gzip'})
        assert status==200 and headers.get('Content-Encoding')=='gzip'
        status,headers,body=get('/index.html')
        assert headers.get('ETag') and headers.get('Strict-Transport-Security')=='max-age=31536000'
        assert get('/index.html',{'If-None-Match':headers['ETag']})[0]==304
        for pth in ['/review/a.json','/content/a.html','/tmp/a','/release.json','/SHA256SUMS']:
            assert get(pth)[0]==404,pth
        # An untrusted symlink inside web root is refused by Nginx, including after root's trusted current symlink.
        root.joinpath(first,'site').chmod(0o755)
        alias=root/first/'site'/'untrusted.txt';alias.symlink_to(work/'commands.log')
        assert get('/untrusted.txt')[0] in [403,404]
        alias.unlink();root.joinpath(first,'site').chmod(0o555)
        passed('real Nginx HTTP redirect, HTTPS gzip, ETag 304, HSTS, private paths and symlink refusal')
        stop=threading.Event();observed=[];missing=[]
        def observe():
            while not stop.is_set():
                try: observed.append(os.readlink(root/'current'))
                except OSError as e: missing.append(str(e))
                time.sleep(.0005)
        thread=threading.Thread(target=observe);thread.start()
        try: publish('--release-dir',packages[1],hook=hook)
        finally: stop.set();thread.join()
        second=os.readlink(root/'current')
        assert first!=second and set(observed)<={first,second} and not missing
        secondhash=hashlib.sha256(get()[2]).hexdigest()
        assert secondhash!=oldhash
        assert get('/',{'If-None-Match':old_etag})[0]==200
        assert get(stable,{'If-None-Match':stable_etag})[0]==304
        assert get(stable,{'Accept-Encoding':'gzip','If-None-Match':stable_gzip_etag})[0]==304
        assert json.loads((root/'.last-publish.json').read_text())['origin_health']=='passed'
        passed('unchanged identity/gzip return 304 across releases; same-size changed homepage returns 200')
        passed('atomic switch and actual nginx test/reload',observations=len(observed),missing=missing)
        # Inject one failure, then allow rollback to exercise the actual old config reload.
        for phase,package in [('test',packages[2]),('reload',packages[3]),('health',packages[4])]:
            marker=work/('failed-'+phase)
            failing=work/('fail-'+phase+'.py')
            failing.write_text('#!/usr/bin/env python3\nfrom pathlib import Path\nimport subprocess,sys\np=Path('+repr(str(marker))+')\nif sys.argv[1]=='+repr(phase)+' and not p.exists():\n p.touch();sys.exit(42)\nraise SystemExit(subprocess.run(['+repr(str(hook))+',sys.argv[1]]).returncode)\n')
            failing.chmod(0o755)
            publish('--release-dir',package,hook=failing,expected=1)
            assert os.readlink(root/'current')==second and hashlib.sha256(get()[2]).hexdigest()==secondhash
            assert not (root/'.publish-transaction.json').exists()
            passed('automatic rollback after '+phase+' failure')
        both=work/'fail-both-health.py'
        both.write_text('#!/usr/bin/env python3\nimport subprocess,sys\nif sys.argv[1]=="health":sys.exit(42)\nraise SystemExit(subprocess.run(['+repr(str(hook))+',sys.argv[1]]).returncode)\n')
        both.chmod(0o755)
        publish('--rollback','20990101T000001',hook=both,expected=1)
        assert (root/'.publish-transaction.json').exists() and os.readlink(root/'current')==second
        publish('--recover',hook=hook)
        assert not (root/'.publish-transaction.json').exists() and os.readlink(root/'current')==second
        passed('failed candidate and failed recovery health preserve journal until verified recovery')
        publish('--rollback','20990101T000001',hook=hook)
        assert os.readlink(root/'current')==first and hashlib.sha256(get()[2]).hexdigest()==oldhash
        assert get('/',{'If-None-Match':old_etag})[0]==304
        passed('explicit rollback restores old HTTP body, ETag and symlink')
        (root/'.publish-transaction.json').write_text(json.dumps({'previous':second,'candidate':first}))
        publish('--release-dir',packages[0],expected=1)
        publish('--recover',hook=hook)
        assert os.readlink(root/'current')==second and hashlib.sha256(get()[2]).hexdigest()==secondhash
        publish('--rollback','20990101T000001',hook=hook)
        passed('interrupted transaction blocks new deploy and recovers previous release')
        publish('--rollback','20990101T000002',hook=hook)
        corrupted=root/second/'site/index.html'
        corrupted.chmod(0o644);corrupted.write_bytes(b'corrupted active fixture');corrupted.chmod(0o444)
        publish('--rollback','20990101T000001',hook=hook)
        assert os.readlink(root/'current')==first and hashlib.sha256(get()[2]).hexdigest()==oldhash
        passed('verified rollback remains available after active payload corruption')
        # Full existing verifier runs against installed site, including both PDF byte ranges and 15 old routes.
        env={**os.environ,'SSL_CERT_FILE':str(cert)}
        subprocess.run([sys.executable,ROOT/'deploy/verify_portal.py','--release-dir',packages[0],
                        '--origin',f'https://localhost:{https}','--output',work/'https-verification.json'],check=True,env=env)
        passed('all public file hashes, MIME, CSP, both PDF ranges and old URL/query/HEAD/POST behavior')
        import importlib.util
        sys.path.insert(0,str(ROOT/'deploy/scripts'))
        spec=importlib.util.spec_from_file_location('deploy_job',ROOT/'deploy/scripts/deploy-job.py')
        job=importlib.util.module_from_spec(spec);spec.loader.exec_module(job)
        ready,done=work/'ready',work/'done';ready.mkdir();done.mkdir()
        shutil.copytree(packages[0],ready/'20990101T000001')
        job.process_queue(root,ready,done,work/'must-not-call-missing-publisher')
        assert not list(ready.iterdir()) and (done/'20990101T000001').is_dir()
        shutil.copytree(packages[0],ready/'20990101T000001')
        bad=ready/'20990101T000001/release.json';data=json.loads(bad.read_text());data['total_bytes']+=1;bad.write_text(json.dumps(data))
        try:
            job.process_queue(root,ready,done,work/'must-not-call-missing-publisher')
            raise AssertionError('Different queue identity accepted')
        except ValueError: pass
        passed('queue recovers a completed receipt and rejects same-ID different metadata')
    finally:
        process.terminate()
        try: process.wait(timeout=10)
        except subprocess.TimeoutExpired: process.kill();process.wait()
        log.close()
    evidence.update(status='passed',nginx_stopped=True,platform=sys.platform,
                    limitations=['Isolated test does not exercise production systemd units or certificates'])
    (work/'report.json').write_text(json.dumps(evidence,indent=2)+'\n')
    print(json.dumps({'status':'passed','checks':len(evidence['checks']),'report':str((work/'report.json').relative_to(ROOT))}))


if __name__=='__main__': main()
