#!/usr/bin/env python3
"""Exact finite kernel / Bernoulli masses; floating characteristic function."""
import json
import math
import re
import sys


def integer(text, maximum):
    if len(text) > 10 or re.fullmatch(r'[0-9]+', text) is None:
        raise ValueError('expected ASCII unsigned decimal integer')
    value = int(text)
    if value > maximum:
        raise ValueError('integer exceeds bound')
    return value


def joint(p, a, b, m):
    weights = [(m-p)*(m-a), (m-p)*a, p*(m-b), p*b]
    rows = [sum(weights[:2]), sum(weights[2:])]
    cols = [weights[0]+weights[2], weights[1]+weights[3]]
    values = [0, 2, 1, 3]  # Z=X+2Y; row-major (0,0),(0,1),(1,0),(1,1).
    return dict(mode='joint', denominator=m*m, weights=weights,
                row_weights=rows, col_weights=cols,
                expectation_numerator=sum(w*z for w, z in zip(weights, values)),
                iterated_numerator=(m-p)*2*a+p*((m-b)+3*b),
                independent=weights[0]*weights[3] == weights[1]*weights[2])


def binomial(n, p, m):
    weights = [1]
    denominator = 1
    for _ in range(n):
        following = [0]*(len(weights)+1)
        for k, weight in enumerate(weights):
            following[k] += (m-p)*weight
            following[k+1] += p*weight
        weights = following
        denominator *= m
    variance_num = n*p*(m-p)
    cf = None
    if variance_num:
        mean = n*p/m
        sd = math.sqrt(variance_num)/m
        cf = [sum(w*math.cos((k-mean)/sd) for k, w in enumerate(weights))/denominator,
              sum(w*math.sin((k-mean)/sd) for k, w in enumerate(weights))/denominator]
    return dict(mode='binomial', denominator=denominator, weights=weights,
                mean_numerator=sum(k*w for k, w in enumerate(weights)),
                variance_numerator=variance_num, variance_denominator=m*m,
                normalizable=bool(variance_num), standardized_cf_t1=cf)


def main(args):
    if len(args) == 5 and args[0] == 'joint':
        p, a, b, m = [integer(v, 1000) for v in args[1:]]
        if m == 0 or max(p, a, b) > m:
            raise ValueError('joint requires 1<=m<=1000 and 0<=p,a,b<=m')
        return joint(p, a, b, m)
    if len(args) == 4 and args[0] == 'binomial':
        n, p, m = [integer(v, bound) for v, bound in zip(args[1:], (16, 8, 8))]
        if m == 0 or p > m:
            raise ValueError('binomial requires 0<=n<=16, 1<=m<=8, 0<=p<=m')
        return binomial(n, p, m)
    raise ValueError('usage: product_limits.py joint p a b m | binomial n p m')


if __name__ == '__main__':
    try:
        print(json.dumps(main(sys.argv[1:]), separators=(',', ':'), allow_nan=False))
    except ValueError as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
