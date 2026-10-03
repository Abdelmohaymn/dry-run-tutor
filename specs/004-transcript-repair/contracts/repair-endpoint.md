# `POST /v1/repair` — wire contract

**Status**: authored 2026-09-18. **Spec**: [../spec.md](../spec.md) ·
**Plan**: [../plan.md](../plan.md) · **Decisions**: [../research.md](../research.md)

This file is the contract *and* the merge instruction. Feature 001 owns the live
contracts (`specs/001-proxy-content-contract/contracts/`), and this branch amends them
in place — the same way the rotation lever did. §Merge below gives the exact blocks.

---

## Request

```http
POST /v1/repair
X-Install-Id: <install id>
X-User-Key: <the learner's own provider key>
X-Provider: groq | openrouter | gemini      (optional; defaults to cfg.provider)
Content-Type: application/json

{ "problem_id": "vp-0007", "transcript": "I'd use a hash mop to store the compliment" }
```

**Exactly two body fields**, `additionalProperties: false`. No audio, no duration, no
level samples, no recogniser confidence, no term list. FR-012, Principle VII, and
research.md R-002.

`X-User-Key` is **required**. A request without it is `BAD_REQUEST`, which is what
makes the trial path structurally unable to repair (research.md R-009).

## Response

```http
200 OK
Content-Type: application/json

{ "repaired": "I'd use a hash map to store the complement", "changed": true }
```

| Field | Type | Meaning |
|---|---|---|
| `repaired` | string | The corrected transcript — **or the raw transcript verbatim** on any fallback. Never absent, never empty when the request was valid. |
| `changed` | boolean | `repaired !== transcript`. Computed server-side so the client never re-derives it. Drives the revert affordance (FR-005, US2 scenario 3). |

**A 200 with `changed: false` is the shape of every internal failure.** Guard rejected
the output, provider returned malformed text, transcript below `min_chars`, above
`max_input_chars`, `repair.enabled` false — all of them answer 200 with the raw
transcript. The learner is never told repair failed, because repair failing costs them
nothing (FR-006).

## Errors

From the existing closed catalogue only
(`specs/001-proxy-content-contract/contracts/error-catalog.md`). **No new codes.**

| Status | Code | When |
|---|---|---|
| 400 | `BAD_REQUEST` | missing `X-User-Key`, body fails the schema, unknown `problem_id`, unknown or un-offered `X-Provider` |
| 401 | `INVALID_KEY` | the provider rejected the learner's key |
| 401 | — | missing/unknown `X-Install-Id` (the `installAuth` middleware, as every other route) |
| 409 | `PROBLEM_KILLED` | `problem_id` is in `killed_problem_ids` |
| 429 | `RATE_LIMITED` / `QUOTA_EXHAUSTED` | the provider said so |
| 502 | `UNCLEAR_RETRY` | the provider did not answer cleanly |

**The client swallows every one of these** and proceeds with the raw transcript
(research.md R-011). They exist so the endpoint is debuggable and honest, not so the
app can act on them. Nothing here is ever queued to the outbox.

`TURN_CAP_REACHED` is **not** in this table and must never be returned: this route
does not call `reserveTurn()` and cannot consume a turn (FR-007, SC-007).

## Server-side behaviour, in order

1. `installAuth` → 401 if unknown.
2. `X-User-Key` present? → else `BAD_REQUEST`.
3. Body parses against `repairRequestSchema`? → else `BAD_REQUEST`.
4. `problem_id` in `getPublicManifest()`? → else `BAD_REQUEST`.
5. `getRuntimeConfig()`. `killed_problem_ids` → `PROBLEM_KILLED`.
6. `resolveKeyedProvider(cfg, header)` → `BAD_REQUEST` on an unknown provider.
7. **Skip checks**, each returning `200 {repaired: transcript, changed: false}` with
   **no usage row**, because nothing was spent:
   - `cfg.repair.enabled === false`
   - non-whitespace length `< cfg.repair.min_chars`
   - length `> cfg.repair.max_input_chars`
8. Provider call: `structuredCompletion()` with `REPAIR_PROMPT`, the assembled user
   content, `temperature: 0`, `maxTokens` per the prompt contract, aborted at
   `cfg.repair.timeout_ms`.
9. **Guards** (plan.md §Guards). Any failure → fall back to the raw transcript.
   Guard 2 calls `getPrivate()` **here, after the provider has answered** — never
   before, and never into the prompt.
10. `writeUsage()` with `endpoint: "repair"`, `turn_index` from `readCounters()`,
    `leak_blocked: true` when guard 2 was the one that rejected.
11. Return.

---

## §Merge — `specs/001-proxy-content-contract/contracts/openapi.yaml`

Add under `paths:`, after `/v1/judge`:

```yaml
  /v1/repair:
    post:
      summary: Correct speech-recognition errors in one spoken transcript
      description: >
        Runs on the learner's own key, before the mandatory transcript review
        (Principle V). Reserves no turn and can never return TURN_CAP_REACHED.
        Every internal failure — guard rejection, malformed output, timeout,
        repair switched off — answers 200 with the raw transcript and
        changed:false, because a failed correction must cost the learner
        nothing (FR-006). X-User-Key is REQUIRED; there is no trial path.
      parameters: [{ $ref: '#/components/parameters/ProviderHeader' }]
      security: [{ InstallId: [], UserKey: [] }]
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/RepairRequest' }
      responses:
        '200':
          description: The corrected transcript, or the raw one verbatim
          content:
            application/json:
              schema: { $ref: '#/components/schemas/RepairResponse' }
        '400': { $ref: '#/components/responses/Err' }
        '401': { $ref: '#/components/responses/Err' }
        '409':
          description: PROBLEM_KILLED — this problem was pulled.
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Error' }
        '429': { $ref: '#/components/responses/Err' }
        '502': { $ref: '#/components/responses/Err' }
```

Add under `components.schemas:`:

```yaml
    RepairRequest:
      type: object
      additionalProperties: false
      required: [problem_id, transcript]
      properties:
        problem_id:
          type: string
          pattern: '^vp-\d{4}$'
        transcript:
          type: string
          minLength: 1
          maxLength: 8000
          description: >
            The raw recogniser output for one spoken turn. TEXT ONLY. This
            endpoint accepts no audio, no duration, no level samples and no
            confidence score, and additionalProperties:false is what enforces
            that (Constitution VII).

    RepairResponse:
      type: object
      additionalProperties: false
      required: [repaired, changed]
      properties:
        repaired:
          type: string
          description: >
            The corrected transcript, or the request's transcript verbatim on
            any fallback.
        changed:
          type: boolean
          description: repaired !== transcript, computed server-side.
```

## §Merge — `specs/001-proxy-content-contract/contracts/config.schema.json`

Add to `properties` (not to `required` — a config written before this feature must
keep parsing, which is the same courtesy `rotation` and `keyed_providers` already get):

```json
"repair": {
  "type": "object",
  "additionalProperties": false,
  "required": ["enabled", "model", "min_chars", "max_input_chars", "timeout_ms", "max_output_ratio", "min_word_overlap"],
  "description": "Transcript repair (feature 004). Absent means repair is off, which is the pre-feature behaviour. THE MODEL NAME HERE IS A FREE-TIER CATALOGUE ENTRY AND WILL CHURN — that is why it is a D1 value and not a constant.",
  "properties": {
    "enabled": { "type": "boolean", "default": true, "description": "FR-010's kill switch. False means the app never calls and never holds the review step." },
    "model": { "type": "string", "default": "llama-3.1-8b-instant", "description": "Overridden per provider by providers[id].repair_model." },
    "min_chars": { "type": "integer", "minimum": 1, "default": 40, "description": "FR-011. Non-whitespace characters. Below this, no round trip. THIS IS THE PRIMARY LEVER IF SC-005's 5% TOKEN BUDGET IS BREACHED." },
    "max_input_chars": { "type": "integer", "minimum": 1, "default": 2000, "description": "Bounded input. Sized above a full 90-second recording (~1400 chars)." },
    "timeout_ms": { "type": "integer", "minimum": 100, "maximum": 5000, "default": 1500, "description": "The Worker's provider timeout AND the app's review-step hold window. One number, two places. Bounded by SC-004's 2 seconds." },
    "max_output_ratio": { "type": "number", "minimum": 1.0, "maximum": 3.0, "default": 1.5, "description": "Guard 1, applied in both directions." },
    "min_word_overlap": { "type": "number", "minimum": 0, "maximum": 1, "default": 0.6, "description": "Guard 3. The guard that catches a model answering the problem instead of correcting the transcript." }
  }
}
```

And add `repair_model` to the existing per-provider override object, beside `model`
and `condense_model`:

```json
"repair_model": { "type": "string" }
```

## §Merge — the D1 write

The lever block is added to the single `runtime_config` row. There is no migration;
this is a payload edit:

```bash
wrangler d1 execute dryrun --remote --command \
  "UPDATE runtime_config SET payload = json_set(payload, '\$.repair', json('{\"enabled\":true,\"model\":\"llama-3.1-8b-instant\",\"min_chars\":40,\"max_input_chars\":2000,\"timeout_ms\":1500,\"max_output_ratio\":1.5,\"min_word_overlap\":0.6}')) WHERE id = 1"
```

Verify with `curl -s https://<relay>/v1/config | jq .repair` before testing on device.
