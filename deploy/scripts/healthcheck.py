#!/usr/bin/env python3
"""Probe current's content on verified TLS loopback; no external DNS dependency."""
import argparse
import fcntl
import json
from pathlib import Path
import sys
import time

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from http_checks import probe_release


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--monitor', action='store_true', help='Take a shared publish lock and detect incomplete transactions')
    args=ap.parse_args()
    root=Path('/srv/reading-notes')
    lock=None
    if args.monitor:
        lock=(root/'.publish.lock').open('rb')
        try: fcntl.flock(lock,fcntl.LOCK_SH|fcntl.LOCK_NB)
        except BlockingIOError:
            print(json.dumps({'status':'deferred','reason':'publication in progress'}));return 0
        if (root/'.publish-transaction.json').exists():
            raise ValueError('Pending publication transaction requires recovery')
    meta=json.loads((root/'current/release.json').read_text())
    for attempt in range(3):
        try:
            result=probe_release(meta)
            print(json.dumps(result));return 0
        except (OSError,ValueError):
            if attempt==2:raise
            time.sleep(.25)


if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as error:
        print(json.dumps({'status':'failed','error':str(error)}),file=sys.stderr);raise SystemExit(1)
