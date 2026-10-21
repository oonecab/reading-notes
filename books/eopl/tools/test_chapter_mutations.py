#!/usr/bin/env python3
"""Show that semantic regressions detect independent implementation faults."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from sync_notes import ROOT, BOOK


def run(racket):
    variants = [
        ('number-leaves-reuses-left-start', 'chapter01.rkt', '(walk (rson t) after-left)', '(walk (rson t) next)'),
        ('bigits-noncanonical-zero', 'chapter02.rkt', "[(and (= (car ds) 1) (null? (cdr ds))) '()]", "[(and (= (car ds) 1) (null? (cdr ds))) '(0)]"),
        ('membership-confuses-false-value', 'chapter02.rkt', '(or (eqv? (caar env) v) (alist-has? (cdr env) v))', '(if (eqv? (caar env) v) (and (cdar env) #t) (alist-has? (cdr env) v))'),
        ('prefix-ignores-extra-tokens', 'chapter02.rkt', '(unless (null? rest) (error \'parse-prefix "unused tokens: ~s" rest))', '(void)'),
        ('zipper-drops-edited-focus', 'chapter02.rkt', '(list (cadr crumb) (car z) (caddr crumb))', "(list (cadr crumb) '() (caddr crumb))"),
    ]
    results = []
    output = ROOT / 'tmp/eopl-ch12-mutations'
    output.mkdir(parents=True, exist_ok=True)
    for name, filename, before, after in variants:
        with tempfile.TemporaryDirectory(prefix=name+'-', dir=output) as temp:
            folder=Path(temp)
            for f in ['chapter01.rkt','chapter02.rkt','test_chapters.rkt']:
                shutil.copy2(BOOK/'code'/f, folder/f)
            target=folder/filename
            source=target.read_text()
            assert source.count(before)==1,(name,'mutation target count')
            target.write_text(source.replace(before,after))
            result=subprocess.run([racket,str(folder/'test_chapters.rkt')],capture_output=True,text=True,timeout=60)
            assert result.returncode != 0, (name,'fault was not detected')
            assert 'FAILURE' in result.stderr or 'ERROR' in result.stderr, (name,'failed before tests')
            results.append({'name':name,'status':'rejected','exit_code':result.returncode})
    report={'status':'passed','cases':results}
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    return report

if __name__=='__main__':
    racket=shutil.which('racket')
    if not racket:
        found=sorted(Path('/Applications').glob('Racket*/bin/racket'))
        racket=str(found[-1]) if found else None
    if not racket:raise SystemExit('Racket is required')
    print(json.dumps(run(racket),indent=2))
