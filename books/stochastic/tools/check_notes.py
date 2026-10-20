#!/usr/bin/env python3
"""Check HTML against standalone sources, then compile and run the matching programs."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit,unquote
import argparse,hashlib,json,math,re,shutil,subprocess,sys
from readable_numbers import readable_text, readable_tex, readable_code
from sync_code import program_sources, synchronize
from html_support import Document, check_resources
from content_integrity import check_snapshot, check_pdf_locations, check_source_numbers
from derivation_coverage import load_documents, validate, check_current_inventory
from generate_cases import reference
from datetime import datetime, timezone
ROOT=Path(__file__).resolve().parents[1]
NOTES=ROOT/"notes"
RUN=ROOT/"tmp/notes-check"
class Page(HTMLParser):
    VOID=set('area base br col embed hr img input link meta param source track wbr'.split())
    ALLOWED=set(('html head meta title style body a aside details summary nav ul li main header h1 h2 h3 h4 h5 h6 p '
                 'strong em b i small span section div ol table thead tbody tfoot tr th td pre code script footer '
                 'figure figcaption blockquote svg defs marker path line polyline polygon rect circle ellipse text g '
                 'math mi mn mo mrow msub msup msubsup mfrac mtd mtr mtable mspace mtext msqrt mroot '
                 'munderover munder mover mstyle menclose mfenced mphantom mpadded merror semantics annotation').split())|VOID
    def __init__(self,path):
        super().__init__(convert_charrefs=True)
        self.path=path;self.ids=set();self.links=[];self.exercises=[];self.codes={}
        self.maths=0;self.figures=0;self.code=None;self.buf=[];self.errors=[];self.styles=[]
        self.style=False;self.stylebuf=[];self.stack=[];self.current_ex=None;self.step_counts={};self.math_depth=0
        self.sections=[];self.annotation_targets=[];self.annotation_cards=0
        self.annotation_counts={};self.annotation_ids=set()
        self.statements=[];self.original_excerpts=0;self.preface_paragraphs=[];self.axioms=0
        self.feed(path.read_text());self.close()
        try:check_resources(path.read_text(), 'notes/'+path.name)
        except ValueError as exc:self.errors.append(str(exc))
        for node in Document(path.read_text()).root.walk('math'):
            if not node.attrs.get('data-tex') or not node.text().strip():
                self.errors.append('empty MathML or missing TeX')
        if self.stack:self.errors.append('unclosed elements: '+str([t for t,a in self.stack[-5:]]))
        for num,count in self.step_counts.items():
            if count<3:self.errors.append('fewer than three detailed steps: '+num)
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag in {'div', 'details'} and 'source-statement' in a.get('class','').split():
            parent=next((attrs.get('id') for t,attrs in reversed(self.stack) if t=='section'),None)
            self.statements.append({'id':a.get('id'),'kind':a.get('data-source-kind'),
                                    'number':a.get('data-source-number'),'section':parent})
        if tag=='blockquote' and 'original-excerpt' in a.get('class','').split():
            self.original_excerpts+=1
            if a.get('lang')!='en':self.errors.append('original excerpt must be marked English')
            if a.get('data-preface-paragraph'):self.preface_paragraphs.append(a['data-preface-paragraph'])
        if tag=='li' and any(t in {'div', 'details'} and attrs.get('data-source-kind')=='Axiom' for t,attrs in self.stack):
            self.axioms+=1
        if tag=='section' and self.stack and self.stack[-1][0]=='main':self.sections.append(a.get('id'))
        if tag=='details' and 'reading-notes' in a.get('class','').split():
            target=a.get('data-notes-for');self.annotation_targets.append(target)
            parent=next((attrs.get('id') for t,attrs in reversed(self.stack) if t=='section'),None)
            if target!=parent or a.get('id')!='notes-'+str(target):self.errors.append('annotation section/anchor mismatch: '+str(target))
            if target in self.annotation_counts:self.errors.append('duplicate annotation group: '+str(target))
            self.annotation_counts[target]=0
        if tag=='div' and 'annotation-card' in a.get('class','').split():
            self.annotation_cards+=1
            target=next((attrs.get('data-notes-for') for t,attrs in reversed(self.stack)
                         if t=='details' and 'reading-notes' in attrs.get('class','').split()),None)
            if target not in self.annotation_counts:self.errors.append('annotation outside section notes')
            else:self.annotation_counts[target]+=1
            note_id=a.get('data-note-id')
            if not note_id or note_id in self.annotation_ids:self.errors.append('missing/duplicate annotation identity: '+str(note_id))
            self.annotation_ids.add(note_id)
        if tag not in self.ALLOWED:self.errors.append('unknown/malformed tag: '+tag)
        if tag in {'p','div','ol','ul','table','pre','h1','h2','h3','h4','h5','h6','figure','section'} and any(t=='p' for t,a in self.stack):
            self.errors.append('block element inside paragraph: '+tag+' at '+str(self.getpos()))
        if tag=='details' and 'exercise' in a.get('class','').split():
            self.current_ex=a.get('data-original-exercise') or a['id'][3:].replace('-','.');self.step_counts[self.current_ex]=0
        if tag=='li' and self.current_ex and self.stack and self.stack[-1][0]=='ol' and 'solution-steps' in self.stack[-1][1].get('class','').split():
            self.step_counts[self.current_ex]+=1
        if tag not in self.VOID:self.stack.append((tag,a))
        if "id" in a:
            if a["id"] in self.ids:self.errors.append("duplicate id "+a["id"])
            self.ids.add(a["id"])
        if "href" in a:self.links.append(a["href"])
        if tag in ["img","script","link","iframe","source"] and any(k in a for k in ["src","srcset","href"]):
            self.errors.append("separate resource: "+tag)
        if tag=="math":
            self.maths+=1;self.math_depth+=1
            if readable_tex(a.get('data-tex','')) != a.get('data-tex',''):
                self.errors.append('omitted leading zero in formula: '+a.get('data-tex','')[:100])
            tex=re.sub(r'\\[{}]','',a.get('data-tex',''));balance=0
            for char in tex:
                balance+=(char=='{')-(char=='}')
                if balance<0:break
            if balance:self.errors.append('unbalanced formula braces: '+a.get('data-tex','')[:100])
        if tag=="merror":self.errors.append("MathML error")
        if tag=="figure":self.figures+=1
        if "data-original-exercise" in a:self.exercises.append(a["data-original-exercise"])
        if tag=="code" and a.get("data-language") in ["c","python"]:
            self.code=(a["id"].rsplit("-",1)[0],a["data-language"]);self.buf=[]
        if tag=="style":self.style=True;self.stylebuf=[]
        if tag=="script" and a.get("type")=="application/json" and "data-program" in a:
            self.record=a["data-program"];self.recordbuf=[]
    def handle_data(self,s):
        if self.code is not None:self.buf.append(s)
        if self.style:self.stylebuf.append(s)
        if getattr(self,"record",None) is not None:self.recordbuf.append(s)
        if not self.math_depth and not self.code and not self.style and not any(t=='script' for t,a in self.stack):
            if readable_text(s) != s:
                self.errors.append('omitted leading zero in readable text: '+s[:100])
            if any('answer-title' in a.get('class', '').split() for t,a in self.stack) and s.strip()!='解答':
                self.errors.append('solution heading must be 解答: '+s)
            if re.search(r'\$[^$\n]+\$|\\(?:frac|begin|sum|mathbb|operatorname)\s*[{(]',s):
                self.errors.append('unconverted formula text: '+s[:70])
    def handle_endtag(self,tag):
        if not self.stack or self.stack[-1][0]!=tag:
            self.errors.append('unbalanced close: '+tag+' at '+str(self.getpos()))
        else:
            _,attrs=self.stack.pop()
            if tag=='details' and 'exercise' in attrs.get('class','').split():self.current_ex=None
        if tag=='math':self.math_depth-=1
        if tag=="code" and self.code is not None:
            if self.code in self.codes:self.errors.append("duplicate program")
            source="".join(self.buf)
            if readable_code(source,self.code[1]) != source:
                self.errors.append('omitted leading zero in program literal: '+str(self.code))
            self.codes[self.code]=source;self.code=None
        if tag=="style":self.styles.append("".join(self.stylebuf));self.style=False
        if tag=="script" and getattr(self,"record",None) is not None:
            if not hasattr(self,"recordings"):self.recordings={}
            self.recordings[self.record]=json.loads("".join(self.recordbuf));self.record=None
    def handle_startendtag(self,tag,attrs):
        self.handle_starttag(tag,attrs)
        if tag not in self.VOID:self.handle_endtag(tag)
def command(argv,stdin="",success=True,expected_status=None):
    r=subprocess.run(list(map(str,argv)),input=stdin,text=True,capture_output=True,timeout=60)
    if success and r.returncode:raise AssertionError(str(argv)+"\n"+r.stderr[:2000])
    if r.returncode<0:raise AssertionError('program terminated by signal: '+str(r.returncode))
    if not success:
        expected_status=2 if expected_status is None else expected_status
        if r.returncode!=expected_status:raise AssertionError(f'expected exit {expected_status}, got {r.returncode}: {r.stderr[:300]}')
        if not r.stderr.strip():raise AssertionError('failure must emit a diagnostic')
    if "AddressSanitizer" in r.stderr or "runtime error:" in r.stderr:raise AssertionError(r.stderr)
    return r.stdout
def close(a,b,label):
    if len(a)!=len(b):raise AssertionError(label+": length")
    for i,(x,y) in enumerate(zip(a,b)):
        if not math.isfinite(x) or not math.isfinite(y) or not math.isclose(x,y,abs_tol=5e-12,rel_tol=8e-12):
            raise AssertionError(f"{label}[{i}]: {x} != {y}")
def matrix_input(c):
    m=c["matrix"];s=str(len(m))+"\n"+"\n".join(" ".join(format(x,".17g") for x in row) for row in m)+"\n"
    if "fixed" in c:s+=" ".join(map(str,c["fixed"]))+"\n"
    if c["mode"]=="psteps":s+=str(c["steps"])+"\n"+" ".join(map(str,c["initial"]))+"\n"
    return s
def nums(s):return [float(x) for x in s.split()]
def finance_rows(s):
    rows=[]
    for line in s.splitlines():
        path,a,b,c,d=line.split();rows.append((path,float(a),float(b),float(c),int(d)))
    return rows
def main():
    global RUN
    started=datetime.now(timezone.utc).isoformat()
    ap=argparse.ArgumentParser();ap.add_argument("--extract-only",action="store_true");ap.add_argument('--run-dir',type=Path,default=RUN);args=ap.parse_args()
    global_run=args.run_dir.resolve()
    RUN=global_run
    RUN.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((NOTES/"source_manifest.json").read_text());pdf=ROOT/manifest["pdf_filename"]
    if hashlib.sha256(pdf.read_bytes()).hexdigest()!=manifest["sha256"]:raise AssertionError("source PDF hash changed")
    web_pdf=ROOT/manifest['web_pdf']['path']
    if ROOT not in web_pdf.resolve().parents or hashlib.sha256(web_pdf.read_bytes()).hexdigest()!=manifest['sha256']:
        raise AssertionError('web PDF missing or differs from the source')
    synchronization=synchronize()
    if synchronization['differences']:raise AssertionError('HTML differs from standalone programs: '+str(synchronization['differences']))
    source_programs,standalone_sources=program_sources()
    # I017 extends the reviewed explanation gate to every catalogued item.
    derivation_documents=load_documents()
    check_current_inventory(derivation_documents)
    derivation_errors=validate(derivation_documents)
    if derivation_errors:raise AssertionError('\n'.join(derivation_errors))
    content_binding=check_snapshot()
    page_correspondence=check_pdf_locations()
    paths=sorted(NOTES.glob("*.html"))
    if len(paths)!=9 or not (NOTES/'preface.html').is_file():raise AssertionError("expected 9 pages including preface")
    pages={p.name:Page(p) for p in paths};programs={};errors=[]
    recordings={name:data for page in pages.values() for name,data in getattr(page,"recordings",{}).items()}
    for name,page in pages.items():
        errors.extend(name+": "+e for e in page.errors)
        if page.annotation_targets!=page.sections:errors.append(name+': reading annotations must follow each section in order')
        if page.annotation_cards!=2*len(page.sections):errors.append(name+': expected two supplementary cards per section')
        if any(count!=2 for count in page.annotation_counts.values()):errors.append(name+': each section must have exactly two supplementary cards')
        for anchor in ['annotation-rail','annotation-content','annotation-context-link']:
            if anchor not in page.ids:errors.append(name+': missing annotation interface '+anchor)
        for href in page.links:
            parts=urlsplit(href)
            if parts.scheme=='file':errors.append(name+': machine-local file URL '+href)
            if parts.scheme or parts.netloc:continue
            dest=(page.path.parent/unquote(parts.path)).resolve() if parts.path else page.path
            if not dest.is_file():errors.append(name+": missing file "+href);continue
            if dest.suffix==".html" and parts.fragment:
                target=pages.get(dest.name)
                if target is None or unquote(parts.fragment) not in target.ids:errors.append(name+": missing anchor "+href)
            if dest.suffix=='.pdf':
                if dest!=web_pdf.resolve():errors.append(name+': unexpected PDF target '+href)
                if parts.fragment and (not re.fullmatch(r'page=[0-9]+',parts.fragment) or not 1<=int(parts.fragment[5:])<=manifest['pdf_pages']):
                    errors.append(name+': invalid PDF page '+href)
        for key,source in page.codes.items():
            if key in programs:errors.append("duplicate code "+str(key))
            programs[key]=source
    for i,c in enumerate(manifest["chapters"][:6],1):
        page=next(p for name,p in pages.items() if name.startswith(f"chapter{i:02d}_"))
        expected=[x["number"] for x in c["exercises"]]
        if page.exercises!=expected:errors.append(f"chapter {i}: exercise coverage/order")
        for num in expected:
            if "ex-"+num.replace(".","-") not in page.ids:errors.append("exercise anchor "+num)
    if len({p.styles[0] for p in pages.values()})!=1:errors.append("inconsistent styles")
    numbered=[(s['kind'],s['number']) for page in pages.values() for s in page.statements if s['number']]
    expected={(s['kind'],s['number']) for s in manifest['numbered_results']}
    if len(numbered)!=len(set(numbered)) or set(numbered)!=expected:errors.append('numbered theorem/lemma/definition source coverage')
    if len(pages['preface.html'].preface_paragraphs)!=4:errors.append('preface must preserve four original paragraphs')
    if sum(p.axioms for p in pages.values())!=3:errors.append('expected three probability axioms')
    for name,page in pages.items():
        if page.statements and 'statement-index' not in page.ids:errors.append(name+': missing definition/theorem index')
        if any(s['section'] not in page.sections for s in page.statements):errors.append(name+': statement outside its section')
        if any(s['kind'] not in {'Theorem','Lemma','Definition','Axiom','Principle'} for s in page.statements):errors.append(name+': unrecognized statement type')
    if len(programs)!=14:errors.append(f"expected 7 pairs, got {len(programs)} programs")
    if programs!=standalone_sources:errors.append('standalone/HTML program coverage or byte content differs')
    for program in source_programs:
        page=pages[Path(program['page']).name]
        for relative in program['files'].values():
            expected='../'+relative
            if expected not in page.links:errors.append(program['page']+': missing program download '+expected)
    for name,lang in programs:
        if (name,"python" if lang=="c" else "c") not in programs:errors.append("unpaired "+name)
        (RUN/(name+(".c" if lang=="c" else ".py"))).write_text(programs[name,lang])
    if errors:raise AssertionError("\n".join(errors))
    report={"html_pages":len(pages),"exercises":sum(len(p.exercises) for p in pages.values()),
            "detailed_answers":sum(len(p.step_counts) for p in pages.values()),
            "solution_steps":sum(sum(p.step_counts.values()) for p in pages.values()),
            "balanced_html":"pass","formula_conversion":"pass",
            "leading_decimal_zeros":"pass","solution_headings":"pass",
            "annotation_groups":sum(len(p.annotation_targets) for p in pages.values()),
            "annotation_cards":sum(p.annotation_cards for p in pages.values()),"annotation_bindings":"pass",
            "formal_statements":sum(len(p.statements) for p in pages.values()),
            "numbered_theorems_and_lemmas":sum(s['kind'] in {'Theorem','Lemma'} for p in pages.values() for s in p.statements),
            "numbered_definitions":sum(s['kind']=='Definition' and s['number'] is not None for p in pages.values() for s in p.statements),
            "numbered_source_coverage":"pass","original_excerpts":sum(p.original_excerpts for p in pages.values()),
            "preface_original_paragraphs":len(pages['preface.html'].preface_paragraphs),"probability_axioms":sum(p.axioms for p in pages.values()),
            "code_pairs":len(programs)//2,"standalone_source_files":len(standalone_sources),
            "source_html_consistency":"pass","web_pdf_sha256":manifest['sha256'],
            "pdf_links":"pass","mathml":sum(p.maths for p in pages.values()),
            "figures":sum(p.figures for p in pages.values()),"source_sha256":manifest["sha256"],
            "content_binding":content_binding,"pdf_page_correspondence":page_correspondence,
            "check_scope":"HTML/source consistency, reviewed-content change guard, numeric references and execution. These checks do not prove all translated statements or mathematical arguments.",
            "started_at_utc":started}
    if args.extract_only:
        print(json.dumps({"extracted":report,"directory":str(RUN)},ensure_ascii=False,indent=2));return
    clang=shutil.which("clang")
    if not clang:raise RuntimeError("clang required")
    names=sorted({name for name,lang in programs})
    for name in names:
        for sanitized in [False,True]:
            output=RUN/(name+("-san" if sanitized else ""))
            flags=["-std=c11","-Wall","-Wextra","-Werror","-pedantic","-ffp-contract=off"]
            flags+=["-O1","-g","-fsanitize=address,undefined","-fno-omit-frame-pointer"] if sanitized else ["-O2"]
            command([clang,*flags,RUN/(name+".c"),"-lm","-o",output])
    print(f"HTML coverage and {len(names)} strict C/sanitizer builds passed.",flush=True)
    cases=json.loads((ROOT/"tools/notes_cases.json").read_text())
    for case in cases:
        independent=reference(case)
        if case['program']=='finance':
            if len(independent)!=len(case['expected']):raise AssertionError('oracle node count')
            for a,b in zip(independent,case['expected']):
                if a['path']!=b['path'] or a['action']!=b['action']:raise AssertionError('independent exact oracle decision')
                close([a[k] for k in ['s','v','delta']],[b[k] for k in ['s','v','delta']],'regenerated oracle')
        else:close(independent,case['expected'],'regenerated oracle')
        name=case["program"];argv=[case["mode"]] if name=="linear" else []
        inp=matrix_input(case) if name=="linear" else case["input"]
        py=command([sys.executable,RUN/(name+".py"),*argv],inp)
        outputs=[command([RUN/(name+suffix),*argv],inp) for suffix in ["","-san"]]
        if any(output!=py for output in outputs):raise AssertionError('C/Python text differs: '+case.get('label',name))
        if name=="finance":
            expected=case["expected"];values=finance_rows(py)
            if len(values)!=len(expected):raise AssertionError("finance node count")
            for row,e in zip(values,expected):
                if row[0]!=e["path"] or row[4]!=e["action"]:raise AssertionError("finance path/decision")
                close(list(row[1:4]),[e["s"],e["v"],e["delta"]],case.get("label","finance"))
            for output in outputs:
                cvalues=finance_rows(output)
                if len(cvalues)!=len(values):raise AssertionError("C finance node count")
                for a,b in zip(cvalues,values):
                    if a[0]!=b[0] or a[4]!=b[4]:raise AssertionError("C finance decision")
                    close(list(a[1:4]),list(b[1:4]),"finance C/Python")
        else:
            values=nums(py);close(values,case["expected"],name+" oracle")
            for output in outputs:close(nums(output),values,name+" C/Python")
    print(f"{len(cases)} independent numerical fixtures passed in C, Python and sanitizers.",flush=True)
    for name in ["poisson","renewal","ctmc","stopping"]:
        py=command([sys.executable,RUN/(name+".py")]);values=nums(py)
        for suffix in ["","-san"]:close(nums(command([RUN/(name+suffix)])),values,name)
        if name=="poisson":
            rows=[list(map(float,s.split())) for s in py.splitlines()]
            close([sum(r[2] for r in rows)],[1],"probability sum")
            for k,p,f in rows:
                if abs(p-f)>6*math.sqrt(max(p*(1-p),0)/100000)+.00005:raise AssertionError("Poisson frequency")
        elif name=="renewal":
            rows=[list(map(float,s.split())) for s in py.splitlines()]
            if abs(rows[0][1]-.5)>.01 or abs(rows[0][2]-.1)>.01:raise AssertionError("renewal bias")
        elif name=="ctmc":
            rows=[list(map(float,s.split())) for s in py.splitlines()]
            if rows[0][1]!=.5 or abs(rows[0][2]-1/3)>.01:raise AssertionError("CTMC time")
        elif abs(values[0]-25)>.3 or abs(values[1]-.5)>.01:raise AssertionError("stopping simulation")
        close(nums(recordings[name]),values,name+" HTML recorded data")
    py=command([sys.executable,RUN/"bs.py","convergence"],"100 100 1 .05 .2\n")
    close(nums(recordings["bs"]),nums(py),"BS HTML recorded data")
    for suffix in ["","-san"]:close(nums(command([RUN/("bs"+suffix),"convergence"],"100 100 1 .05 .2\n")),nums(py),"BS convergence")
    rows=py.splitlines();bs_reference=float(rows[0].split()[0]);gaps=[abs(float(s.split()[1])-bs_reference) for s in rows[1:]]
    if gaps[-1]>=gaps[0] or gaps[-1]>.01:raise AssertionError("CRR convergence")
    invalid=[
        ("linear",["pstation"],"0\n"),("linear",["pstation"],"2\n1 0\n0 1\n"),
        ("linear",["qstation"],"2\n-1 2\n1 -1\n"),
        ("finance",[],"13 4 2 .5 .25 4 0 0 0\n"),("finance",[],"3 4 2 .5 2 4 0 0 0\n"),
        ("bs",[],"100 100 1 .05 -.2\n"),
        ("linear",['pstation'],"2.0\n.5 .5\n.5 .5\n"),
        ("linear",['pstation'],"2\n.5 .5\n.5 .5\n7\n"),
        ("linear",['pstation'],"2\n.5 NaN\n.5 .5\n"),
        ("linear",['qstation'],"2\n1e-15 0\n0 0\n"),
        ("linear",['qstation'],"2\n-1e-15 2e-15\n1e-15 -1e-15\n"),
        ("linear",['pstation'],"2\n.5 -.5\n.5 .5\n"),
        ("linear",['pprob'],"2\n.5 .5\n0 1\n-.5 1\n"),
        ("linear",['pprob'],"2\n.5 .5\n0 1\n-1 2\n"),
        ("linear",['ptime'],"2\n.5 .5\n0 1\n-1 1\n"),
        ("linear",['pprob'],"2\n.5 .5\n0 1\n-1 -1\n"),
        ("linear",['ptime'],"2\n1 0\n0 1\n-1 0\n"),
        ("linear",['psteps'],"2\n.5 .5\n.5 .5\n1.0\n1 0\n"),
        ("linear",['psteps'],"2\n.5 .5\n.5 .5\n100001\n1 0\n"),
        ("linear",['psteps'],"2\n.5 .5\n.5 .5\n0\n1.1 -.1\n"),
        ("finance",[],"1 4 2 .5 .25 4 0 0 0 extra\n"),
        ("finance",['bad'],"1 4 2 .5 .25 4 0 0 0\n"),
        ("finance",[],"1.0 4 2 .5 .25 4 0 0 0\n"),
        ("finance",[],"1 4 2 .5 .25 4 8 0 0\n"),
        ("finance",[],"1 4 2 .5 .25 4 0 2 0\n"),
        ("finance",[],"1 4 2 .5 .25 4 0 0\n"),
        ("finance",[],"1 inf 2 .5 .25 4 0 0 0\n"),
        ("finance",[],"12 1e308 2 .5 .25 4 0 0 0\n"),
        ("finance",[],"12 1e-308 2 1e-308 .25 4 0 0 0\n"),
        ("bs",[],"100 100 1 .05 .2 extra\n"),
        ("bs",['convergence','extra'],"100 100 1 .05 .2\n"),
        ("bs",['unknown'],"100 100 1 .05 .2\n"),
        ("bs",[],"100 100 -1 .05 .2\n"),
        ("bs",[],"0 100 1 .05 .2\n"),
        ("bs",[],"100 inf 1 .05 .2\n"),
        ("bs",[],"100 100 1 -1000 .2\n"),
        ("bs",[],"100 100 1 1000 .2\n"),
        ("bs",['convergence'],"100 100 0 .05 .2\n"),
        ("bs",['convergence'],"100 100 1 .05 0\n"),
        ("bs",['convergence'],"100 100 1 2 .01\n"),
        ("bs",[],"100_0 100 1 .05 .2\n"),
        ("bs",[],"0x1p4 100 1 .05 .2\n")]
    invalid += [
        ('linear',['pstation'],'2\n'+'0'*127+'1 1 0\n'),
        ('finance',[],'0'*127+'1 4 1 0.5 0.25 4 0 0\n'),
        ('bs',[],'1'*128+' 1 0.05 0.2\n'),
        ('linear',['qstation'],'3\n-1 1 0\n1 -1.0000000000000009 8.881784197001252e-16\n0 8.881784197001252e-16 -8.881784197001252e-16\n')]
    for name,argv,inp in invalid:
        numerical=(name=='linear' and (inp=='2\n1 0\n0 1\n' or argv==['ptime'] and inp=='2\n1 0\n0 1\n-1 0\n' or '8.881784197001252e-16' in inp)) or (name=='finance' and ('1e308' in inp or '1e-308' in inp)) or (name=='bs' and ('1000' in inp or inp=='100 100 1 2 .01\n'))
        expected_status=3 if numerical else 2
        command([sys.executable,RUN/(name+".py"),*argv],inp,False,expected_status)
        for suffix in ["","-san"]:command([RUN/(name+suffix),*argv],inp,False,expected_status)
    report['source_page_number_check']=check_source_numbers()
    command([sys.executable,ROOT/'tools/check_content_regressions.py'])
    command([sys.executable,ROOT/'tools/test_tooling.py'])
    seed_checks=json.loads(command([sys.executable,ROOT/'tools/check_simulation_seeds.py',RUN/'seed-checks']))
    report.update({"numerical_fixtures":len(cases),"simulation_runs":4,"crr_periods":[16,32,64,128,256,512],
                   "c11_strict":"pass","asan_ubsan":"pass","python":"pass","cross_language":"pass",
                   "invalid_inputs":len(invalid),"browser_acceptance":"recorded separately",
                   "content_regressions":"pass","tooling_regressions":"pass",
                   "additional_seed_checks":seed_checks,
                   "finished_at_utc":datetime.now(timezone.utc).isoformat()})
    (RUN/"report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2))
    print(json.dumps(report,ensure_ascii=False,indent=2));print("OVERALL PASS")
if __name__=="__main__":main()
