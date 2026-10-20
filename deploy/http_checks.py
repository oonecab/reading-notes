"""Bounded HTTPS content probes shared by publication and release verification."""
import hashlib
import http.client
import socket
import ssl
from urllib.parse import quote, urlsplit


class OriginTLS(http.client.HTTPSConnection):
    def __init__(self, host, port, connect_ip=None, **kwargs):
        self.connect_ip=connect_ip
        super().__init__(host, port, **kwargs)

    def connect(self):
        self.sock=socket.create_connection((self.connect_ip or self.host,self.port), timeout=self.timeout)
        self.sock=self._context.wrap_socket(self.sock, server_hostname=self.host)


def request(origin, path, *, connect_ip=None, headers=None, limit=None, timeout=5):
    url=urlsplit(origin)
    if url.scheme!='https' or not url.hostname or url.path not in ('','/') or url.query or url.fragment or url.username:
        raise ValueError('Health origin must be an HTTPS origin')
    connection=OriginTLS(url.hostname,url.port or 443,connect_ip,timeout=timeout,context=ssl.create_default_context())
    try:
        connection.request('GET',path,headers={'Host':url.netloc,'Accept-Encoding':'identity', **(headers or {})})
        response=connection.getresponse()
        return response.status, {k.lower():v for k,v in response.getheaders()}, response.read(None if limit is None else limit+1)
    finally:
        connection.close()


def probe_release(meta, origin='https://notes.zzzping.top', connect_ip='127.0.0.1'):
    rows={r['path']:r for r in meta['files']}
    entries={name for name in rows if name.endswith('/notes/book_overview.html')}
    names={'index.html', *entries}
    for book in {name.split('/')[0] for name in entries}:
        chapters=[r for r in rows.values() if r['path'].startswith(book+'/notes/chapter') and r['path'].endswith('.html')]
        if chapters:
            names.add(max(chapters,key=lambda r:r['bytes'])['path'])
    results=[]
    for name in sorted(names):
        row=rows[name]
        status,headers,body=request(origin,'/'+quote(name),connect_ip=connect_ip,limit=row['bytes'])
        if status!=200 or hashlib.sha256(body).hexdigest()!=row['sha256'] or headers.get('content-encoding'):
            raise ValueError('Origin content check failed: '+name+' (HTTP '+str(status)+')')
        if headers.get('content-type','').split(';')[0]!='text/html' or headers.get('cache-control')!='no-cache':
            raise ValueError('Origin delivery headers differ: '+name)
        if not all(s in headers.get('content-security-policy','') for s in meta['inline_script_csp_sources']):
            raise ValueError('Origin CSP differs: '+name)
        results.append({'path':name,'sha256':row['sha256']})
    return {'status':'passed','release_id':meta['release_id'],'archive_sha256':meta['archive_sha256'],'files':results}
