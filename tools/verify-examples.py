#!/usr/bin/env python3
"""Run each problem's reference solution on its public examples.

The validator (validate-content.ts) checks structure only. This script checks
that every public example is TRUE: its input fits the problem's constraints
and its output is what a correct solution returns.

Each content/problems/vp-NNNN.json needs a matching tools/ref-solutions/vp-NNNN.py:

    def solve(**inputs):          # required: a correct solution
    def check_input(**inputs):    # required: assert every public constraint
    def same(got, want, inputs):  # optional: custom compare, for outputs that
                                  # aren't plain JSON or allow several answers

An example input like `nums = [1, 2], target = 3` becomes solve(nums=[1, 2], target=3).
An example output is parsed as JSON (`true`, `"abc"`, `[1, 2]`, `4.0`) unless
the solution defines same().

Usage (from repo root or worker/):
    python3 tools/verify-examples.py                     # every problem
    python3 tools/verify-examples.py content/problems/vp-0012.json ...
"""
import ast
import copy
import importlib.util
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROBLEMS = ROOT / "content" / "problems"
SOLUTIONS = Path(__file__).resolve().parent / "ref-solutions"


def parse_input(text):
    """`a = 1, b = [2]` -> {'a': 1, 'b': [2]}, using literal values only."""
    call = ast.parse(f"f({text})", mode="eval").body
    if call.args:
        raise ValueError("every input value needs a name, like `nums = [...]`")
    return {kw.arg: ast.literal_eval(kw.value) for kw in call.keywords}


def default_same(got, want_text):
    want = json.loads(want_text)
    if isinstance(want, float) or isinstance(got, float):
        return math.isclose(got, want, rel_tol=0, abs_tol=1e-5)
    return got == want


def load_solution(pid):
    path = SOLUTIONS / f"{pid}.py"
    if not path.exists():
        return None
    spec = importlib.util.spec_from_file_location(pid.replace("-", "_"), path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def verify(problem_path):
    pub = json.loads(problem_path.read_text())["public"]
    pid = pub["id"]
    mod = load_solution(pid)
    if mod is None:
        return pid, [f"no reference solution: add tools/ref-solutions/{pid}.py"]
    for fn in ("solve", "check_input"):
        if not hasattr(mod, fn):
            return pid, [f"tools/ref-solutions/{pid}.py has no {fn}()"]

    failures = []
    examples = pub.get("examples") or []
    if not examples:
        failures.append("no public examples")
    for n, ex in enumerate(examples, 1):
        where = f"example {n} ({ex['input']})"
        try:
            inputs = parse_input(ex["input"])
        except Exception as e:
            failures.append(f"{where}: input doesn't parse: {e}")
            continue
        try:
            mod.check_input(**copy.deepcopy(inputs))
        except AssertionError as e:
            failures.append(f"{where}: input breaks a constraint: {e or 'assert failed'}")
            continue
        got = mod.solve(**copy.deepcopy(inputs))
        try:
            if hasattr(mod, "same"):
                ok = mod.same(got, ex["output"], copy.deepcopy(inputs))
            else:
                ok = default_same(got, ex["output"])
        except Exception as e:
            failures.append(f"{where}: output {ex['output']!r} can't be compared: {e}")
            continue
        if not ok:
            failures.append(f"{where}: example says {ex['output']}, reference solution gives {json.dumps(got)}")
    return pid, failures


def main(argv):
    targets = [Path(a).resolve() for a in argv] or sorted(PROBLEMS.glob("vp-*.json"))
    total = 0
    for target in targets:
        pid, failures = verify(target)
        if failures:
            total += len(failures)
            print(f"\n  {pid}  ({target.name})")
            for f in failures:
                print(f"     {f}")
    print(f"\n{'FAIL' if total else 'PASS'}: {len(targets)} problem(s) checked, {total} issue(s)")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
