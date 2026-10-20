#!/usr/bin/env python3
"""I015: wrong targets and incomplete processes must fail the real HTML gate."""
from fractions import Fraction as F
from pathlib import Path
import re
import sys
import unittest
import itertools
import math

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'books/stochastic/tools'))
from html_support import Document, Element
from derivation_coverage import (SAMPLE_PAGE, inventory, load_documents, mentions,
                                 mentions_result, target_for, validate)


class DerivationGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.documents = load_documents()
        cls.source = cls.documents[SAMPLE_PAGE].source

    def modified(self, start, end, replacement):
        docs = dict(self.documents)
        docs[SAMPLE_PAGE] = Document(self.source[:start] + replacement + self.source[end:])
        return validate(docs, [SAMPLE_PAGE])

    def node(self, anchor):
        return target_for(self.documents, SAMPLE_PAGE, '#' + anchor)[1]

    def test_full_inventory_is_not_a_sample(self):
        report = inventory(self.documents)
        self.assertEqual(report['counts'], {'Result': 115, 'Example': 162, 'Exercise': 236})
        self.assertEqual(len(report['records']), 513)
        self.assertEqual(len(report['page_sha256']), 9)
        self.assertTrue(all(r['target_id'] for r in report['records'] if r['kind'] == 'Exercise'))

    def test_sample_acceptance(self):
        self.assertEqual(validate(self.documents, [SAMPLE_PAGE]), [])

    def test_whole_book_acceptance_and_removed_proofs_fail(self):
        self.assertEqual(validate(self.documents), [])
        for page, anchor, label in [
            ('chapter04_continuous_time_markov_chains.html', 'lemma-4-10', 'Lemma 4.10:'),
            ('appendix_a_probability_review.html', 'theorem-A-7', 'Theorem A.7:'),
        ]:
            doc = self.documents[page]
            statement = target_for(self.documents, page, '#' + anchor)[1]
            link = next(a for a in statement.walk('a') if a.has_class('proof-link'))
            docs = dict(self.documents)
            docs[page] = Document(doc.source[:link.start] + doc.source[link.end:])
            self.assertTrue(any(label + ' missing complete-proof link' in e for e in validate(docs)))

    def test_original_wrong_target_fails(self):
        statement = self.node('theorem-1-19')
        link = next(a for a in statement.walk('a') if a.has_class('proof-link'))
        errors = self.modified(link.start, link.end,
                               '<a class="proof-link" href="#derive-c1-period-cost">完整证明 →</a>')
        self.assertTrue(any('Theorem 1.19: proof target does not cover' in e for e in errors))

    def test_number_reference_without_dedicated_proof_fails(self):
        proof = self.node('body-review-s18')
        content = self.source[proof.start:proof.end].replace('data-proof-for="Theorem:1.19"', '')
        errors = self.modified(proof.start, proof.end, content)
        self.assertTrue(any('Theorem 1.19: missing explicit item-specific proof' in e for e in errors))

    def test_wrong_kind_fails_even_with_same_visible_number(self):
        proof = self.node('body-review-s18')
        content = self.source[proof.start:proof.end].replace('data-proof-for="Theorem:1.19"', 'data-proof-for="Lemma:1.19"')
        errors = self.modified(proof.start, proof.end, content)
        self.assertTrue(any('Theorem 1.19: missing explicit item-specific proof' in e for e in errors))

    def test_empty_proof_fails(self):
        proof = self.node('body-review-s18')
        sequence = next(n for n in proof.walk('ol') if n.has_class('proof-steps'))
        errors = self.modified(sequence.content_start, sequence.content_end, '<li>证明略。</li>')
        self.assertTrue(any('Theorem 1.19: fewer than three' in e for e in errors))
        self.assertTrue(any('Theorem 1.19: empty/template' in e for e in errors))

    def test_orphan_proof_fails(self):
        end = self.source.index('</main>')
        errors = self.modified(end, end, '<div class="source-review" id="unlinked-regression">测试孤块</div>')
        self.assertTrue(any('#unlinked-regression: source-review has no inbound link' in e for e in errors))

    def test_deleted_example_result_fails_with_three_steps_remaining(self):
        example = self.node('example-1-18')
        result = next(n for n in example.walk('li') if n.has_class('result-check'))
        errors = self.modified(result.start, result.end, '')
        self.assertTrue(any('Example 1.18: missing explicit result/check step' in e for e in errors))

    def test_template_exercise_step_fails(self):
        ex = self.node('ex-1-20')
        sequence = next(n for n in ex.walk('ol') if n.has_class('solution-steps'))
        step = next(n for n in sequence.children if isinstance(n, Element) and n.tag == 'li')
        errors = self.modified(step.start, step.end, '<li>本题与前面相同，代入即可，类似可得最终答案。</li>')
        self.assertTrue(any('Exercise 1.20: empty/template step' in e for e in errors))

    def test_number_matching_is_exact_and_ranges_are_explicit(self):
        def node(text):
            return Element('p', children=[text])
        self.assertFalse(mentions(node('定理 1.10'), '1.1'))
        self.assertFalse(mentions(node('收益 1.1-225 单位'), '1.19'))
        self.assertTrue(mentions(node('定理 1.19–1.23'), '1.21'))
        self.assertFalse(mentions_result(node('例 4.10 的计算'), '4.10'))
        self.assertTrue(mentions_result(node('引理 4.10'), '4.10'))


class ExactCalculationTests(unittest.TestCase):
    """Independent small models verify the less obvious newly expanded numbers."""
    def stationary(self, matrix, weights):
        p = [[F(str(x)) for x in row] for row in matrix]
        total = sum(weights)
        pi = [F(x, total) for x in weights]
        self.assertTrue(all(sum(row) == 1 for row in p))
        self.assertEqual([sum(pi[i] * p[i][j] for i in range(len(pi)))
                          for j in range(len(pi))], pi)
        return pi

    def test_social_and_machine_examples(self):
        self.stationary([['.7','.2','.1'],['.3','.5','.2'],['.2','.4','.4']], [22,16,9])
        pi = self.stationary([['.5','.5',0,0],['.05','.5','.45',0],
                              [0,'.1','.5','.4'],[0,0,'.3','.7']], [1,10,45,60])
        self.assertEqual(sum(i*x for i,x in enumerate(pi)), F(70,29))

    def test_inbreeding_exit_times_and_probabilities(self):
        p = [[F(x) for x in row] for row in [
            [1,0,0,0,0,0],['1/4','1/2',0,'1/4',0,0], [0,0,0,1,0,0],
            ['1/16','1/4','1/8','1/4','1/4','1/16'], [0,0,0,'1/4','1/2','1/4'], [0,0,0,0,0,1]]]
        g = [F(x) for x in [0,'29/6','20/3','17/3','29/6',0]]
        h = [F(x) for x in [1,'3/4','1/2','1/2','1/4',0]]
        for i in range(1,5):
            self.assertEqual(g[i], 1+sum(p[i][j]*g[j] for j in range(6)))
            self.assertEqual(h[i], sum(p[i][j]*h[j] for j in range(6)))

    def test_inbreeding_original_positive_time_boundary(self):
        """Exercise 1.66 uses n > 0; a chain already absorbed waits one step.

        After the first step, use a time-zero remaining wait. Feeding the
        positive-time boundary value back into the recurrence overcounts it.
        """
        p = [[F(x) for x in row] for row in [
            [1,0,0,0,0,0], ['1/4','1/2',0,'1/4',0,0], [0,0,0,1,0,0],
            ['1/16','1/4','1/8','1/4','1/4','1/16'],
            [0,0,0,'1/4','1/2','1/4'], [0,0,0,0,0,1]]]
        remaining = [F(x) for x in [0,'29/6','20/3','17/3','29/6',0]]
        original = [F(x) for x in [1,'29/6','20/3','17/3','29/6',1]]
        for i in range(6):
            self.assertEqual(original[i], 1+sum(p[i][j]*remaining[j] for j in range(6)))
        self.assertNotEqual(original[1], 1+sum(p[1][j]*original[j] for j in range(6)))

    def test_smoking_finite_time_and_queen_degree(self):
        x = F(7,10)
        for _ in range(10):
            x = F(8,100)+F(67,100)*x
        self.assertEqual(format(float(x), '.9f'), '0.250765106')
        degrees = [14+min(i-1,j-1)+min(i-1,8-j)+min(8-i,j-1)+min(8-i,8-j)
                   for i in range(1,9) for j in range(1,9)]
        self.assertEqual(sum(degrees), 1456)
        self.assertEqual(F(sum(degrees), degrees[0]), F(208,3))

    def test_all_48_displayed_eliminations(self):
        """Execute the displayed row operations, then check the displayed solution.

        This catches a wrong intermediate row operation even when the final
        numerical answer happens to be correct. No authoring script is used.
        """
        def number(text):
            text = re.sub(r'\s+', '', text)
            match = re.fullmatch(r'(-?)\\frac\{(-?\d+)\}\{(\d+)\}', text)
            return ((-1 if match[1] else 1) * F(int(match[2]), int(match[3]))
                    if match else F(text))

        documents = load_documents()
        checked = 0
        for ol in (ol for doc in documents.values() for ol in doc.root.walk('ol')):
            if not ol.has_class('solution-steps'):
                continue
            lis = [n for n in ol.children if isinstance(n, Element) and n.tag == 'li']
            if len(lis) != 4 or not list(lis[2].walk('table')):
                continue
            equations = [m.attrs['data-tex'] for m in lis[1].walk('math')
                         if r'\begin{matrix}' in m.attrs['data-tex']]
            if not equations:
                continue
            tex = equations[-1]
            bodies = re.findall(r'\\begin\{matrix\}(.*?)\\end\{matrix\}', tex)
            a = [[number(x) for x in row.split('&')] for row in bodies[0].split(r'\\')]
            b = [number(x) for x in bodies[1].split(r'\\')]
            augmented = [row + [rhs] for row, rhs in zip(a, b)]
            table = next(lis[2].walk('table'))
            operations = []
            for row in table.walk('tr'):
                cells = [c for c in row.children if isinstance(c, Element) and c.tag == 'td']
                if not cells:
                    continue
                self.assertEqual(len(cells), 2)
                # The first formula in the operation cell is the row operation.
                # Its explanatory paragraph may also contain formatted coefficients.
                statements = [c for c in cells[1].children
                              if isinstance(c, Element) and c.has_class('math-inline')]
                self.assertEqual(len(statements), 1)
                formulas = list(statements[0].walk('math'))
                self.assertEqual(len(formulas), 1)
                operations.append(formulas[0].attrs['data-tex'])
            self.assertTrue(operations)
            for operation in operations:
                scaled = re.fullmatch(r'R_(\d+)\\leftarrow \((.*?)\)R_\1', operation)
                subtracted = re.fullmatch(r'R_(\d+)\\leftarrow R_\1-\((.*?)\)R_(\d+)', operation)
                swapped = re.fullmatch(r'R_(\d+)\\leftrightarrow R_(\d+)', operation)
                if scaled:
                    i, factor = int(scaled[1])-1, number(scaled[2])
                    augmented[i] = [factor*x for x in augmented[i]]
                elif subtracted:
                    i, factor, j = int(subtracted[1])-1, number(subtracted[2]), int(subtracted[3])-1
                    augmented[i] = [x-factor*y for x,y in zip(augmented[i], augmented[j])]
                elif swapped:
                    i,j = int(swapped[1])-1, int(swapped[2])-1
                    augmented[i], augmented[j] = augmented[j], augmented[i]
                else:
                    self.fail('Unrecognized displayed row operation: ' + operation)
            n = len(a)
            self.assertEqual([row[:-1] for row in augmented],
                             [[F(i==j) for j in range(n)] for i in range(n)])
            solution_tex = next(m.attrs['data-tex'] for m in lis[-1].walk('math')
                                if r'\left(' in m.attrs['data-tex'])
            values = [number(x) for x in solution_tex.split(r'\left(',1)[1].split(r'\right)',1)[0].split(',')]
            if solution_tex.startswith(r'\pi='):
                expected = values
            else:
                # Column labels explicitly identify the internal coordinates.
                labels = re.findall(r'[hg]_\{([^}]+)\}', tex)
                if 'V' in labels:
                    expected = values[:3]
                elif '21' in labels:
                    expected = values[1:5]
                elif len(values) == 5 and len(labels) == 3:
                    expected = values[1:4]
                elif not labels:
                    # Continuous-time hitting systems omit the absorbing,
                    # zero-time boundary coordinates from the unknown vector.
                    expected = [v for v in values if v]
                else:
                    expected = [values[int(k)-1] for k in labels]
            self.assertEqual([row[-1] for row in augmented], expected)
            self.assertEqual([sum(x*y for x,y in zip(row, expected)) for row in a], b)
            checked += 1
        self.assertEqual(checked, 48)


class RemainingChapterCalculationTests(unittest.TestCase):
    @staticmethod
    def number(tex):
        tex = re.sub(r'\s+', '', tex)
        m = re.fullmatch(r'(-?)\\frac\{(-?\d+)\}\{(\d+)\}', tex)
        return (-1 if m[1] else 1)*F(int(m[2]), int(m[3])) if m else F(tex)

    def test_competing_servers_route_probabilities(self):
        # Carol takes the teller who becomes free. Anne-last requires
        # Betty-first, then slow Carol beats fast Anne.
        a, b = F(1, 3), F(1, 6)
        anne_last = b/(a+b)*b/(a+b)
        betty_last = a/(a+b)*a/(a+b)
        carol_last = a/(a+b)*b/(a+b) + b/(a+b)*a/(a+b)
        self.assertEqual([anne_last, betty_last, carol_last], [F(1,9), F(4,9), F(4,9)])
        self.assertEqual(anne_last+betty_last+carol_last, 1)
        self.assertNotEqual(b/(a+b)*a/(a+b), anne_last)
        self.assertEqual(1/(a+b)+a/(a+b)/a+b/(a+b)/b, 6)

    def test_renewal_time_and_service_start_sampling_differ(self):
        # M/M/1 has rho=1/2 and mixed-Poisson A with P(A=k)=(2/3)(1/3)^k.
        rho, a0 = F(1,2), F(2,3)
        return_mean = a0/(1-rho)
        self.assertEqual(return_mean, F(4,3))
        self.assertEqual(1/return_mean, F(3,4))
        self.assertNotEqual(1/return_mean, 1-rho)
        # Uniform(2,3) interarrival, service 1: every arrival sees empty,
        # but one busy time-unit in a mean 5/2-unit renewal interval.
        self.assertEqual(1/F(5,2), F(2,5))
        self.assertNotEqual(F(2,5), F(2,7))

    def test_infinite_servers_and_repair_weights(self):
        # Truncated unnormalised Poisson weights check the n*mu death rate.
        a = F(3,2)
        weights = [a**n/math.factorial(n) for n in range(12)]
        for n in range(11):
            self.assertEqual(weights[n]*a, weights[n+1]*(n+1))
        self.assertNotEqual(weights[1]*a, weights[2])
        repair = [F(15)**n/math.factorial(n) for n in range(4)]
        self.assertEqual(sum(repair), 691)
        self.assertEqual([v/sum(repair) for v in repair], [F(x,1382) for x in [2,30,225,1125]])

    def test_last_departure_and_total_wait_by_independent_methods(self):
        rates = [F(1), F(2), F(3)]
        last = [F(0)]*3
        for order in itertools.permutations(range(3)):
            probability = F(1)
            remaining = set(range(3))
            for person in order:
                probability *= rates[person]/sum(rates[i] for i in remaining)
                remaining.remove(person)
            last[order[-1]] += probability
        self.assertEqual(last, [F(35,60), F(16,60), F(9,60)])
        # Integrate 1-prod_i(1-exp(-rate_i*t)) by inclusion-exclusion.
        mean_max = sum(((-1)**(size+1))/sum(group)
                       for size in range(1,4) for group in itertools.combinations(rates,size))
        self.assertEqual(mean_max, F(73,60))

    def test_doubling_strategy_all_1024_histories(self):
        gains, loss_tail, tail_count = [], F(0), 0
        for history in itertools.product([0,1], repeat=10):
            stake, gain, last_win = 1, 0, 0
            for k, won in enumerate(history, 1):
                gain += stake if won else -stake
                stake = 1 if won else stake*2
                if won:
                    last_win = k
            gains.append(gain)
            if last_win <= 4:
                tail_count += 1
                loss_tail += 2**(10-last_win)-1
        self.assertEqual(sum(gains), 0)
        self.assertEqual(F(tail_count,1024), F(1,64))
        self.assertEqual(loss_tail/1024, F(191,64))
        for n in [1,2,10,30]:
            self.assertEqual((1-F(1,2**n))-(2**n-1)*F(1,2**n), 0)
            self.assertEqual((2**n-1)*F(1,2**n), 1-F(1,2**n))

    def test_historical_put_call_table_arithmetic(self):
        strike = [600,640,680]
        puts = list(map(F, ['28','45.90','74.16']))
        calls = list(map(F, ['55.60','32.70','17.85']))
        actual = [F(620)+p-c for p,c in zip(puts,calls)]
        self.assertEqual(actual, list(map(F,['592.40','633.20','676.31'])))
        self.assertTrue(all(a != F(b) for a,b in zip(actual,['598.20','638.20','681.31'])))
        discount = math.exp(-.01*.27393)
        self.assertAlmostEqual(discount, .99726444848, places=10)
        for k,a,residual in zip(strike,actual,[-5.9587,-5.0492,-1.8298]):
            self.assertAlmostEqual(float(a)-k*discount, residual, places=4)

    def test_all_finance_exercise_tree_tables(self):
        # Read the displayed tables. Independently reconstruct each contract's
        # payoff from its history, and verify both replication cash flows.
        call = lambda k: lambda h: max(h[-1]-k, 0)
        put = lambda k: lambda h: max(k-h[-1], 0)
        asian = lambda h: max(sum(h)/len(h)-4, 0)
        cases = {
            6:(100,2,F(1,2),F(5,4),2,call(80),False),
            7:(45,F(3,2),F(2,3),F(7,6),2,put(50),False),
            8:(4,2,F(1,2),F(5,4),3,asian,False),
            9:(4,2,F(1,2),F(5,4),3,lambda h:h[-1]-min(h),False),
            11:(27,F(4,3),F(2,3),F(10,9),3,lambda h:F(h[-1]>27),False),
            12:(54,F(3,2),F(2,3),F(7,6),3,lambda h:0 if max(h)>=70 else put(50)(h),False),
            14:(64,2,F(1,2),F(5,4),3,call(125),False),
            15:(27,F(4,3),F(2,3),F(10,9),3,put(30),False),
            16:(27,F(4,3),F(2,3),F(10,9),3,put(30),True),
            17:(27,F(4,3),F(2,3),F(10,9),3,lambda h:abs(h[-1]-30),True),
            18:(16,3,F(1,2),F(4,3),3,lambda h:min(call(10)(h),60),True),
            19:(8,2,F(1,2),F(5,4),3,lambda h:max(h)-h[-1],True),
            20:(4,2,F(1,2),F(5,4),3,asian,True),
        }
        doc = Document((ROOT/'books/stochastic/notes/chapter06_mathematical_finance.html').read_text())
        ids = {n.attrs.get('id'):n for n in doc.root.walk()}
        roots, leaves, nodes = {}, 0, 0
        for number,(s,u,d,r,depth,payoff,american) in cases.items():
            s,u,d,r = map(F,(s,u,d,r))
            p = (r-d)/(u-d)
            def prices(path):
                result = [s]
                for move in path:
                    result.append(result[-1]*(u if move=='H' else d))
                return result
            tables = list(ids[f'ex-6-{number}'].walk('table'))
            self.assertEqual(len(tables), 2)
            vals, terminal_average = {}, F(0)
            for row in list(tables[0].walk('tr'))[1:]:
                cells = [n for n in row.children if isinstance(n,Element) and n.tag=='td']
                path = cells[0].text().strip()
                numbers = [self.number(next(c.walk('math')).attrs['data-tex']) for c in cells[1:]]
                probability = p**path.count('H')*(1-p)**path.count('T')
                expected_payoff = payoff(prices(path))
                self.assertEqual(numbers, [prices(path)[-1],expected_payoff,probability,probability*expected_payoff])
                vals[path] = expected_payoff
                terminal_average += probability*expected_payoff
                leaves += 1
            for row in list(tables[1].walk('tr'))[1:]:
                cells = [n for n in row.children if isinstance(n,Element) and n.tag=='td']
                path = cells[1].text().strip().replace('起点','')
                data = [self.number(next(c.walk('math')).attrs['data-tex']) for c in cells[2:6]]
                stock, high, low, continuation = data
                self.assertEqual([stock,high,low], [prices(path)[-1], vals[path+'H'], vals[path+'T']])
                self.assertEqual(continuation, (p*high+(1-p)*low)/r)
                value = continuation
                if american:
                    immediate, value = [self.number(next(c.walk('math')).attrs['data-tex']) for c in cells[6:8]]
                    self.assertEqual(immediate, payoff(prices(path)))
                    self.assertEqual(value, max(immediate,continuation))
                    self.assertEqual(cells[8].text().strip(), '立即行权' if immediate>continuation else '继续')
                if not american or value==continuation:
                    delta, bank = [self.number(next(c.walk('math')).attrs['data-tex']) for c in cells[-2:]]
                    self.assertEqual(delta*stock+bank, continuation)
                    self.assertEqual(delta*u*stock+r*bank, high)
                    self.assertEqual(delta*d*stock+r*bank, low)
                vals[path] = value
                nodes += 1
            if not american:
                self.assertEqual(vals[''], terminal_average/r**depth)
            roots[number] = vals['']
        self.assertEqual((leaves,nodes), (96,83))
        self.assertEqual(roots[8], F(152,125))
        self.assertEqual(roots[20], F(476,375))
        self.assertEqual(roots[16], F(117,25))
        self.assertEqual(roots[17], F(306,25))

    def test_appendix_nonuniform_integrability_counterexample(self):
        # A.23: X_n is 2^n only at the atom of mass 2^-n.
        for n in [1,2,10,100]:
            self.assertEqual(F(1,2**n)*2**n, 1)
            self.assertEqual(sum(F(1,2**k) for k in range(1,n+1)), 1-F(1,2**n))
        # Each fixed sample point has only one nonzero term, hence limit zero;
        # the non-vanishing tail expectation rules out domination/UI.
        for bound in [2,4,1024]:
            n = bound.bit_length()+1
            self.assertGreater(2**n, bound)
            self.assertEqual(F(1,2**n)*2**n, 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
