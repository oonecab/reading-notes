#!/usr/bin/env python3
"""独立手算用例；必要执行不放在 assert 表达式内。"""
from __future__ import annotations

import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "code"))
from scope_demo import Closure, DEMO, LanguageError, evaluate


def run() -> dict:
    cases = [
        ("zero", ("const", 0), 0),
        ("negative", ("diff", ("const", -3), ("const", 4)), -7),
        ("shadow", ("let", "x", ("const", 1),
                    ("let", "x", ("const", 2), ("var", "x"))), 2),
        ("let-rhs-old-env", ("let", "x", ("const", 4),
                            ("let", "x", ("diff", ("var", "x"), ("const", 1)),
                             ("var", "x"))), 3),
        ("argument-caller-env", ("let", "x", ("const", 10),
                                ("let", "f", ("proc", "y", ("var", "y")),
                                 ("let", "x", ("const", 20),
                                  ("call", ("var", "f"), ("var", "x"))))), 20),
        ("parameter-shadows", ("let", "x", ("const", 10),
                              ("call", ("proc", "x", ("var", "x")), ("const", 7))), 7),
        ("escaped-closure", ("let", "f",
                            ("let", "x", ("const", 8), ("proc", "y",
                             ("diff", ("var", "x"), ("var", "y")))),
                            ("call", ("var", "f"), ("const", 3))), 5),
        ("higher-order", ("call", ("call",
                                  ("proc", "x", ("proc", "y",
                                   ("diff", ("var", "x"), ("var", "y")))),
                                  ("const", 9)), ("const", 2)), 7),
        ("demo", DEMO, 15),
    ]
    for label, ast, expected in cases:
        actual = evaluate(ast)
        if actual != expected:
            raise AssertionError((label, expected, actual))
    closure = evaluate(("proc", "x", ("var", "x")))
    if not isinstance(closure, Closure):
        raise AssertionError("procedure must be a value")
    bad = [
        ((), "nonempty tuple"), (("wat", 1), "unknown"),
        (("const", True), "integer"), (("const", 1, 2), "arity"),
        (("var", "bad name"), "variable name"), (("var", "missing"), "unbound"),
        (("call", ("const", 2), ("const", 3)), "procedure"),
        (("diff", ("proc", "x", ("var", "x")), ("const", 1)), "integers"),
        # Closure free variables are resolved at call time using the saved environment.
        (("let", "f", ("proc", "y", ("var", "x")),
          ("let", "x", ("const", 8), ("call", ("var", "f"), ("const", 0)))), "unbound"),
    ]
    for ast, message in bad:
        try:
            evaluate(ast)
        except LanguageError as exc:
            if message not in str(exc):
                raise AssertionError((ast, str(exc)))
        else:
            raise AssertionError(("expected LanguageError", ast))
    try:
        evaluate(("const", 1), scope="unknown")
    except LanguageError:
        pass
    else:
        raise AssertionError("invalid scope accepted")
    grid = 0
    discriminating = 0
    for a in range(-2, 3):
        for b in range(-2, 3):
            for c in range(-2, 3):
                ast = ("let", "x", ("const", a),
                       ("let", "f", ("proc", "y", ("diff", ("var", "y"), ("var", "x"))),
                        ("let", "x", ("const", c), ("call", ("var", "f"), ("const", b)))))
                lexical = evaluate(ast)
                dynamic = evaluate(ast, scope="dynamic")
                if lexical != b - a or dynamic != b - c:
                    raise AssertionError((a, b, c, lexical, dynamic))
                grid += 1
                discriminating += lexical != dynamic
    if discriminating != 100:
        raise AssertionError("scope negative control did not discriminate")
    return {"status": "passed", "hand_calculated_cases": len(cases) + 1,
            "error_cases": len(bad) + 1, "scope_grid": grid,
            "scope_discriminating_cases": discriminating}


if __name__ == "__main__":
    print(json.dumps(run(), ensure_ascii=False))
