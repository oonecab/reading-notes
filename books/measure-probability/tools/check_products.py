"""Independent atom enumeration / binomial coefficient checks for Chapters 5–6."""
from fractions import Fraction as F
import cmath
import copy
import itertools
import json
import math
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def require(ok, message):
    if not ok:
        raise ValueError(message)


def verify(args, row):
    mode, *vals = args
    if mode == 'joint':
        p, a, b, m = map(int, vals)
        probabilities = []
        for x, y in itertools.product((0, 1), repeat=2):
            px = F(p if x else m-p, m)
            py = F((b if x else a) if y else m-(b if x else a), m)
            probabilities.append(px*py)
        require(row['denominator'] == m*m, 'joint denominator')
        actual = [F(w, row['denominator']) for w in row['weights']]
        require(actual == probabilities and sum(actual) == 1, 'joint atoms')
        xs, ys = [(0,0),(0,1),(1,0),(1,1)], (0,1)
        marg_x = [sum(q for q,(x,y) in zip(actual,xs) if x == v) for v in ys]
        marg_y = [sum(q for q,(x,y) in zip(actual,xs) if y == v) for v in ys]
        require([F(w,m*m) for w in row['row_weights']] == marg_x, 'row marginal')
        require([F(w,m*m) for w in row['col_weights']] == marg_y, 'column marginal')
        # Layer-cake E Z = P(Z>=1)+P(Z>=2)+P(Z>=3), independent of weighted-value loop.
        expectation = sum(sum(q for q,(x,y) in zip(actual,xs) if x+2*y >= k) for k in (1,2,3))
        require(F(row['expectation_numerator'],m*m) == expectation, 'layer-cake expectation')
        require(F(row['iterated_numerator'],m*m) == expectation, 'kernel iterated expectation')
        independent = all(q == marg_x[x]*marg_y[y] for q,(x,y) in zip(actual,xs))
        require(row['independent'] == independent, 'all-atom independence')
    else:
        n, p, m = map(int, vals)
        denominator = m**n
        expected = [math.comb(n,k)*p**k*(m-p)**(n-k) for k in range(n+1)]
        require(row['denominator'] == denominator and row['weights'] == expected, 'binomial coefficients')
        probs = [F(w,denominator) for w in expected]
        require(sum(probs) == 1, 'total mass')
        mean = sum(k*q for k,q in enumerate(probs))
        variance = sum((k-mean)**2*q for k,q in enumerate(probs))
        require(F(row['mean_numerator'],denominator) == mean, 'enumerated mean')
        require(F(row['variance_numerator'],row['variance_denominator']) == variance, 'enumerated variance')
        require(row['normalizable'] == (variance > 0), 'zero variance flag')
        if variance == 0:
            require(row['standardized_cf_t1'] is None, 'zero variance must not normalize')
        else:
            sd = math.sqrt(float(variance))
            # Independent product of the one-step centered characteristic functions.
            cf = ((1-p/m)*cmath.exp(-1j*(p/m)/sd)+(p/m)*cmath.exp(1j*(1-p/m)/sd))**n
            actual = complex(*row['standardized_cf_t1'])
            require(abs(actual-cf) < 2e-12, 'characteristic product')
        if n <= 6:
            enumerated = [F(0)]*(n+1)
            for outcomes in itertools.product((0,1),repeat=n):
                prob = F(1)
                for x in outcomes:
                    prob *= F(p if x else m-p,m)
                enumerated[sum(outcomes)] += prob
            require(enumerated == probs, 'independent path enumeration')


def run(run_dir):
    run_dir.mkdir(parents=True,exist_ok=True)
    cases = []
    for m in (1,2,3,4):
        for p,a,b in itertools.product(range(m+1),repeat=3):
            cases.append(['joint',*map(str,(p,a,b,m))])
    cases += [['joint','333','0','1000','1000'],['joint','1000','1000','1000','1000']]
    for n in (0,1,2,4,6,16):
        for m in (1,2,3,8):
            for p in sorted({0,1,m//2,m}):
                cases.append(['binomial',*map(str,(n,p,m))])
    invalid=[[],['joint'],['oops','1','1','1'],['joint','1','1','1','0'],
             ['joint','5','1','1','4'],['joint','1','5','1','4'],['joint','1','1','5','4'],
             ['joint','1','1','1','1001'],['binomial','17','1','2'],['binomial','2','3','2'],
             ['binomial','2','1','0'],['binomial','2','1','9'],['binomial','2','1','2','extra']]
    for token in ('','-0','-1','+1',' 1','1 ','1.0','１','1_0','9'*100,'0'*11):
        invalid.append(['joint',token,'1','1','4'])
        invalid.append(['binomial',token,'1','2'])
    drivers=[[sys.executable,str(ROOT/'code/product_limits.py')]];builds=[]
    for label,flags in [('release',['-O2']),('sanitized',['-O1','-g','-fsanitize=address,undefined','-fno-omit-frame-pointer'])]:
        binary=run_dir/('product_limits-'+label)
        cmd=['clang','-std=c11','-Wall','-Wextra','-Werror','-pedantic',*flags,str(ROOT/'code/product_limits.c'),'-lm','-o',str(binary)]
        subprocess.run(cmd,check=True,capture_output=True,text=True);builds.append(cmd);drivers.append([str(binary)])
    results=[];executions=0
    for i,driver in enumerate(drivers):
        for args in cases:
            proc=subprocess.run(driver+args,capture_output=True,text=True)
            require(proc.returncode==0 and not proc.stderr,'valid CLI failed: '+proc.stderr)
            row=json.loads(proc.stdout);verify(args,row);executions+=1
            if i==0:results.append(row)
        for args in invalid:
            proc=subprocess.run(driver+args,capture_output=True,text=True)
            require(proc.returncode==2 and not proc.stdout and bool(proc.stderr),'invalid input contract')
            executions+=1
    rejected=[]
    for label,mode,key in [('kernel_mass','joint','weights'),('conditional_weight','joint','iterated_numerator'),
                           ('kernel_independence','joint','independent'),('binomial_coefficient','binomial','weights'),
                           ('binomial_variance','binomial','variance_numerator'),('normalization','binomial','standardized_cf_t1')]:
        index=next(i for i,args in enumerate(cases) if args==(['joint','1','1','3','4'] if mode=='joint' else ['binomial','4','1','2']))
        row=copy.deepcopy(results[index])
        if key=='weights':row[key][0]+=1
        elif key=='independent':row[key]=not row[key]
        elif key=='standardized_cf_t1':row[key][0]+=0.1
        else:row[key]+=1
        try:verify(cases[index],row)
        except ValueError:rejected.append(label)
        else:raise ValueError('accepted mutant '+label)
    # Exact finite variance scaling of empirical CDF; original denominator loses n^2.
    n=16;p=F(1,2);mean_var=p*(1-p)/n
    require(mean_var/(p*(1-p)/n)==1 and mean_var/(n*p*(1-p))==F(1,n*n),'empirical scale fixture')
    # Lemma 6.4.4: mass 3/4 at 0 and 1/4 at 2*pi.
    require(all(0.75+0.25*math.cos(2*math.pi*t)>=0.5-1e-15 for t in [k/64 for k in range(65)]),'positive real cf')
    require(abs(math.log(0.75+0.25*math.cos(2*math.pi)))<1e-15 and math.pi**2>0,'fixed frequency counterexample')
    report=dict(valid_cases=len(cases),invalid_cases=len(invalid),cli_executions=executions,builds=builds,
                oracles=['exact atom fractions and all-atom independence','layer-cake finite expectation','binomial coefficients','all binary paths for n<=6','centered one-step CF product'],
                mutations_rejected=rejected,scope='Finite models and correction fixtures; no simulation is used as proof of an infinite limit.')
    (run_dir/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    return report
