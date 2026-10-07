# Deploy notes: tutor and judge review fixes (2026-10-07)

Commits `7494005` and `c941e05`. Do these in order, from `worker/`.

## Every deploy: from the main checkout only

Deploy from this working copy (`dry-run-tutor/worker`), never from a fresh
clone, a CI runner or a `git worktree`. Problems from `vp-0004` on are
untracked (`.gitignore`), so they exist only here; `npm run build:content`
compiles whatever is in `content/problems/`, and a deploy from anywhere else
ships only the 4 tracked problems and drops the rest from prod.

Before deploying, check the build line names more than 4 problems:

```bash
npm run build:content   # "built N problem(s)": N must be more than 4 once vp-0004 exists
```

## 1. Apply migration 0010 to the prod D1

```bash
npx wrangler d1 migrations apply dry-run-tutor --env prod --remote
```

It adds `device_day.reached_keys`. Every chat turn now reads that column, so deploying the code before this migration breaks every turn.

## 2. Turn Nemotron's thinking off for structured calls

Run the command under "Structured calls on Nemotron" in `worker/README.md` on the prod config.

- It covers the judge and the finish check only; the tutor stream keeps thinking on.
- Use the right `trial.pool[N]` index for each Nemotron member.
- Without this, about 19% of assessments come back empty.

## 3. Build content, then deploy

```bash
npm run build:content
npx wrangler deploy --env prod
```

`src/generated/` is gitignored, and deploy ships whatever was built last.

## After deploy

Play one session on the phone with a good answer, a wrong answer, and "just give me the answer" asked twice.
