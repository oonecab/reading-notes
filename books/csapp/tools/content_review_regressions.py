"""Scoped REA-v2 content checks: 3.33 aliasing and 9.20 reserved heap regions.

The libc space experiment uses Darwin's own zone allocator without sanitizer
interposition. Alias correctness is also run with ASan/UBSan and NDEBUG.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import html
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import xml.etree.ElementTree as ET


def check_ex285_math(page: str):
    """Ensure both negative-t powers are one complete mathematical object."""
    start = page.index('id="ex-2-85"')
    end = page.index('id="ex-2-86"', start)
    exercise = page[start:end]
    if 'ᵗ' in exercise:
        raise ValueError('2.85 must not split t into an external Unicode superscript')
    ns = {'m': 'http://www.w3.org/1998/Math/MathML'}
    prefix = '{' + ns['m'] + '}'
    # The powers now belong to the complete M and f equalities. Inspect the
    # presentation tree, not an obsolete span around the isolated power.
    forms = {}
    for source in re.findall(r'<math\b.*?</math>', exercise, re.S):
        root = ET.fromstring(source)
        tokens = [node for node in root.iter() if node.tag in
                  {prefix + name for name in ('mi', 'mn', 'mo', 'mtext')}]
        superscripts = root.findall('.//m:msup', ns)
        if not superscripts or not tokens or tokens[0].text not in ('M', 'f'):
            continue
        name = tokens[0].text
        expected = {'M': 'M=2−2−t', 'f': 'f=1−2−t'}[name]
        if name in forms or ''.join(node.text or '' for node in tokens) != expected:
            raise ValueError('2.85 complete M/f equality differs from its mathematical definition')
        if len(superscripts) != 1 or len(superscripts[0]) != 2:
            raise ValueError('2.85 malformed MathML power')
        base, exponent = superscripts[0]
        if (''.join(base.itertext()) != '2' or exponent.tag != prefix + 'mrow' or
                [child.tag for child in exponent] != [prefix + 'mo', prefix + 'mi'] or
                ''.join(exponent.itertext()) != '−t'):
            raise ValueError('2.85 exponent must contain minus and t inside MathML')
        forms[name] = root
    if set(forms) != {'M', 'f'}:
        raise ValueError('2.85 must contain both complete M/f equalities with negative-t powers')
    return {'complete_negative_t_powers': len(forms), 'complete_equalities': sorted(forms)}


def check_content_review(base: Path, run: Path, compiler: str = 'clang'):
    base, run = Path(base).resolve(), Path(run).resolve()
    run.mkdir(parents=True, exist_ok=True)
    commands = []
    environment = dict(os.environ, MallocMaxMagazines='1')

    information_page = (base / 'notes/chapter02_information.html').read_text()
    math = check_ex285_math(information_page)
    start = information_page.index('id="ex-2-85"')
    end = information_page.index('id="ex-2-86"', start)
    exercise = information_page[start:end]
    negative_t = '<mo>&#x02212;</mo><mi>t</mi></mrow></msup>'
    mutations = {
        'missing exponent t': (negative_t, '<mo>&#x02212;</mo></mrow></msup>'),
        'positive exponent': (negative_t, '<mo>+</mo><mi>t</mi></mrow></msup>'),
        'wrong base': ('<msup><mn>2</mn><mrow><mo>&#x02212;</mo><mi>t</mi>',
                       '<msup><mn>3</mn><mrow><mo>&#x02212;</mo><mi>t</mi>'),
        'external t': (negative_t, '<mo>&#x02212;</mo></mrow></msup><mi>t</mi>'),
        'wrong M constant': ('<mi>M</mi><mo>=</mo><mn>2</mn><mo>−</mo>',
                             '<mi>M</mi><mo>=</mo><mn>3</mn><mo>−</mo>'),
        'external superscript': (negative_t, '<mo>&#x02212;</mo></mrow></msup>ᵗ'),
    }
    math['mutations_rejected'] = []
    for label, (old, new) in mutations.items():
        if old not in exercise:
            raise ValueError('MathML mutation anchor disappeared: ' + label)
        broken = information_page[:start] + exercise.replace(old, new, 1) + information_page[end:]
        try:
            check_ex285_math(broken)
        except ValueError:
            math['mutations_rejected'].append(label)
        else:
            raise ValueError('MathML mutation escaped: ' + label)
    math['missing_exponent_mutation_rejected'] = True
    space_page = (base / 'notes/chapter09_virtual_memory.html').read_text()
    match = re.search(r'<code\b[^>]*\bid="ch09_space-c"[^>]*>(.*?)</code>', space_page, re.S)
    if not match or html.unescape(match[1]) != (base / 'code/ch09_space.c').read_text():
        raise ValueError('9.20 space measurement reading copy differs from maintained source')

    def command(args, expected=0):
        proc = subprocess.run(list(map(str, args)), capture_output=True, text=True,
                              timeout=60, env=environment)
        commands.append({'command': [str(x).replace(str(base), 'BOOK').replace(str(run), 'RUN') for x in args],
                         'exit_code': proc.returncode, 'stdout': proc.stdout, 'stderr': proc.stderr})
        if expected is not None and proc.returncode != expected:
            (run / 'failure.json').write_text(json.dumps(commands, ensure_ascii=False, indent=2) + '\n')
            raise ValueError('Content regression failed: ' + repr(args) + '\n' + proc.stderr)
        return proc

    flags = [compiler, '-std=c11', '-Wall', '-Wextra', '-Werror', '-pedantic', '-O2', '-DNDEBUG']
    alias = base / 'code/ch03_procprob_alias.c'
    expected_alias = 'alias source-order=1 assembly-order=257 independent-long=256 independent-char=0 checks=2\n'
    for suffix, extra in [('release', []), ('sanitized', ['-fsanitize=address,undefined', '-fno-omit-frame-pointer'])]:
        binary = run / ('alias-' + suffix)
        command([*flags, *extra, alias, '-o', binary])
        if command([binary]).stdout != expected_alias:
            raise ValueError('3.33 alias/order results differ from 1/257 and independent-object reference')
    # The rejected universal-equivalence claim is represented by reordering
    # source_order. That mutation must fail even with assertions disabled.
    wrong = alias.read_text().replace('    *u += a;\n    *v += b;', '    *v += b;\n    *u += a;', 1)
    if wrong == alias.read_text():
        raise ValueError('alias mutation anchor disappeared')
    mutant = run / 'alias-reordered.c'; mutant.write_text(wrong)
    command([*flags, '-fsanitize=address,undefined', mutant, '-o', run / 'alias-reordered'])
    failed = command([run / 'alias-reordered'], expected=None)
    if failed.returncode != 1 or 'alias mismatch' not in failed.stderr:
        raise ValueError('illegal reorder mutation escaped or failed for an unrelated reason')

    space = {'status': 'unavailable', 'reason': 'Darwin zone API required; no guessed libc heap denominator'}
    if platform.system() == 'Darwin':
        source = base / 'code/ch09_space.c'
        binary = run / 'space'
        command([*flags, source, '-o', binary])
        repeats = []
        for repetition in range(3):
            rows = [json.loads(line) for line in command([binary]).stdout.splitlines()]
            wanted = {(n, backend) for n in [64, 512]
                      for backend in ['toy-first', 'toy-next', 'libc-private-zone']}
            if {(r['blocks'], r['backend']) for r in rows} != wanted or len(rows) != 6:
                raise ValueError('space experiment did not execute both traces on all three backends')
            for row in rows:
                count, h, page = row['blocks'], row['max_heap'], row['page_bytes']
                # Independently count requested live bytes, not allocator headers
                # or usable-size metadata. The trace allocates all before freeing.
                payload = sum(8 + (13 * i) % 120 for i in range(count))
                if row['peak_payload'] != payload or row['operations'] != 2 * count or row['samples'] != 2 * count + 1:
                    raise ValueError('space trace differs from independent workload accounting')
                if h < payload or page <= 0 or h % page or row['final_heap'] > h:
                    raise ValueError('invalid reserved-page denominator')
                if row['backend'].startswith('toy') and (h != 65536 or row['final_heap'] != 65536):
                    raise ValueError('toy arena is not the specified fixed 64 KiB heap')
                if abs(row['peak_utilization'] - payload / h) > 1e-9:
                    raise ValueError('reported utilization differs from independent division')
            repeats.append({'repeat': repetition + 1, 'rows': rows})
        # Using live bytes would recreate the invalid denominator. The C
        # region-enumeration cross-check must reject that change immediately.
        wrong = source.read_text().replace('h = s.size_allocated;', 'h = s.size_in_use;', 1)
        if wrong == source.read_text():
            raise ValueError('space denominator mutation anchor disappeared')
        mutant = run / 'space-live-denominator.c'; mutant.write_text(wrong)
        command([*flags, '-I', base / 'code', mutant, '-o', run / 'space-live-denominator'])
        failed = command([run / 'space-live-denominator'], expected=None)
        if failed.returncode != 1 or 'allocator invariant failed' not in failed.stderr:
            raise ValueError('live-block denominator mutation escaped or failed for unrelated reason')
        space = {'status': 'passed', 'repeats': repeats,
                 'metric': 'peak requested bytes / maximum block-region reserved bytes',
                 'region_check': 'page union of MALLOC_PTR_REGION_RANGE_TYPE and MALLOC_ADMIN_REGION_RANGE_TYPE equals size_allocated at every sample',
                 'excluded': ['out-of-region allocator controllers on both backends', 'shared process state'],
                 'scope': 'Darwin private scalable zone; not default malloc dispatch or physical RSS',
                 'sanitizer': 'disabled for space measurement to preserve libc backend'}
    sources = ['code/ch03_procprob_alias.c', 'code/ch09_space.c', 'code/ch09_allocator.c',
               'tools/content_review_regressions.py']
    report = {'status': 'passed' if space['status'] == 'passed' else 'partial',
              'checked_at': datetime.now(timezone.utc).isoformat(),
              'environment': {'system': platform.system(), 'release': platform.release(),
                              'machine': platform.machine(), 'MallocMaxMagazines': '1'},
              'source_sha256': {name: hashlib.sha256((base / name).read_bytes()).hexdigest() for name in sources},
              'math': math,
              'space_reading_copy_equal': True,
              'alias': {'status': 'passed', 'assumptions': 'little-endian LP64, 8-bit signed char',
                        'source_order': 1, 'assembly_order_model': 257,
                        'independent_objects_equal': True, 'reorder_mutation_rejected': True},
              'space': space, 'commands': commands}
    (run / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    return report
