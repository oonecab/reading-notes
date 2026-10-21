"""Source-based and independent finite checks for chapters 5--8."""
import itertools
from html.parser import HTMLParser
import json
import math
from pathlib import Path
import re
import subprocess
import sys
from check_algebra import module, need, permutation_then, graph_words, cell_text

ROOT = Path(__file__).resolve().parents[1]


def closure(generators, table):
    found = {0}
    queue = [0]
    for a in queue:
        for b in generators:
            c = table[a][b]
            if c not in found:
                found.add(c)
                queue.append(c)
    return frozenset(found)


def all_subgroups(table):
    found = {frozenset({0})}
    queue = list(found)
    for h in queue:
        for g in range(len(table)):
            k = closure(list(h) + [g], table)
            if k not in found:
                found.add(k)
                queue.append(k)
    return found


def table_from_permutations(perms):
    index = {p:i for i,p in enumerate(perms)}
    return [[index[permutation_then(a,b)] for b in perms] for a in perms]


def perm_closure(generators):
    e = tuple(range(len(generators[0])))
    found = {e}
    queue = [e]
    for a in queue:
        for b in generators:
            p = permutation_then(a,b)
            if p not in found:
                found.add(p)
                queue.append(p)
    return queue


def orders(table):
    return [len(closure([g],table)) for g in range(len(table))]


def permutation_checks():
    mod = module('permutations')
    need(mod.compose((1,0,2),(0,2,1))==(2,0,1), 'temporal composition reverses (12) then (23)')
    count = 0
    square_counts = {}
    for n in range(1,8):
        squares=set()
        for p in itertools.permutations(range(n)):
            parts = mod.cycles(p)
            need(sorted(x for part in parts for x in part)==list(range(n)), 'cycles omit/repeat a point')
            current=tuple(range(n));order=0
            while True:
                current=permutation_then(current,p);order+=1
                if current==tuple(range(n)):break
            need(order==math.lcm(*(len(part) for part in parts)), 'cycle order fails repeated action')
            need(mod.compose(p,mod.inverse(p))==tuple(range(n)), 'permutation inverse failed')
            inversions=sum(p[i]>p[j] for i in range(n) for j in range(i+1,n))
            need(inversions%2==(n-len(parts))%2,'parity fails cycle count')
            squares.add(permutation_then(p,p));count+=1
        square_counts[n]=len(squares)
    sigma=(1,2,3,0,5,4)
    squares={permutation_then(p,p) for p in itertools.permutations(range(6))}
    need(sigma not in squares, '5.4.2 square counterexample disappeared')
    need(square_counts[6]<math.factorial(6)//2, 'squares incorrectly equal A6')
    # Verify cycle decomposition with the book's temporal convention.
    for n in range(2,9):
        p=tuple(range(n))
        for k in range(1,n):
            t=list(range(n));t[0],t[k]=t[k],t[0]
            p=permutation_then(p,t)
        need(p==tuple(list(range(1,n))+[0]), '7.32 temporal transposition factorization failed')
    return {'permutations':count,'distinct_squares_by_degree':square_counts}


def subgroup_checks():
    mod=module('subgroups');cases=0;counts={}
    for n in range(1,7):
        if n>=3:
            perms=[tuple(((-1)**j*(x+i))%n for x in range(n)) for j in range(2) for i in range(n)]
            t=table_from_permutations(perms)
        else:
            t=[[a^b for b in range(2*n)] for a in range(2*n)]
        for a,b in itertools.product(range(2*n),repeat=2):
            need(mod.multiply(a,b,n)==t[a][b], 'Dn multiplication differs from vertex action')
            cases+=1
        expected=all_subgroups(t)
        output=subprocess.run([sys.executable,str(ROOT/'code/subgroups.py'),str(n)],check=True,capture_output=True,text=True).stdout
        actual={frozenset(map(int,s.split(','))) for s in re.findall(r'^H=\{([^}]*)\}',output,re.M)}
        need(actual==expected,'subset enumeration differs from generator closure')
        for h in expected:
            for right in (False,True):
                want={frozenset(t[x][g] if right else t[g][x] for x in h) for g in range(2*n)}
                got={frozenset(mod.members(mask,2*n)) for mask in mod.cosets(h,n,right)}
                need(got==want,'coset partition differs from independent action')
        counts[n]=len(expected)
    need(counts=={1:2,2:5,3:6,4:10,5:8,6:16},'subgroup counts changed')
    return {'vertex_products':cases,'subgroups_by_n':counts}


def valid_products():
    return [(n,m,u) for n in range(2,13) for m in range(1,7) for u in range(n)
            if n*m<=24 and math.gcd(n,u)==1 and pow(u,m,n)==1]


def product_checks():
    mod=module('products');cases=0
    for n,m,u in valid_products():
        # Independent faithful action on a marked n-by-m grid. The second
        # coordinate preserves distinct layers even when the automorphism repeats.
        states=[(x,y) for y in range(m) for x in range(n)]
        perms=[tuple((pow(pow(u,-1,n),j,n)*(x+i))%n+n*((y+j)%m) for x,y in states)
               for j in range(m) for i in range(n)]
        t=table_from_permutations(perms)
        for a,b in itertools.product(range(n*m),repeat=2):
            need(mod.multiply(a,b,n,m,u)==t[a][b], 'semidirect product differs from grid action')
            need((t[a][b]//n)==((a//n+b//n)%m),'quotient map does not preserve product')
            cases+=1
        need([mod.element_order(a,n,m,u) for a in range(n*m)]==orders(t),'semidirect element order incorrect')
    return {'parameter_sets':len(valid_products()),'faithful_action_products':cases}


def hom_checks():
    mod=module('homomorphisms');pairs=0;exhaustive=0
    for m in range(1,13):
        for n in range(1,13):
            maps=list(mod.maps(m,n));need(len(maps)==math.gcd(m,n),'Hom count differs from gcd')
            for k,values,kernel,image,fibers in maps:
                for a,b in itertools.product(range(m),repeat=2):
                    need(values[(a+b)%m]==(values[a]+values[b])%n,'map not additive');pairs+=1
                need(len(kernel)*len(image)==m,'kernel-image count failed')
                expected={frozenset((g+x)%m for x in kernel) for g in range(m)}
                need({frozenset(f) for _,f in fibers}==expected,'fibers not kernel cosets')
                need(set(image)==set(values),'image incorrect')
            if m<=4 and n<=4:
                actual={tuple(v) for _,v,*_ in maps};want=set()
                for values in itertools.product(range(n),repeat=m):
                    exhaustive+=1
                    if all(values[(a+b)%m]==(values[a]+values[b])%n for a in range(m) for b in range(m)):
                        want.add(values)
                need(actual==want,'generator enumeration differs from exhaustive functions')
    return {'cyclic_pairs':144,'additive_equations':pairs,'exhaustive_functions':exhaustive}


def source_diagram_checks(text=None):
    """Bind the rendered 7.18(h) arrows to independently transcribed source input."""
    text = text or (ROOT/'notes/chapter07_products_and_quotients.html').read_text()
    source = json.loads((ROOT/'notes/structures_inputs.json').read_text())['figures']['7.18h']
    class Tags(HTMLParser):
        def __init__(self, html):
            super().__init__(); self.paths=[]; self.nodes=[]; self.feed(html)
        def handle_starttag(self, tag, attrs):
            a=dict(attrs)
            if tag=='path' and a.get('class')=='edge': self.paths.append(a)
            if tag=='circle' and a.get('class')=='node': self.nodes.append(a)
    counts={}
    colors={'red':'#b54332','blue':'#3263a4','green':'#2c8149'}
    for figure, mode, count in [('ex718-h-before','node',16),('ex718-h-after','block',8)]:
        match=re.search(r'<figure id="'+figure+r'">(.*?)</figure>',text,re.S)
        need(match is not None,'7.18h source diagram absent: '+figure)
        drawn=Tags(match[1]);need(len(drawn.nodes)==count,'7.18h node count differs')
        observed=set()
        centers=[(float(n['cx']),float(n['cy'])) for n in drawn.nodes]
        for a in drawn.paths:
            c=a['data-source-color'];i=int(a['data-source-'+mode]);j=int(a['data-target-'+mode])
            need(0<=i<count and 0<=j<count,'7.18h invalid drawn endpoint')
            need(a.get('stroke')==colors[c],'7.18h source color mapping differs')
            need((c,i,j) not in observed,'7.18h duplicate drawn edge')
            observed.add((c,i,j))
            if mode=='node' and c=='red': observed.add((c,j,i))
            else: need('marker-end' in a,'7.18h directional arrow has no arrowhead')
            # Metadata alone is insufficient: path endpoints must meet those nodes.
            numbers=list(map(float,re.findall(r'-?(?:\d+(?:\.\d*)?|\.\d+)',a['d'])))
            need(len(numbers)>=4,'7.18h path has no endpoints')
            for point,k in [((numbers[0],numbers[1]),i),((numbers[-2],numbers[-1]),j)]:
                nearest=min(range(count),key=lambda n:math.dist(point,centers[n]))
                need(nearest==k and math.dist(point,centers[k])<=float(drawn.nodes[k]['r'])+6,
                     '7.18h path geometry does not meet declared node')
        expected={(c,i,source[c][i]) for c in colors for i in range(16)} if mode=='node' else {
            (c,i%8,source[c][i]%8) for c in colors for i in range(16)}
        need(observed==expected,'7.18h displayed arrows differ from original source action')
        counts[figure]=len(observed)
    return counts


def source_checks():
    data=json.loads((ROOT/'notes/structures_inputs.json').read_text())
    f=data['figures']['7.18fg'];r,b,t=[f[k] for k in ('red','blue','green')]
    need(b[r[0]]==r[b[0]] and b[r[8]]!=r[b[8]],'7.18fg source witness changed')
    need(len(perm_closure([r,b,t]))==64,'7.18fg action group order changed')
    for color,other in [(t,b),(b,r)]:
        parts={frozenset((i,color[i])) for i in range(16)}
        need(any(len({next(k for k,p in enumerate(parts) if other[x] in p) for x in block})>1 for block in parts),
             '7.18fg collapse unexpectedly single-valued')
    h=data['figures']['7.18h'];perms=perm_closure([h[k] for k in ('blue','green','red')])
    need(len(perms)==16 and len({p[0] for p in perms})==16,'7.18h not regular')
    bynode={p[0]:p for p in perms};table=[[bynode[y][x] for y in range(16)] for x in range(16)]
    H={0,8};cosets={frozenset(table[g][k] for k in H) for g in range(16)}
    need(cosets=={frozenset(table[k][g] for k in H) for g in range(16)},'7.18h H not normal')
    need(all(8 in s for s in all_subgroups(table) if len(s)==8),'7.18h nonsplit witness failed')
    # Quotient by central red pair: r^4=t^2=e, t*r*t=r^-1, eight cosets.
    q=lambda x:next(k for k,s in enumerate(cosets) if x in s)
    need(q(table[table[4][1]][4])==q(3) and len(cosets)==8,'7.18h quotient not D4')
    # Original matrices are read literally. Gaussian integer arithmetic is exact here.
    def mm(a,b):return tuple(sum(a[2*i+k]*b[2*k+j] for k in range(2)) for i in range(2) for j in range(2))
    counts=[]
    for gens in [((0,-1,-1,0),(0,1,1,0)),((0,-1,-1,0),(0,1j,1j,0))]:
        seen={(1,0,0,1)};queue=list(seen)
        for a in queue:
            for b in gens:
                p=mm(a,b)
                if p not in seen:seen.add(p);queue.append(p)
        need(all(mm(a,b)==mm(b,a) for a in seen for b in seen),'8.42a/b not abelian')
        counts.append(len(seen))
    need(counts==[4,8],'8.42 literal signs changed')
    old=json.loads((ROOT/'notes/algebra_inputs.json').read_text())['a4']
    red={x:y for c in old['red_cycles'] for x,y in zip(c,c[1:]+c[:1])}
    blue={x:y for x,y in old['blue_pairs']}|{y:x for x,y in old['blue_pairs']}
    words=graph_words(old['labels'],[red,blue]);gens=[(1,2,0,3),(1,0,3,2)];ps={}
    for label,word in words.items():
        p=tuple(range(4))
        for g in word:p=permutation_then(p,gens[g])
        ps[label]=p
    inverse={v:k for k,v in ps.items()}
    mul=lambda x,y:inverse[permutation_then(ps[x],ps[y])]
    inv=lambda x:next(y for y in ps if mul(x,y)=='e')
    need(mul(mul('y','b'),'y')=='d','7.37 conjugator failed')
    need(mul(mul(mul('a','x'),inv('a')),inv('x'))=='y','8.17 A4 commutator label failed')
    text=(ROOT/'notes/chapter06_subgroups.html').read_text()
    html=re.search(r'<table[^>]*id="table-a4-ch6".*?</table>',text,re.S)[0]
    rows=[[cell_text(v) for v in re.findall(r'<t[hd][^>]*>(.*?)</t[hd]>',row,re.S)] for row in re.findall(r'<tr[^>]*>(.*?)</tr>',html,re.S)]
    labels=[x.replace('²','2') for x in rows[0][1:]]
    need([[v.replace('²','2') for v in row[1:]] for row in rows[1:]]==[[mul(a,b) for b in labels] for a in labels],'6.31 displayed A4 table differs from four-vertex action')
    # Hand-read orbit answers, independently build arrows on source positions.
    for n,m,u,start,want in [(5,4,2,18,[18,12,9,0]),(8,2,3,11,[11,4,15,0])]:
        r=[j*n+(i+pow(u,j,n))%n for j in range(m) for i in range(n)]
        t=[((j+1)%m)*n+i for j in range(m) for i in range(n)]
        perms=perm_closure([r,t]);by={p[0]:p for p in perms};a=0;got=[]
        for _ in range(4):a=by[start][a];got.append(a)
        need(got==want,'5.15 source powers failed')
    # 5.33e: direct product realization, with b rather than b^-1 in last relation.
    op=lambda a,b:((a[0]+b[0])%4,(a[1]+b[1])%2)
    a,b=(1,0),(1,1)
    need(op(a,a)==op(b,b) and op(op(b,a),b)==(3,0),'5.33e literal presentation failed')
    return {'displayed_source_arrows':source_diagram_checks(),'invalid_7_18fg_action_order':64,'valid_7_18h_group_order':16,'source_matrix_orders':counts,'a4_displayed_entries':144,'source_orbits':2,'literal_5_33e':True}


def diagram_checks(text=None):
    """Read the displayed C24 lattice, checking divisibility and visual edge ambiguity."""
    text=text or (ROOT/'notes/chapter06_subgroups.html').read_text()
    svg=re.search(r'<figure id="ex624">(.*?)</figure>',text,re.S)[1]
    nodes={}
    for x,y,label in re.findall(r'<text x="([^"]+)" y="([^"]+)">([^<]+)</text>',svg):
        generator=1 if label=='G' else 24 if label=='{e}' else int(label.strip('⟨⟩'))
        nodes[(float(x),float(y)-5)]=generator
    need(set(nodes.values())=={1,2,3,4,6,8,12,24},'C24 lattice node labels changed')
    edges=set()
    for x,y,X,Y in re.findall(r'<path\b[^>]*\sd="M([\d.]+) ([\d.]+)L([\d.]+) ([\d.]+)"',svg):
        a,b=(float(x),float(y)),(float(X),float(Y))
        need(a in nodes and b in nodes,'C24 lattice edge misses a node')
        edges.add((nodes[a],nodes[b]))
        dx,dy=b[0]-a[0],b[1]-a[1];length2=dx*dx+dy*dy
        for point in nodes:
            if point in (a,b):continue
            u=((point[0]-a[0])*dx+(point[1]-a[1])*dy)/length2
            distance=math.hypot(point[0]-a[0]-u*dx,point[1]-a[1]-u*dy)
            need(not(0<u<1 and distance<22),'C24 lattice edge passes through an unrelated node')
    expected={(a,b) for a in nodes.values() for b in nodes.values() if a>b and a%b==0 and a//b in (2,3)}
    need(edges==expected and len(edges)==10,'C24 lattice cover edges do not encode prime-index containment')
    return {'c24_nodes':len(nodes),'c24_cover_edges':len(edges),'unrelated_node_crossings':0}


def mutation_checks():
    """Faults must be rejected by independent checks, never by modifying maintained files."""
    from unittest.mock import patch
    original_module=module
    caught=[]
    def reject(label, check, replacement):
        with patch(__name__+'.module',replacement):
            try:check()
            except ValueError as error:caught.append({'fault':label,'rejected_by':str(error)})
            else:raise ValueError('mutation survived: '+label)
    def reversed_compose(name):
        mod=original_module(name)
        if name=='permutations':mod.compose=lambda p,q:tuple(p[x] for x in q)
        return mod
    def untwisted_product(name):
        mod=original_module(name)
        if name=='products':mod.multiply=lambda a,b,n,m,u:(a%n+b%n)%n+n*((a//n+b//n)%m)
        return mod
    def missing_trivial_map(name):
        mod=original_module(name)
        if name=='homomorphisms':
            maps=mod.maps
            mod.maps=lambda m,n:(row for row in maps(m,n) if row[0]!=0)
        return mod
    reject('reverse temporal composition',permutation_checks,reversed_compose)
    reject('drop semidirect action',product_checks,untwisted_product)
    reject('omit trivial homomorphism',hom_checks,missing_trivial_map)
    text=(ROOT/'notes/chapter06_subgroups.html').read_text()
    # Replace the unique trivial node inside this figure regardless of layout coordinates.
    block=re.search(r'<figure id="ex624">.*?</figure>',text,re.S)[0]
    altered=text.replace(block,block.replace('>{e}</text>','>⟨7⟩</text>'))
    try:diagram_checks(altered)
    except ValueError as error:caught.append({'fault':'wrong C24 lattice node','rejected_by':str(error)})
    else:raise ValueError('wrong C24 lattice node survived')
    return caught


def cli_checks(run_dir):
    registered=json.loads((ROOT/'code/programs.json').read_text())['programs']
    valid={
      'permutations':[[],['1','1'],['2,1','1,2'],['2,3,1','2,1,3'],['2,3,4,5,6,7,8,1','8,7,6,5,4,3,2,1']],
      'subgroups':[[]]+[[str(n)] for n in range(1,7)],
      'products':[[]]+[list(map(str,p)) for p in valid_products()],
      'homomorphisms':[[]]+[[str(m),str(n)] for m in range(1,13) for n in range(1,13)]}
    programs=[p for p in registered if Path(p['files']['python']).stem in valid]
    need({Path(p['files']['python']).stem for p in programs}==set(valid),
         'chapters 5–8 program registration incomplete')
    invalid={
      'permutations':[[''],['1','1','1'],['0','1'],['1,1','1,2'],['1,','1,2'],['1','1,2'],['１','1'],['-1','1'],['9999999999999','1']],
      'subgroups':[['0'],['7'],['-1'],[''],['1','2'],['1.0'],['99999999999999999999'],['１']],
      'products':[['1','2','1'],['4','2','0'],['4','3','3'],['5','2','2'],['12','6','1'],['4','2'],['-4','2','1'],['4','2','1','0'],['4','2','9999999999999999999']],
      'homomorphisms':[['0','2'],['13','2'],['1'],['1','2','3'],['1.5','2'],['１','2'],['-1','2'],['0001','2'],['999999999999999','2']]}
    commands=[];runs=0
    for program in programs:
        name=Path(program['files']['python']).stem
        for variant,flags in [('release',['-O2']),('sanitized',['-O1','-g','-fsanitize=address,undefined','-fno-omit-frame-pointer'])]:
            binary=run_dir/(name+'-'+variant)
            cmd=['clang','-std=c11','-Wall','-Wextra','-Werror','-pedantic']+flags+[str(ROOT/program['files']['c']),'-o',str(binary)]
            subprocess.run(cmd,check=True,capture_output=True,text=True);commands.append(' '.join(cmd))
            for args in valid[name]:
                py=subprocess.run([sys.executable,str(ROOT/program['files']['python'])]+args,capture_output=True,text=True)
                c=subprocess.run([str(binary)]+args,capture_output=True,text=True);runs+=2
                need(py.returncode==c.returncode==0 and py.stdout==c.stdout and not c.stderr and not py.stderr,'C/Python output mismatch: '+name+' '+str(args))
                if not args:need(c.stdout==program['expected_stdout'],'registered stdout stale')
            for args in invalid[name]:
                for driver in ([str(binary)],[sys.executable,str(ROOT/program['files']['python'])]):
                    result=subprocess.run(driver+args,capture_output=True,text=True);runs+=1
                    need(result.returncode==2 and not result.stdout and result.stderr,'invalid input accepted: '+name+' '+str(args))
    return {'process_runs':runs,'c_builds':commands,'sanitizers':'ASan and UBSan in all four programs'}


def run(run_dir):
    return {'permutations':permutation_checks(),'subgroups':subgroup_checks(),'products':product_checks(),
            'homomorphisms':hom_checks(),'source':source_checks(),'diagrams':diagram_checks(),'mutations':mutation_checks(),'cli':cli_checks(run_dir)}
