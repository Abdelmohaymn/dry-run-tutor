# Hackathon Phase 2 API delta

This delta documents the owner-approved extensions in
`hackathon/implementation-guide.md`.

## `GET /v1/problems`

Install-authenticated. Returns `200` with
`{ "problems": [{ "id", "title", "difficulty", "tags" }] }`, using only the
public manifest. Killed problems and the practice problem are omitted.
Responses are `private, no-store`.

## `GET /v1/daily?date=&problem_id=`

`date` remains required and must be today or the adjacent UTC day. The
optional `problem_id` selects an evergreen public problem instead of the
daily picker. Unknown ids and the practice problem return `BAD_REQUEST`;
killed problems return `PROBLEM_KILLED`. The selected problem records the same
`device_day` activity row as an ordinary daily response.

## `POST /v1/session/reset`

Install-authenticated with strict body `{ "problem_id": "vp-NNNN" }`.
The current UTC day's `device_day` row is deleted. If the device's trial slot
names that problem for today, the slot is retired and its session allowance is
incremented. The operation is idempotent and returns `{ "ok": true }`.

## Free-path transcript repair

`POST /v1/repair` accepts requests without `X-User-Key`. Such requests use an
eligible trial-pool member and settle the member's `provider_day` usage from
the provider-reported input and output token counts. If no member is
available, the response is the unchanged transcript with `changed: false`.
Keyed requests retain their existing routing and guard behaviour.
