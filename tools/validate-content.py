#!/usr/bin/env python3
"""Validate problem JSON against problem-schema.md v2. Run in CI over the content directory."""
import json, sys, glob, os

def validate(p):
    f=[]; pid=p['public']['id']; pub=p['public']; pv=p['private']
    if pub.get('schema_version')!=2: f.append("rule1  schema_version must be 2")
    verds={a['verdict'] for a in pv.get('reference_approaches',[])}
    for need in ('optimal','suboptimal','wrong'):
        if need not in verds: f.append(f"rule2  missing a '{need}' reference approach")
    akeys={a['key'] for a in pv.get('reference_approaches',[])}
    for fu in pv.get('followups',[]):
        for w in fu.get('when_approach',[]):
            if w!='*' and w not in akeys: f.append(f"rule3  followup '{fu.get('id')}' -> unknown approach '{w}'")
    for ins in pv.get('key_insights',[]):
        k=ins.get('key'); h=ins.get('hints') or []; ns=ins.get('never_say') or []
        if len(h)!=3: f.append(f"rule5  insight '{k}' needs exactly 3 hints, has {len(h)}")
        if not ns:    f.append(f"rule6  insight '{k}' has empty never_say")
        for t in ns:
            for i,rung in enumerate(h,1):
                if t.lower() in rung.lower():
                    f.append(f"rule9  insight '{k}' LEAKS never_say term '{t}' in hint rung {i}")
    for w in pv.get('common_wrong_turns',[]):
        k=w.get('key')
        if not w.get('counter_question'): f.append(f"rule7  wrong turn '{k}' missing counter_question")
        elif not w['counter_question'].strip().endswith('?'):
            f.append(f"rule8  wrong turn '{k}' counter_question must be a question (end in '?')")
        if not w.get('failing_case'):     f.append(f"rule7  wrong turn '{k}' missing failing_case")
    if 'glossary_terms' in pv: f.append("       glossary_terms is public in v2, not private")
    return pid, f

def main(paths):
    total=0
    for path in paths:
        doc=json.load(open(path))
        problems = doc['problems'] if isinstance(doc,dict) and 'problems' in doc else [doc]
        for p in problems:
            pid,f = validate(p)
            if f:
                total+=len(f); print(f"\n  {pid}  ({os.path.basename(path)})")
                for x in f: print(f"     {x}")
    print(f"\n{'FAIL' if total else 'PASS'}: {total} problem(s) issue(s)")
    return 1 if total else 0

if __name__=='__main__':
    args=sys.argv[1:] or sorted(glob.glob('content/problems/*.json')) or ['sample-problems.json']
    sys.exit(main(args))
