// contracts/network-key.md. Collapses an IPv6 address to its /64 so one
// subscriber cannot rotate through 2^64 addresses to dodge a per-network cap.
// IPv4, "unknown" and anything unparseable come back unchanged. Pure; never throws.

export function networkKey(ip: string): string {
  const s = ip.trim().toLowerCase();
  if (!s.includes(":")) return s;

  const pct = s.indexOf("%");
  let t = pct >= 0 ? s.slice(0, pct) : s;

  const lastColon = t.lastIndexOf(":");
  const tail = t.slice(lastColon + 1);
  if (tail.includes(".")) {
    const octets = tail.split(".");
    if (octets.length !== 4) return s;
    const o: number[] = [];
    for (const part of octets) {
      if (!/^\d{1,3}$/.test(part)) return s;
      const n = Number(part);
      if (n > 255) return s;
      o.push(n);
    }
    t = `${t.slice(0, lastColon + 1)}${((o[0]! << 8) | o[1]!).toString(16)}:${((o[2]! << 8) | o[3]!).toString(16)}`;
  }

  const halves = t.split("::");
  if (halves.length > 2) return s;
  const left = halves[0] === "" ? [] : halves[0]!.split(":");
  const right = halves.length === 2 && halves[1] !== "" ? halves[1]!.split(":") : [];

  let groups: string[];
  if (halves.length === 1) {
    if (left.length !== 8) return s;
    groups = left;
  } else {
    const fill = 8 - left.length - right.length;
    if (fill < 1) return s;
    groups = [...left, ...Array<string>(fill).fill("0"), ...right];
  }

  if (!groups.every((g) => /^[0-9a-f]{1,4}$/.test(g))) return s;
  const g = groups.map((x) => parseInt(x, 16).toString(16));

  if (g.slice(0, 5).every((x) => x === "0") && g[5] === "ffff") {
    const hi = parseInt(g[6]!, 16);
    const lo = parseInt(g[7]!, 16);
    return `${hi >> 8}.${hi & 255}.${lo >> 8}.${lo & 255}`;
  }

  return `${g[0]}:${g[1]}:${g[2]}:${g[3]}::/64`;
}
