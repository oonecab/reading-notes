#!/usr/bin/env python3
"""Run the chapter's actual supplied inputs and independently expected reading examples."""
import html
import json
from pathlib import Path
import re
import subprocess
import tempfile

from sync_notes import ROOT, BOOK


def run(racket, run_dir):
    output = Path(run_dir)
    output.mkdir(parents=True, exist_ok=True)
    questions = json.loads((BOOK / "notes/questions_ch07.json").read_text())["items"]

    def inputs(number):
        return [html.unescape(s) for s in re.findall(
            r'<pre><code class="language-text">(.*?)</code></pre>',
            questions[number - 1]["chinese_html"], re.S)]

    cases = []

    def add(name, operation, program, expected, options=""):
        cases.append(dict(name=name, operation=operation, program=program, expected=expected, options=options))

    for n, program in enumerate(inputs(1), 1):
        # The period after item4 is source punctuation, not part of the grammar.
        add(f"7.1-{n}-evaluation", "runtime-error" if n in (9, 10) else "value",
            program.rstrip("."), "runtime-type" if n in (9, 10) else "<procedure>")
    for n, program in enumerate(inputs(13), 1):
        add(f"7.13-{n}-type", "typing-error" if n in (1, 4) else "infer", program,
            "typing" if n in (1, 4) else "(int -> int)" if n == 2 else "int")
    add("7.13-2-call", "value", "(" + inputs(13)[1] + " 7)", "6")
    add("7.13-3-value", "value", inputs(13)[2], "99")
    for n, program in enumerate(inputs(15), 1):
        add(f"7.15-{n}-type", "infer", program, "(int -> int)" if n == 1 else "int")
        add(f"7.15-{n}-value", "value", program, "<procedure>" if n == 1 else "1")
    checked_mutual = inputs(15)[1].replace("? even", "int even").replace("? odd", "int odd").replace(": ?", ": int")
    add("7.5-annotated-mutual-check", "check", checked_mutual, "int")
    marked = inputs(14)[0]
    add("7.14-original-rejected", "typing-error", marked, "typing")
    for annotation in ("int", "?"):
        corrected = marked.replace("x : bool", "x : " + annotation)
        add("7.14-corrected-" + annotation, "value", corrected, "1")
        add("7.14-corrected-type-" + annotation, "infer", corrected, "int")
    add("7.28-original-identity-type", "infer", inputs(28)[0], "int", "#:polymorphism 'w")
    add("7.28-original-identity-value", "value", inputs(28)[0], "11")
    original_map = inputs(28)[1]
    add("7.28-original-syntax", "typing-error", original_map, "typing")
    corrected_map = re.sub(r"let\s+\?\s+map\s*\(f\s*:\s*\?\)\s*=",
                           "let map = proc(f:?)", original_map, count=1)
    assert "((foo f) cdr(x))" in corrected_map
    corrected_map = corrected_map.replace("((foo f) cdr(x))", "(foo cdr(x))")
    for mode in ("copy", "w"):
        add("7.28-original-cons-map-" + mode, "infer", corrected_map,
            "(pairof (listof int) (listof bool))", "#:polymorphism '" + mode)
    add("7.28-original-cons-map-value", "value", corrected_map, "(pair (2 4) (#f #f))")
    for name, program, result in [
        ("known-safe-rejected", "if zero?(0) then 11 else zero?(1)", "11"),
        ("nested-process-argument-order", "((proc(x)proc(y) if y then x else 11 7) zero?(0))", "7"),
        ("multiargument-recursion", "letrec f(x,y)=if zero?(x) then y else (f -(x,1) y) in (f 5 44)", "44"),
        ("setright-sentinel", "setright(newpair(1,2),3)", "83"),
    ]:
        add(name, "value", program, result, "#:mutable-pairs? #t" if "setright" in name else "")
    for name, program, result in [
        ("pair-argument-type", "proc(p) unpair x y=p in -(x,y)", "((pairof int int) -> int)"),
        ("reference-argument-type", "proc(r) begin setref(r,1); deref(r) end", "((refto int) -> int)"),
        ("omitted-recursive-result", "letrec f(x)=x in f", "(a0 -> a0)"),
    ]:
        add(name, "infer", program, result)

    quote = lambda s: json.dumps(s, ensure_ascii=False)
    assertions = []
    for case in cases:
        op, program, expected, options = (case[k] for k in ("operation", "program", "expected", "options"))
        function = "infer" if op in ("infer", "typing-error") else "check" if op == "check" else "evaluate"
        call = f"(m:{function} {quote(program)} {options})"
        if op == "typing-error":
            assertion = f"(check-exn m:exn:fail:typing? (lambda () {call}))"
        elif op == "runtime-error":
            assertion = f"(check-exn (lambda (e) (and (m:exn:fail:object? e) (eq? (m:exn:fail:object-kind e) '{expected}))) (lambda () {call}))"
        else:
            assertion = f"(check-equal? (format \"~s\" {call if op in ('infer', 'check') else '(m:datum ' + call + ')'}) {quote(expected)})"
        assertions.append(f"(test-case {quote(case['name'])} {assertion})")
    source = '#lang racket\n(require rackunit rackunit/text-ui json (prefix-in m: (file ' + quote(str(BOOK / "code/chapter07.rkt")) + ')))\n'
    source += '(define failures (run-tests (test-suite "source-inputs" ' + "\n".join(assertions) + ')))\n'
    source += f'(write-json (hash \'status (if (zero? failures) "passed" "failed") \'cases {len(cases)} \'failures failures)) (newline) (exit failures)\n'
    with tempfile.TemporaryDirectory(prefix="source-inputs-", dir=output) as temporary:
        probe = Path(temporary) / "probe.rkt"
        probe.write_text(source)
        tested = subprocess.run([racket, str(probe)], capture_output=True, text=True, timeout=60)
    (output / "execution.log").write_text(tested.stdout + tested.stderr)
    assert tested.returncode == 0, (tested.stdout, tested.stderr)
    report = dict(status="passed", cases=cases, execution=json.loads(tested.stdout.splitlines()[-1]),
                  source="notes/questions_ch07.json; explicit expected reading examples")
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    return report
