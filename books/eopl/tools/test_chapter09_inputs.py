#!/usr/bin/env python3
"""Execute final displayed object programs and separately preserve source fragments."""
import html
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from sync_notes import ROOT, BOOK


def run(racket,run_dir):
    output=Path(run_dir);output.mkdir(parents=True,exist_ok=True)
    page=(BOOK/'notes/chapter09_objects.html').read_text()
    shown={n:html.unescape(s) for n,s in re.findall(r'<code class="language-text" data-object-input="([^"]+)">(.*?)</code>',page,re.S)}
    expected={
      'figure9-1':'((3 -3) (5 -5))','figure9-2':'12','figure9-3':'((6 8) (20 40) 87)',
      'figure9-4':'(101 102 101 999)','figure9-5':'172','figure9-6':'33','override-self':'(11 22 22)',
      'oddeven-client':'1','figure9-8-complete':'(11 22 7 8)','exercise9-1':'(2 2 4)',
      'exercise9-2':'0','instanceof-demo':'(#t #t #t)','field-demo':'7',
      'exercise9-9':'(7 2)','exercise9-10':'(22 11 2 7)','exercise9-11':'(17 23)',
      'exercise9-12':'(17 23)','exercise9-13':'1','exercise9-15':'(1 2)',
      'exercise9-16':'(0 7)','exercise9-17':'(11 22 11)', 'exercise9-25':'(#t #t #t #t #f)',
      'exercise9-26':'9','exercise9-27':'1','exercise9-28':'(1 1 1 2)','exercise9-29':'(10 11 10)',
      'figure9-12':'(12 100)','exercise9-30':'(12 12 12)',
      'exercise9-30-stringable':'("(3,(4,(5,[])))" "((3,4),5)" "5:(3,(4,[]))")',
      'exercise9-32':'(#t #f #f)','exercise9-36':'11','exercise9-37':'(12 21)','exercise9-40':'10','exercise9-41':'(7 7)'}
    typed={'figure9-12':'(listof int)','exercise9-30':'(listof int)','exercise9-30-stringable':'(listof string)',
           'exercise9-32':'(listof bool)','exercise9-36':'int','exercise9-37':'(listof int)','exercise9-40':'int','exercise9-41':'(listof int)'}
    flags={'exercise9-16':"#:options (hash 'overload? #t)",'exercise9-26':"#:options (hash 'multiple? #t)",
           'exercise9-40':"#:options (hash 'field-initializers? #t)",'exercise9-41':"#:options (hash 'field-initializers? #t)"}
    assert set(shown)==set(expected),('displayed input inventory differs',set(shown)^set(expected))
    cases=[]
    def add(name,operation,source,result,options='',category='displayed-complete-program'):
        cases.append(dict(name=name,operation=operation,program=source,expected=result,options=options,category=category))
    for name,value in expected.items():
        opts=flags.get(name,'')
        add(name+'-value','run',shown[name],value,('#:typed? #t ' if name in typed else '')+opts)
        if name in typed:add(name+'-type','check',shown[name],typed[name],opts)
    add('overload-name-mangling','run',shown['exercise9-16'],'(0 7)',"#:options (hash 'mangle? #t)")
    add('lexical-super','run',shown['figure9-6'],'33',"#:options (hash 'lexical? #t 'direct-super? #t)")
    add('named-slots','run',shown['exercise9-10'],'(22 11 2 7)',"#:options (hash 'named-slots? #t)")
    rows=json.loads((BOOK/'notes/questions_ch09.json').read_text())['items']
    def inputs(n):return [html.unescape(s) for s in re.findall(r'<pre><code class="language-text">(.*?)</code></pre>',rows[n-1]['chinese_html'],re.S)]
    add('9.13-source-final-methods','run',inputs(13)[0]+'\nlet o=new oddeven() in send o odd(13)','1',category='original-declarations-with-explicit-client')
    add('9.15-source-static-state','run',inputs(15)[0],'(1 2)',category='original-complete-program')
    add('9.26-source-class-skeleton','parse-declarations',inputs(26)[0]+'\n0','4',category='original-fragment-parse')
    for i in [0,1]:add('9.27-source-'+str(i+1),'run',inputs(27)[i],'1',category='original-complete-program')
    for i in [0,1]:add('9.30-interface-fragment-'+str(i+1),'parse-declarations',inputs(30)[i]+'\n0','1','#:typed? #t',category='original-fragment-parse')
    add('9.37-literal-original-rejected','type-error',inputs(37)[0],'override',category='original-complete-program')
    # The two method snippets are executed unchanged inside explicit class fixtures.
    base='''class point extends object field x field y
method initialize(a,b)begin set x=a;set y=b end method getx()x method gety()y\n'''+inputs(25)[0]+'''
class colorpoint extends point field color
method initialize(a,b,c)begin super initialize(a,b);set color=c end method getcolor()color\n'''
    add('9.25-original-coordinate-method','run',base+'\nlet p=new point(3,4) c=new colorpoint(3,4,7) in list(send p similarpoints(p),send p similarpoints(c),send c similarpoints(p),send c similarpoints(c))','(#t #t #t #t)',category='original-method-with-explicit-fixture')
    add('9.25-original-incorrect-extension','runtime-error',base+'\n'+inputs(25)[1]+'\nlet c=new colorpoint(3,4,7) p=new point(3,4) in send c similarpoints(p)','method',category='original-method-with-explicit-fixture')
    quote=lambda s:json.dumps(s,ensure_ascii=False)
    tests=[]
    for case in cases:
        op=case['operation'];source=quote(case['program']);opts=case['options']
        if op in ['runtime-error','type-error']:
            call=f'(m:{"check" if op=="type-error" else "run"} {source})'
            body=f'(check-exn (lambda (e) (and (m:exn:fail:oo? e) (eq? (m:exn:fail:oo-kind e) (quote {case["expected"]})))) (lambda () {call}))'
        else:
            call=f'(m:{"parse" if op=="parse-declarations" else op} {source} {opts})'
            if op=='parse-declarations':call='(length (m:pgm-decls '+call+'))'
            body=f'(check-equal? (format "~s" {call}) {quote(case["expected"])})'
        tests.append('(test-case '+quote(case['name'])+' '+body+')')
    script='#lang racket\n(require rackunit rackunit/text-ui (prefix-in m: (file '+quote(str(BOOK/'code/chapter09.rkt'))+')))\n'
    script+='(exit (run-tests (test-suite "final displayed inputs" '+'\n'.join(tests)+')))\n'
    with tempfile.TemporaryDirectory(prefix='displayed-',dir=output) as folder:
        probe=Path(folder)/'probe.rkt';probe.write_text(script)
        result=subprocess.run([racket,str(probe)],capture_output=True,text=True,timeout=60)
    (output/'execution.log').write_text(result.stdout+result.stderr)
    assert result.returncode==0,(result.stdout,result.stderr)
    report=dict(status='passed',cases=cases,displayed_programs=len(shown),executed_program_or_type_cases=sum(c['category']!='original-fragment-parse' for c in cases),original_fragment_parse_cases=sum(c['category']=='original-fragment-parse' for c in cases))
    (output/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    return report

if __name__=='__main__':
    installed=sorted(Path('/Applications').glob('Racket*/bin/racket'))
    racket=shutil.which('racket') or (str(installed[-1]) if installed else None)
    assert racket,'Racket required'
    print(json.dumps(run(racket,ROOT/'tmp/eopl-ch09-source-inputs'),ensure_ascii=False,indent=2))
