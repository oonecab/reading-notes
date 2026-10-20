"""Persist per-path content validators independently of release extraction time."""
import hashlib
import json
import os
from pathlib import Path
import re
import time

from durability import atomic_json


def representation_key(name, names):
    # gzip_static serves both files at the original URL. Reserve in one domain
    # so equally sized identity/gzip bytes cannot accidentally share a strong ETag.
    return name[:-3] if name.endswith('.gz') and name[:-3] in names else name


def assign_validators(root, site, rows, now=None):
    """Call under the publish lock, before making the candidate immutable.

    Nginx uses second-resolution mtime plus size as its ETag. Reserve seconds for
    every historical representation, even after retention removes its release.
    Colliding writes use a free earlier second, never a future Last-Modified.
    The timestamp is a cache identity; release.json records publication identity.
    """
    root, site = Path(root), Path(site)
    ledger = root/'.cache-validators.json'
    now = int(time.time() if now is None else now)
    if ledger.is_symlink():
        raise ValueError('Cache ledger must be a regular file')
    if ledger.exists():
        state = json.loads(ledger.read_text())
        if state.get('schema_version') != 1 or not isinstance(state.get('files'), dict):
            raise ValueError('Invalid cache validator ledger')
    else:
        state = {'schema_version': 1, 'files': {}}
    # Import old installations before their first managed retention. Also covers
    # a crash after ledger durability but before candidate installation.
    installed = sorted((root/'releases').glob('[0-9]*'), reverse=True)
    current = (root/'current').resolve()
    installed.sort(key=lambda p: p.resolve() != current)
    for release in installed:
        if not re.fullmatch(r'\d{8}T\d{6}', release.name) or release.is_symlink():
            raise ValueError('Unsafe installed release')
        old_rows = json.loads((release/'release.json').read_text())['files']
        names = {r['path'] for r in old_rows}
        for row in old_rows:
            name = row['path']
            p = release/'site'/name
            if Path(name).is_absolute() or '..' in Path(name).parts or p.is_symlink():
                raise ValueError('Unsafe cached representation')
            if hashlib.sha256(p.read_bytes()).hexdigest() != row['sha256']:
                raise ValueError('Cannot import damaged cached representation: '+name)
            entry = state['files'].setdefault(representation_key(name, names), {'versions': {}, 'reserved': {}})
            stamp = int(p.stat().st_mtime)
            entry['versions'].setdefault(row['sha256'], stamp)
            key = str(stamp)
            old = entry['reserved'].get(key, row['sha256'])
            entry['reserved'][key] = row['sha256'] if old == row['sha256'] else '*'
    assignments = []
    names = {r['path'] for r in rows}
    for row in rows:
        name, digest = row['path'], row['sha256']
        entry = state['files'].setdefault(representation_key(name, names), {'versions': {}, 'reserved': {}})
        stamp = entry['versions'].get(digest)
        if stamp is None or entry['reserved'].get(str(stamp)) != digest or stamp > now:
            stamp = now
            while str(stamp) in entry['reserved']:
                stamp -= 1
            if stamp < 1:
                raise ValueError('Cache validator seconds exhausted')
            entry['versions'][digest] = stamp
            entry['reserved'][str(stamp)] = digest
        assignments.append((site/name, stamp))
    # Persist reservations first; a failed flush cannot publish reused validators.
    atomic_json(ledger, state)
    for p, stamp in assignments:
        os.utime(p, (stamp, stamp), follow_symlinks=False)
