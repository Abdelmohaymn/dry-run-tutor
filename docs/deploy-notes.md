# Deploy notes: tutor and judge review fixes (2026-10-07)

Commits `7494005` and `c941e05`. Do these in order, from `worker/`.

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
