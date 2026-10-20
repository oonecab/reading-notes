#!/usr/bin/env python3
"""序言原创例子：六种 AST 构造，显式环境与闭包；Python 3.10+。"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


class LanguageError(ValueError):
    """模型程序的非法语法或运行错误。"""


@dataclass(frozen=True)
class Env:
    name: str
    value: Any
    parent: Env | None

    def lookup(self, name: str) -> Any:
        frame: Env | None = self
        while frame is not None:
            if frame.name == name:
                return frame.value
            frame = frame.parent
        raise LanguageError(f"unbound variable: {name}")


@dataclass(frozen=True)
class Closure:
    param: str
    body: tuple
    saved_env: Env | None


def validate(expr: tuple) -> None:
    """只接受 const/var/diff/let/proc/call，先验证整个有限 AST。"""
    if not isinstance(expr, tuple) or not expr:
        raise LanguageError("expression must be a nonempty tuple")
    tag, *parts = expr
    arities = {"const": 1, "var": 1, "diff": 2,
               "let": 3, "proc": 2, "call": 2}
    if not isinstance(tag, str) or tag not in arities:
        raise LanguageError("unknown expression tag")
    if len(parts) != arities[tag]:
        raise LanguageError(f"wrong AST arity: {tag}")
    if tag == "const":
        if type(parts[0]) is not int:
            raise LanguageError("constant must be an integer")
    elif tag in ("var", "let", "proc"):
        if not isinstance(parts[0], str) or not parts[0].isidentifier():
            raise LanguageError("invalid variable name")
        for child in parts[1:]:
            validate(child)
    else:
        for child in parts:
            validate(child)


def evaluate(expr: tuple, *, scope: str = "lexical") -> int | Closure:
    """按值、从左到右求值；dynamic 是用于比较的语言变体。"""
    if scope not in ("lexical", "dynamic"):
        raise LanguageError("scope must be lexical or dynamic")
    validate(expr)

    def value_of(node: tuple, env: Env | None) -> int | Closure:
        tag, *parts = node
        if tag == "const":
            return parts[0]
        if tag == "var":
            if env is None:
                raise LanguageError(f"unbound variable: {parts[0]}")
            return env.lookup(parts[0])
        if tag == "diff":
            left = value_of(parts[0], env)
            right = value_of(parts[1], env)
            if type(left) is not int or type(right) is not int:
                raise LanguageError("difference expects integers")
            return left - right
        if tag == "let":
            name, rhs, body = parts
            value = value_of(rhs, env)
            return value_of(body, Env(name, value, env))
        if tag == "proc":
            param, body = parts
            return Closure(param, body, env)
        # validate 已保证余下的构造只可能是 call。
        procedure = value_of(parts[0], env)
        argument = value_of(parts[1], env)
        if not isinstance(procedure, Closure):
            raise LanguageError("call expects a procedure")
        parent = procedure.saved_env if scope == "lexical" else env
        return value_of(procedure.body, Env(procedure.param, argument, parent))

    return value_of(expr, None)


DEMO = (
    "let", "x", ("const", 10),
    ("let", "f", ("proc", "y", ("diff", ("var", "y"), ("var", "x"))),
     ("let", "x", ("const", 20), ("call", ("var", "f"), ("const", 25))))
)


if __name__ == "__main__":
    for mode in ("lexical", "dynamic"):
        result = evaluate(DEMO, scope=mode)
        print(f"{mode}: {result}")
