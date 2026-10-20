#!/usr/bin/env python3
"""Check release hashes, MIME types, CSP, PDF ranges and static route behavior."""
import argparse
from datetime import datetime
import hashlib
import gzip
import http.client
import json
from pathlib import Path
import socket
import ssl
from urllib.parse import quote, urlsplit
from zoneinfo import ZoneInfo


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--release-dir', type=Path, required=True)
    ap.add_argument('--origin', required=True)
    ap.add_argument('--connect-ip', help='Connect to this origin IP, preserving HTTPS SNI and hostname verification')
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    metadata = json.loads((args.release_dir / 'release.json').read_text())
    origin = urlsplit(args.origin)
    if origin.scheme not in {'http', 'https'} or origin.path not in {'', '/'}:
        ap.error('Origin must be an HTTP(S) origin without a path')

    class OriginTLS(http.client.HTTPSConnection):
        def connect(self):
            self.sock = socket.create_connection((args.connect_ip or self.host, self.port), timeout=self.timeout)
            self.sock = self._context.wrap_socket(self.sock, server_hostname=self.host)

    def request(path, method='GET', headers=None):
        if origin.scheme == 'https':
            connection = OriginTLS(origin.hostname, origin.port or 443, timeout=20, context=ssl.create_default_context())
        else:
            connection = http.client.HTTPConnection(args.connect_ip or origin.hostname, origin.port or 80, timeout=20)
        connection.request(method, path, headers={'Host': origin.netloc, **(headers or {})})
        response = connection.getresponse()
        result = response.status, {k.lower(): v for k, v in response.getheaders()}, response.read()
        connection.close()
        return result

    started = datetime.now(ZoneInfo('Asia/Shanghai')).isoformat()
    results = []
    redirects = metadata.get('entry_redirects', {})
    inventory = {r['path']:r for r in metadata['files']}
    compression_results = []
    for row in metadata['files']:
        if '/' + row['path'] in redirects:
            continue
        status, headers, blob = request('/' + quote(row['path']))
        digest = hashlib.sha256(blob).hexdigest()
        assert status == 200 and digest == row['sha256'], (row['path'], status, digest)
        suffix = Path(row['path']).suffix
        mime = headers.get('content-type', '').split(';')[0]
        expected = {'.html': 'text/html', '.css': 'text/css', '.svg': 'image/svg+xml',
                    '.json': 'application/json', '.pdf': 'application/pdf',
                    '.c': 'text/plain', '.py': 'text/plain', '.md': 'text/plain', '.zip': 'application/zip'}.get(suffix, 'application/octet-stream')
        assert mime == expected, (row['path'], mime, expected)
        assert headers['x-content-type-options'] == 'nosniff'
        assert headers['cache-control'] == 'no-cache'
        csp = headers['content-security-policy']
        assert all(value in csp for value in metadata['inline_script_csp_sources'])
        assert not headers.get('content-encoding'), row['path']
        etag = headers.get('etag')
        assert etag, row['path']
        cached, cached_headers, cached_body = request('/'+quote(row['path']), headers={'If-None-Match':etag})
        assert cached == 304 and not cached_body and cached_headers['etag'] == etag, row['path']
        compressed = inventory.get(row['path']+'.gz')
        if compressed:
            code, gz_headers, gz_blob = request('/'+quote(row['path']), headers={'Accept-Encoding':'gzip'})
            assert code == 200 and gz_headers.get('content-encoding') == 'gzip', row['path']
            assert 'accept-encoding' in gz_headers.get('vary','').lower(), row['path']
            assert hashlib.sha256(gz_blob).hexdigest() == compressed['sha256'], row['path']
            assert gzip.decompress(gz_blob) == blob, row['path']
            assert request('/'+quote(row['path']), headers={'Accept-Encoding':'gzip','If-None-Match':gz_headers['etag']})[0] == 304
            code, plain_headers, plain = request('/'+quote(row['path']), headers={'Accept-Encoding':'gzip;q=0'})
            assert code == 200 and not plain_headers.get('content-encoding') and plain == blob
            compression_results.append({'path':row['path'],'identity_bytes':len(blob),'gzip_bytes':len(gz_blob),'conditional':304})
        results.append({'path': row['path'], 'status': status, 'mime': mime, 'bytes': len(blob), 'sha256': digest})
    for path, target in [('/', 'index.html'), ('/stochastic/', 'stochastic/index.html'), ('/weiss/', 'weiss/index.html')]:
        if path in redirects:
            continue
        status, headers, blob = request(path)
        expected = next(row['sha256'] for row in metadata['files'] if row['path'] == target)
        assert status == 200 and hashlib.sha256(blob).hexdigest() == expected, path
    redirect_results = []
    for path, target in sorted(redirects.items()):
        for query in ['', '?source=books&mode=map']:
            status, headers, blob = request(path + query)
            destination = urlsplit(headers.get('location', ''))
            assert status == 301 and destination.path == target, (path, status, headers)
            assert destination.query == query.removeprefix('?'), (path, headers['location'])
            if destination.netloc:
                assert destination.scheme == origin.scheme and destination.netloc == origin.netloc
            assert headers['cache-control'] == 'no-cache'
            assert 'content-security-policy' in headers
        status, headers, blob = request(path, method='HEAD')
        assert status == 301 and not blob and urlsplit(headers['location']).path == target, path
        assert request(path, method='POST')[0] == 403, path
        redirect_results.append({'path': path, 'target': target, 'status': 301,
                                 'query_preserved': True, 'head': 301, 'post': 403})
    pdf_results = []
    import tarfile
    with tarfile.open(args.release_dir / 'site.tar.gz') as archive:
        for row in metadata['files']:
            pdf = row['path']
            if not pdf.endswith('.pdf'):
                continue
            status, headers, blob = request('/' + pdf, headers={'Range': 'bytes=32-63'})
            assert status == 206 and len(blob) == 32, pdf
            assert headers['content-range'] == f"bytes 32-63/{row['bytes']}", pdf
            assert blob == archive.extractfile(pdf).read()[32:64], pdf
            pdf_results.append({'path': pdf, 'status': status, 'range': headers['content-range'],
                                'bytes_match': True})
    assert pdf_results, 'Expected at least one published source PDF'
    for path, method, expected in [('/.git/config', 'GET', 404), ('/absent.html', 'GET', 404),
                                   ('/index.html', 'POST', 403), ('/SHA256SUMS', 'GET', 404)]:
        assert request(path, method=method)[0] == expected, (path, method)
    result = {'status': 'pass', 'release_id': metadata['release_id'], 'origin': args.origin,
              'connect_ip': args.connect_ip, 'started_at': started,
              'finished_at': datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
              'files_checked': len(results), 'files': results, 'entry_redirects': redirect_results,
              'pdf_range': '206; bytes 32-63 agree with release', 'pdf_ranges': pdf_results,
              'precompressed': compression_results, 'conditional_requests': len(results),
              'route_checks': 'pass'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({**{k: result[k] for k in ['status', 'release_id', 'files_checked', 'pdf_range', 'route_checks']},
                      'entry_redirects_checked': len(redirect_results)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
