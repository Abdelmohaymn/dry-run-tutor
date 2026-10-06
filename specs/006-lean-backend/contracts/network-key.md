# Contract — `networkKey(ip)` (FR-007, FR-008)

New file `worker/src/lib/network-key.ts`, one export:

```ts
export function networkKey(ip: string): string
```

Pure, synchronous, never throws. Callers:

| Caller | Use |
|---|---|
| `lib/trial-pool.ts` · `hashIp(ip, secret)` | hashes `` `ip:${networkKey(ip)}` `` instead of `` `ip:${ip}` `` — so `trial_ip_hash` and `ip_daily_session_cap` count per /64. Callers of `hashIp` do **not** change. |
| `routes/install.ts` | `INSTALL_RL.limit({ key: networkKey(ip) })` — otherwise one IPv6 host rotates through 2^64 addresses and skips the limit |

## Rules

1. `s = ip.trim().toLowerCase()`.
2. No `:` in `s` → return `s` unchanged (IPv4, `"unknown"`, `""`, garbage).
3. Drop a zone id: everything from the first `%`.
4. If the text after the last `:` contains `.`, it is a dotted IPv4 tail:
   parse 4 octets (each `/^\d{1,3}$/` and ≤ 255, else return `s`) and
   replace that text with `` `${(o0<<8|o1).toString(16)}:${(o2<<8|o3).toString(16)}` ``.
5. Expand `::`:
   - `halves = t.split("::")`; more than 2 halves → return `s`.
   - `left = halves[0] === "" ? [] : halves[0].split(":")`;
     `right = halves.length === 2 && halves[1] !== "" ? halves[1].split(":") : []`.
   - One half (no `::`): `left` must have exactly 8 groups, else return `s`.
   - Two halves: `fill = 8 - left.length - right.length`; `fill < 1` → return `s`;
     `groups = [...left, ...Array(fill).fill("0"), ...right]`.
   - Every group must match `/^[0-9a-f]{1,4}$/`, else return `s`. Normalise each
     with `parseInt(g, 16).toString(16)` (drops leading zeros).
6. IPv4-mapped: groups 0–4 are `"0"` and group 5 is `"ffff"` → return the
   dotted IPv4 built from groups 6–7.
7. Otherwise return `` `${g0}:${g1}:${g2}:${g3}::/64` ``.

## Test vectors (`worker/test/unit/network-key.test.ts`)

| Input | Output |
|---|---|
| `203.0.113.7` | `203.0.113.7` |
| `unknown` | `unknown` |
| `""` | `""` |
| `2a02:c7c:1234:5678:abcd:ef01:2345:6789` | `2a02:c7c:1234:5678::/64` |
| `2a02:c7c:1234:5678::1` | `2a02:c7c:1234:5678::/64` |
| `2A02:0C7C:1234:5678:0000:0000:0000:0001` | `2a02:c7c:1234:5678::/64` |
| `2a02:c7c:1234:9999::1` | `2a02:c7c:1234:9999::/64` (different /64) |
| `2a02:c7c::1` | `2a02:c7c:0:0::/64` |
| `::1` | `0:0:0:0::/64` |
| `fe80::1%eth0` | `fe80:0:0:0::/64` |
| `::ffff:203.0.113.7` | `203.0.113.7` |
| `::ffff:cb00:7107` | `203.0.113.7` |
| `1::2::3` | `1::2::3` (invalid, unchanged) |
| `2a02:zzzz::1` | `2a02:zzzz::1` (invalid, unchanged) |

Plus two `hashIp` assertions in the same file:

- `hashIp("2a02:c7c:1234:5678::1", S) === hashIp("2a02:c7c:1234:5678::2", S)`
- `hashIp("::ffff:203.0.113.7", S) === hashIp("203.0.113.7", S)`
