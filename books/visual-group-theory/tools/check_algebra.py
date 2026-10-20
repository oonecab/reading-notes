"""Independent finite oracles for chapters 2--4; no third-party packages."""
from html import unescape
import importlib.util
import itertools
import json
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

from check_reading import spelling

ROOT = Path(__file__).resolve().parents[1]


def need(condition, message):
    if not condition:
        raise ValueError(message)


def module(name):
    spec = importlib.util.spec_from_file_location('vgt_' + name, ROOT / 'code' / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def cell_text(fragment):
    """Read the displayed MathML, excluding its duplicate copy annotation."""
    superscripts = str.maketrans('0123456789+−=()ni', '⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ⁿⁱ')
    subscripts = str.maketrans('0123456789+−=()aeijoruvx', '₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎ₐₑᵢⱼₒᵣᵤᵥₓ')

    def math_text(match):
        value = spelling(ET.fromstring(match[0]))
        value = re.sub(r'\^\{([0123456789+−=()ni]+)\}',
                       lambda m: m[1].translate(superscripts), value)
        return re.sub(r'_\{([0123456789+−=()aeijoruvx]+)\}',
                      lambda m: m[1].translate(subscripts), value)

    fragment = re.sub(r'<math\b[^>]*>.*?</math>', math_text, fragment, flags=re.S)
    return unescape(re.sub('<[^>]+>', '', fragment)).strip()


def html_table(identifier):
    text = (ROOT/'notes/chapter04_algebra_at_last.html').read_text()
    found = re.search(r'<table\b[^>]*id="' + re.escape(identifier) + r'".*?</table>', text, re.S)
    need(found is not None, 'missing table ' + identifier)
    rows = []
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>', found[0], re.S):
        rows.append([cell_text(x)
                     for x in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>', row, re.S)])
    need(rows[0][1:] == [r[0] for r in rows[1:]], 'table labels do not align')
    return rows[0][1:], [r[1:] for r in rows[1:]]


def graph_words(names, colors):
    words = {names[0]: []}
    queue = [names[0]]
    for a in queue:
        for i, color in enumerate(colors):
            b = color[a]
            if b not in words:
                words[b] = words[a] + [i]
                queue.append(b)
    need(set(words) == set(names), 'source diagram disconnected')
    return words


def permutation_then(a, b):
    return tuple(b[i] for i in a)


def source_oracles():
    # A stale accessible label must not conceal a changed displayed exponent.
    fixture = ('<math aria-label="a²"><semantics><msup><mi>a</mi><mn>2</mn>'
               '</msup><annotation encoding="text/plain">a²</annotation></semantics></math>')
    need(cell_text(fixture) == cell_text('a²') == 'a²', 'MathML table-cell decoding failed')
    need(cell_text(fixture.replace('<mn>2</mn>', '<mn>3</mn>')) == 'a³',
         'MathML table reader trusts stale annotation')
    data = json.loads((ROOT/'notes/algebra_inputs.json').read_text())
    # The printed D_n tables are checked on actual polygon vertices, independently
    # of the normal-form multiplication used to construct the tables.
    polygon_entries = 0
    for n, identifier in [(3, 's3-table'), (4, 'd4-table'), (5, 'd5-table')]:
        labels, rows = html_table(identifier)
        permutations = [tuple(((-1)**j * (x+i)) % n for x in range(n))
                        for j in range(2) for i in range(n)]
        expected = [[labels[permutations.index(permutation_then(a,b))]
                     for b in permutations] for a in permutations]
        need(rows == expected, 'displayed polygon table fails vertex oracle')
        polygon_entries += (2*n)**2
    a = data['a4']
    red = {x:y for c in a['red_cycles'] for x,y in zip(c,c[1:]+c[:1])}
    blue = {x:y for x,y in a['blue_pairs']} | {y:x for x,y in a['blue_pairs']}
    words = graph_words(a['labels'], [red,blue])
    # Independent action model on FOUR objects; source graph has TWELVE nodes.
    generators = [(1,2,0,3), (1,0,3,2)]
    permutations = {}
    for label, word in words.items():
        perm = tuple(range(4))
        for g in word:
            perm = permutation_then(perm,generators[g])
        permutations[label] = perm
    need(len(set(permutations.values())) == 12, 'A4 permutations not distinct')
    for label in a['labels']:
        for g, color in enumerate((red,blue)):
            need(permutation_then(permutations[label],generators[g]) == permutations[color[label]],
                 'A4 source edge fails independent four-object model')
    inverse_map = {v:k for k,v in permutations.items()}
    show = lambda x: re.sub(r'([abcd])2', r'\1²', x)
    labels, rows = html_table('a4-table')
    expected = [[show(inverse_map[permutation_then(permutations[x],permutations[y])])
                 for y in a['labels']] for x in a['labels']]
    need(labels == list(map(show,a['labels'])) and rows == expected, 'A4 displayed table mismatch')
    # Exact 2x2 complex matrices; temporal product means matrix B times A.
    def mm(a,b):
        return tuple(sum(a[2*i+k]*b[2*k+j] for k in range(2)) for i in range(2) for j in range(2))
    mats = [(1,0,0,1),(1j,0,0,-1j),(0,1,-1,0),(0,1j,1j,0)]
    mats += [tuple(-x for x in m) for m in mats]
    qnames = data['q4']['labels']
    qexpected = [[qnames[mats.index(mm(b,a))] for b in mats] for a in mats]
    need(html_table('q4-table') == (qnames,qexpected), 'Q4 table fails matrix oracle')
    for field, generator in [('red_cycles',1),('blue_cycles',2)]:
        for cycle in data['q4'][field]:
            for x,y in zip(cycle,cycle[1:]+cycle[:1]):
                need(qexpected[qnames.index(x)][generator] == y, 'Q4 source arrow mismatch')
    for key, given in data['given_tables'].items():
        need(html_table('given-'+key.replace('.','-')) == (given['labels'],given['rows']),
             'source question table drifted: '+key)
    # Verify the algebra answers by substitution, including source-label correction.
    amul = lambda x,y: inverse_map[permutation_then(permutations[x],permutations[y])]
    need(amul(amul('b','x'),'a2') == 'y', '4.29 substitution failed')
    need(amul(amul('b2','a'),'y') == 'e', '4.29 correction failed')
    need(amul('b2',amul('b2','b2')) == amul(amul('x','y'),'z'), '4.30b failed')
    qmul = lambda x,y:qexpected[qnames.index(x)][qnames.index(y)]
    need(qmul(qmul('i','−j'),'−i') == 'j', '4.28b failed')
    need(qmul(qmul(qmul('j','i'),'−i'),'−k') == qmul('k','j'), '4.30a failed')
    # Demonstrate why the two source diagrams are not regular Cayley diagrams.
    def walk(diagram,start,word):
        for g in word:
            start = diagram['red' if g=='r' else 'blue'][start]
        return start
    left,right = data['false_diagrams'].values()
    need(walk(left,0,'rb') == walk(left,0,'br') and walk(left,1,'rb') != walk(left,1,'br'),
         '4.16 left witness failed')
    need(walk(right,0,'b') == walk(right,0,'brr') and walk(right,4,'b') != walk(right,4,'brr'),
         '4.16 right witness failed')
    return data, {'a4_entries':144,'q4_entries':64,'polygon_table_entries':polygon_entries,
                  'source_input_tables':len(data['given_tables']),
                  'equation_and_false_diagram_witnesses':7}


def cayley_oracle(mod):
    cases = 0
    for n in range(3,13):
        states,words,edges = mod.enumerate_group(n)
        perms = [tuple((s*x+k)%n for x in range(n)) for s,k in states]
        expected = {tuple((s*x+k)%n for x in range(n)) for s in (-1,1) for k in range(n)}
        need(set(perms) == expected and len(states) == 2*n, 'polygon reachability incorrect')
        for i,perm in enumerate(perms):
            for g in range(2):
                dest = edges[i][g]
                expected_perm = tuple((x+1)%n if g==0 else (-x)%n for x in perm)
                need(perms[dest] == expected_perm, 'polygon edge disagrees with vertex oracle')
                cases += 1
            actual = tuple(range(n))
            for letter in words[i]:
                actual = tuple((x+1)%n if letter=='r' else (-x)%n for x in actual)
            need(actual == perm, 'word does not reach advertised permutation')
            need(all(len(words[d]) <= len(words[i])+1 for d in edges[i]), 'BFS shortest distance failed')
    return cases


def frieze_oracle(mod):
    count = 0
    for length in range(7):
        for word in map(''.join,itertools.product('hgG',repeat=length)):
            sx,sy,dx = mod.evaluate(word)
            for x,y in [(0,0),(1,0),(0,1),(2,-3)]:
                a,b=x,y
                for letter in word:
                    if letter=='h': a=-a
                    elif letter=='g': a,b=a+1,-b
                    else: a,b=a-1,-b
                need((a,b)==(sx*x+dx,sy*y), 'affine action disagrees with point oracle')
                count += 1
            inverse = ''.join({'h':'h','g':'G','G':'g'}[x] for x in word[::-1])
            need(mod.evaluate(word+inverse)==(1,1,0), 'inverse word failed')
    return count


def group_by_translations(t):
    """Independent criterion: left translations form a regular permutation group."""
    n=len(t);symbols=set(range(n))
    if any(set(row)!=symbols for row in t):
        return False
    if any({t[i][j] for i in range(n)}!=symbols for j in range(n)):
        return False
    if not any(all(t[e][i]==t[i][e]==i for i in range(n)) for e in range(n)):
        return False
    translations={tuple(row) for row in t}
    return all(tuple(a[b[i]] for i in range(n)) in translations
               for a in translations for b in translations)


def table_oracle(mod):
    total=0;counts={}
    for n in range(1,4):
        groups=0
        for entries in itertools.product(range(n),repeat=n*n):
            t=[list(entries[i*n:(i+1)*n]) for i in range(n)]
            want=group_by_translations(t)
            need(mod.check(t)[1]==want, 'finite-table classification disagrees with regular translations')
            total+=1;groups+=want
        counts[n]=groups
    need(counts=={1:1,2:2,3:3}, 'unexpected small labelled group count')
    completions=[]
    for a,b,c in itertools.product(*[[p for p in itertools.permutations(range(4)) if p[0]==i] for i in [1,2,3]]):
        t=[list(range(4)),list(a),list(b),list(c)]
        if group_by_translations(t):
            completions.append(t)
    need(len(completions)==4, 'four-element completions unexpected')
    for condition,table_id in [(2,'small-19d'),(3,'small-19e')]:
        matched=[t for t in completions if t[1][1]==condition]
        displayed=html_table(table_id)[1]
        need(len(matched)==1 and displayed==[[str(x) for x in row] for row in matched[0]],
             'small group unique completion mismatch')
    two=[t for t in completions if t[1][1]==0]
    actual=[[[int(x) for x in row] for row in html_table(i)[1]] for i in ['small-20v','small-20c']]
    need(len(two)==2 and all(t in two for t in actual) and actual[0]!=actual[1],
         '4.20 does not contain exactly all completions')
    return total, counts


def run(run_dir):
    cm,fm,tm = (module(x) for x in ['cayley','frieze','tables'])
    data,source = source_oracles()
    polygon_cases=cayley_oracle(cm)
    frieze_cases=frieze_oracle(fm)
    table_cases,counts=table_oracle(tm)
    drivers={}
    commands=[]
    for name in ['cayley','frieze','tables']:
        drivers[name]=[[sys.executable,str(ROOT/'code'/f'{name}.py')]]
        for suffix,flags in [('o2',['-O2']),('san',['-O1','-g','-fsanitize=address,undefined','-fno-omit-frame-pointer'])]:
            binary=run_dir/f'{name}-{suffix}'
            cmd=['clang','-std=c11','-Wall','-Wextra','-Werror','-pedantic']+flags+[str(ROOT/'code'/f'{name}.c'),'-o',str(binary)]
            subprocess.run(cmd,check=True,capture_output=True,text=True)
            commands.append(' '.join(cmd))
            drivers[name].append([str(binary)])
    cli=0
    def compare(name,args,input=None,code=0,expected=None):
        nonlocal cli
        outputs=[]
        for driver in drivers[name]:
            result=subprocess.run(driver+args,input=input,capture_output=True,text=True)
            need(result.returncode==code, f'{name} wrong return code: {args[:1]} {result.stderr[:200]}')
            if code==2:
                need(not result.stdout and result.stderr, 'input failure must only write stderr')
            else:
                need(not result.stderr,'unexpected stderr')
                if expected is not None:need(result.stdout==expected,'CLI disagrees with independent expected output')
                outputs.append(result.stdout)
            cli+=1
        need(not outputs or all(x==outputs[0] for x in outputs),'C/Python outputs differ')
    for n in range(3,13):compare('cayley',[str(n)])
    for args in [['2'],['13'],['03'],['+4'],['4','5'],['x']]:compare('cayley',args,code=2)
    compare('cayley',[])
    words=[''.join(x) for n in range(5) for x in itertools.product('hgG',repeat=n)]
    for word in words+['g'*10000,'hgh','hghg']:
        sx,sy,dx=fm.evaluate(word)
        compare('frieze',[word],expected=f'word sx sy dx\n{word or "e"} {sx} {sy} {dx}\n')
    compare('frieze',[])
    for args in [['g'*10001],['e'],['g h'],['g','h'],['🙂']]:compare('frieze',args,code=2)
    sample_tables=[[[0]],[[i^j for j in range(4)] for i in range(4)],
                   [[(i+j)%16 for j in range(16)] for i in range(16)]]
    for given in data['given_tables'].values():
        labels=given['labels']
        sample_tables.append([[labels.index(x) if x in labels else len(labels) for x in row] for row in given['rows']])
    for identifier in ['c5-table','q4-table','a4-table','s3-table','d4-table','d5-table']:
        labels,rows=html_table(identifier)
        sample_tables.append([[labels.index(x) for x in row] for row in rows])
    for t in sample_tables:
        expected,is_group=tm.check(t)
        input=str(len(t))+'\n'+'\n'.join(' '.join(map(str,row)) for row in t)+'\n'
        compare('tables',['--stdin'],input,0 if is_group else 1,'\n'.join(expected)+'\n')
    compare('tables',[])
    compare('tables',['--stdin'],' \t\n1\v\f0\r ',expected='CLOSURE OK\nASSOCIATIVE OK\nIDENTITY 0\nINVERSES OK\nGROUP YES\n')
    for separator in ['\x1c','\x1d','\x1e','\x1f']:
        compare('tables',['--stdin'],'1'+separator+'0',code=2)
    for text in ['', '0', '17', '2 0 1 1', '1 0 0', '1 a', '1 12345', '1 +0','1 ０']:
        compare('tables',['--stdin'],text,code=2)
    compare('tables',['wrong'],code=2)
    mutations=[]
    for name,old,new,oracle in [
        ('cayley','(-sign, (-shift) % n)','(-sign, shift % n)',cayley_oracle),
        ('frieze','sx, dx = -sx, -dx','sx, dx = -sx, dx',frieze_oracle)]:
        source_code=(ROOT/'code'/f'{name}.py').read_text()
        mutated=source_code.replace(old,new)
        need(mutated!=source_code,'mutation did not change code')
        namespace={'__name__':'mutated'}
        exec(compile(mutated,name,'exec'),namespace)
        from types import SimpleNamespace
        try:oracle(SimpleNamespace(**namespace))
        except ValueError:mutations.append(name+': incorrect reflection rejected')
        else:raise ValueError('oracle accepted mutation')
    # A Latin square alone is insufficient: preserve the actual associativity counterexamples.
    need(tm.check([[0,1,2],[1,0,0],[2,0,0]])[1] is False,'4.10 was accepted')
    return {'source_math':source,'polygon_edge_cases':polygon_cases,'frieze_point_cases':frieze_cases,
            'all_tables_up_to_order_3':table_cases,'labelled_group_counts':counts,
            'cli_runs':cli,'c_build_commands':commands,'mutations_rejected':mutations}
