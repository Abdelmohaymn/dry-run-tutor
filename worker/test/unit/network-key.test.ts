import { describe, expect, it } from "vitest";
import { networkKey } from "../../src/lib/network-key";

// contracts/network-key.md §Test vectors.
const VECTORS: [string, string][] = [
  ["203.0.113.7", "203.0.113.7"],
  ["unknown", "unknown"],
  ["", ""],
  ["2a02:c7c:1234:5678:abcd:ef01:2345:6789", "2a02:c7c:1234:5678::/64"],
  ["2a02:c7c:1234:5678::1", "2a02:c7c:1234:5678::/64"],
  ["2A02:0C7C:1234:5678:0000:0000:0000:0001", "2a02:c7c:1234:5678::/64"],
  ["2a02:c7c:1234:9999::1", "2a02:c7c:1234:9999::/64"],
  ["2a02:c7c::1", "2a02:c7c:0:0::/64"],
  ["::1", "0:0:0:0::/64"],
  ["fe80::1%eth0", "fe80:0:0:0::/64"],
  ["::ffff:203.0.113.7", "203.0.113.7"],
  ["::ffff:cb00:7107", "203.0.113.7"],
  ["1::2::3", "1::2::3"],
  ["2a02:zzzz::1", "2a02:zzzz::1"],
];

describe("networkKey()", () => {
  it.each(VECTORS)("%j -> %j", (input, expected) => {
    expect(networkKey(input)).toBe(expected);
  });
});
