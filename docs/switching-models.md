# Switching API keys and models

How to put a new key or model behind the tutor and judge safely. Follow it every time; a model that looks fine in one chat can still break the judge or leak answers.

Background: `specs/review-tutor-judge-findings.md` (2026-10-07) measured these risks on Nebius.

## 1. Which path are you changing?

| Path | Whose key | Where it is set | Used by |
|---|---|---|---|
| **Trial pool** | yours (the operator's) | `trial.pool[]` in the D1 `config` row, key in a Worker secret | every learner without their own key (today: all users) |
| **Learner key** | the learner's | `providers.<id>.model` in the D1 `config` row; the host is compiled in | learners who paste a key in the app |

Learner keys can only go to the hosts in `KEYED_PROVIDER_BASE_URLS` (`worker/src/lib/provider.ts`): `groq`, `openrouter`, `gemini`, `nebius`. A new host for learner keys is a code change. The trial pool takes any OpenAI-compatible `base_url`.

## 2. Test the model before you switch

Run the live harness with the new key and model. From `worker/`:

```bash
GROQ_API_KEY=<the key> \
HARNESS_PROVIDER=<groq|openrouter|gemini|nebius> \
HARNESS_MODEL=<model id> \
npm run test:harness
```

`GROQ_API_KEY` is only the variable name. It holds whatever key the provider needs.

- **Nemotron only:** add `HARNESS_STRUCTURED_EXTRA_BODY='{"chat_template_kwargs":{"enable_thinking":false}}'` to match production (see section 4).
- **Never paste the key into a file in the repo.** The repo is public. To keep it off your shell history, use `read -s K` and then `GROQ_API_KEY="$K"`.

**Pass bar:** at least 46 of 48, the Nemotron baseline. Two known flakes may fail:

- `vp-0002 > garbled`: the judge says `borderline` where `unclear` is expected.
- `vp-0003 > concept_question`: a 2-in-8 sketch-overlap flake.

What a failure means:

| Failing test | Meaning | Do |
|---|---|---|
| `opening_brute_force`, `direct_pressure`, `regression S4_*`, any `leaked` | The tutor gives the answer away | Do not switch |
| `regression S1/S3/S5/S8/S9` | The tutor re-asks settled points | Do not switch for the tutor; still fine as a judge-only model |
| `second_solution_request` | The tutor withholds the solution after two asks | Do not switch for the tutor |
| `regression S2_*` | Wrong language or dialect for Egyptian Arabic | Do not switch if you have Arabic users |
| judge `hollow feedback` or `judge call failed` | Broken structured output, or the reasoning ate the token budget | Set `structured_output: false` for that member, or try the thinking-off body |
| judge `expected one of [pass]` on `acceptable_*` / `paraphrase_*` | The judge is too harsh | Do not use as the judge |

Also run the free test suite: `npm test`. It must be all green, but it uses no real model.

**Limits of the harness:**

- It runs the **learner-key** path (tier AB, no stored progress). It does not exercise the trial pool's routing.
- The regex checks are a first gate. For a real model change, also replay the review scenarios with a grader, the way the review did.

## 3. Switch

Save the current config first, so you can roll back:

```bash
npx wrangler d1 execute dry-run-tutor --env prod --remote \
  --command "SELECT payload FROM config WHERE id = 1" > config-backup-$(date +%F).json
```

Keep the backup out of git. Use `dry-run-tutor-dev --env dev` for dev.

### 3a. Trial pool: add or replace a member

1. Store the key as a Worker secret. Paste it interactively; never put it on the command line or in a file:
   ```bash
   npx wrangler secret put TRIAL_KEY_<NAME> --env prod
   ```
2. Add the member:
   ```bash
   npx wrangler d1 execute dry-run-tutor --env prod --remote --command "UPDATE config SET payload = json_insert(payload, '\$.trial.pool[#]', json('{
     \"id\": \"<short_id>\",
     \"secret_binding\": \"TRIAL_KEY_<NAME>\",
     \"base_url\": \"https://<host>/v1\",
     \"model\": \"<model id>\",
     \"daily_token_budget\": <below the provider daily allowance>,
     \"structured_output\": <true only if it supports strict json_schema>,
     \"enabled\": true,
     \"cooldown_ms\": 60000
   }')), updated_at = datetime('now') WHERE id = 1"
   ```
   - `structured_output: true` makes the member eligible for the judge and the finish check. Set it only when strict `json_schema` really works: the harness judge tests pass with no hollow results.
   - Pool order is selection order. Put the new member first only after it passes.
   - Budget: one trial session (10 turns + judge) costs about **38k tokens**. Size `daily_token_budget` accordingly.
3. To retire a member, set its `enabled` to `false` (`json_set(payload, '$.trial.pool[N].enabled', json('false'))`).

### 3b. Learner keys: change the model for a provider

```bash
npx wrangler d1 execute dry-run-tutor --env prod --remote --command "UPDATE config SET payload = json_set(payload, '\$.providers.<id>.model', '<model id>'), updated_at = datetime('now') WHERE id = 1"
```

- **Offering a provider in the app:** `keyed_providers` lists which providers a learner can pick. Add the id there to offer one.
- **Defaults:** a provider without its own `model` falls back to the top-level `model`.

## 4. Model-specific settings

| Model type | Set this | Why |
|---|---|---|
| **Nemotron** (`nvidia/nemotron-*`) | `structured_extra_body: {"chat_template_kwargs":{"enable_thinking":false}}` on its pool member and on `providers.nebius` | With thinking on, 19% of judge results came back empty and the judge took 3.4× as long. **Never** set it for the tutor: the tutor needs thinking on (quality dropped about 30% without it). |
| **Other models** | No `structured_extra_body` | Other providers may reject unknown fields like `chat_template_kwargs` with a 400 error. |
| **Reasoning models** (gpt-oss, DeepSeek-R/Flash, Kimi, GLM, Qwen3.5, Gemini 2.5+ thinking) | Watch the harness for empty replies and `ERROR` judge results | Hidden thinking counts against the token limit. The tutor stream is capped at `max_tokens 2500`, judge 2000, finish check 1500. An empty tutor reply returns a retryable error and the turn is refunded. gpt-oss-120b hit the judge cap in 5 of 75 calls. |
| **Any model** | Nothing; it is sent automatically | The tutor stream always sends `temperature 0.6`, `top_p 0.95`, `max_tokens 2500` (`STREAM_*` in `worker/src/lib/provider-groq.ts`). If a provider rejects `top_p` or `temperature`, every chat turn fails with a retry error. Check the first harness test. The fix is a code change to those constants. |

## 5. What we measured on Nebius (2026-10-07)

| Model | As tutor | As judge | Notes |
|---|---|---|---|
| Nemotron-3-Super (current) | best, 27/30 after fixes | 90/93 with thinking off | recommended for both |
| DeepSeek-V4-Pro | 20/30, pushes the "official" approach | 74/75, 2.5 s | good judge, 5× judge cost |
| Qwen3-235B-Instruct | not tested | 74/75 | very slow on Nebius at the time (about 29 s) |
| Qwen3-30B-Instruct | 23/30, names terms early | 62/69, broke on long JSON | cheap; not recommended |
| gpt-oss-120b | not scored | 70/70 answered, 5 hit the token cap | reasoning tokens make it slower |

These numbers do not carry over to other providers. Run section 2 for every new provider/model pair.

## 6. After switching

1. Watch the first few real sessions for error frames (`UNCLEAR_RETRY`, `RATE_LIMITED`) and for leaks in replies.
2. Play one session on the phone yourself: one good answer, one wrong answer, one "just give me the answer" asked twice. See `content/problems/PLAYTEST.md`.
3. **Roll back:** write the saved payload back:
   ```bash
   npx wrangler d1 execute dry-run-tutor --env prod --remote \
     --command "UPDATE config SET payload = '<saved JSON>', updated_at = datetime('now') WHERE id = 1"
   ```
   No redeploy is needed. `GET /v1/config` picks the change up on its next read.
