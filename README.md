# Dry Run

One coding-interview problem a day, talked through out loud with a tutor that already knows the
answer and will not hand it over.

You speak your approach. It pushes back — a counter-question, then a failing case, then the
smallest useful hint. It never says "correct". At the end you get a verdict classified against
human-authored ground truth, and the editorial. Free forever, at zero cost to anyone.

There is **no code entry, no multiple choice, and no tap-to-answer control anywhere in the
product** — one content type, spoken. That constraint is the product, not an omission; see
Principle I in `.specify/memory/constitution.md`.

## About this repo

A public snapshot of Dry Run, an Android app that already existed before this repo. The first
commit is that pre-existing app with private material removed: the full problem library (four
sample problems remain), deploy IDs, release signing and store tooling, internal planning docs
and the landing site. Hosts, database IDs and the contact address are placeholders. Every commit
after the first is new work.

## Layout

| Path | What lives there |
|---|---|
| `lib/` | The Flutter Android client (feature 002) |
| `worker/` | The Cloudflare Worker relay — seven endpoints, frozen wire contract (feature 001) |
| `content/problems/` | Sample problems, `public`/`private` split; the private half never leaves the server |
| `specs/` | Wire and design contracts the code and tests read |

## Running it

```bash
flutter pub get
flutter run
```

One app (`app.dryrun.tutor`), one relay: `lib/core/config/relay.dart` holds the deployed worker URL.
Pass `--dart-define=RELAY_BASE_URL=https://...` to point a build at another worker.
`lib/core/config/brand.dart` holds the product name and every identifier derived from it.
Release builds use `android/key.properties` if present, otherwise the debug key.

## Tests

```bash
flutter analyze                 # zero issues is the bar
flutter test                    # 331 tests
cd worker && npm test           # 372 tests
```

If Drift tests fail on `libsqlite3.so`, the host is missing the unversioned dev symlink rather
than the library:

```bash
mkdir -p /tmp/shim && ln -sfn /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /tmp/shim/libsqlite3.so
LD_LIBRARY_PATH=/tmp/shim flutter test
```

## Deploying the relay

```bash
cd worker
npx wrangler deploy --env dev
```

Content changes do nothing on a device until the worker redeploys. `runtime_config`'s
`content_manifest_url` must name the worker's own host — the client refuses any other (FR-004),
and a wrong value strands every install on `/withdrawn`.

