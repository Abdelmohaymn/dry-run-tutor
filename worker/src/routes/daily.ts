// GET /v1/daily?date=YYYY-MM-DD — contracts/worker-api.md. The server picks
// the day's problem and returns its public half. The insert-or-ignore into
// `device_day` is the D7 activity signal: a row exists for every day a device
// opened its daily problem (data-model.md §A3, §A7).
import { Hono } from "hono";
import type { Env, Variables } from "../types";
import { AppError } from "../lib/errors";
import { getPublicManifest } from "../lib/content";
import { getRuntimeConfig } from "../lib/runtime-config";
import { dayNumber, pickDaily } from "../lib/daily-pick";
import { utcDate } from "../lib/time";

export const dailyRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

function isRealDate(date: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return false;
  const parsed = new Date(`${date}T00:00:00Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === date;
}

dailyRoute.get("/", async (c) => {
  const date = c.req.query("date");
  if (date === undefined || !isRealDate(date)) throw new AppError("BAD_REQUEST");
  // One day either side absorbs midnight skew between the device's trusted
  // clock and ours; two days ahead is always refused (SC-004).
  if (Math.abs(dayNumber(date) - dayNumber(utcDate())) > 1) throw new AppError("BAD_REQUEST");

  const cfg = await getRuntimeConfig(c.env.DB);
  const problem = pickDaily(getPublicManifest().problems, cfg, date);
  if (!problem) throw new AppError("PROBLEM_KILLED");

  await c.env.DB
    .prepare("INSERT OR IGNORE INTO device_day (device_hash, date, problem_id) VALUES (?1, ?2, ?3)")
    .bind(c.get("installId"), date, problem.id)
    .run();

  return c.json({ date, problem }, 200, { "cache-control": "private, no-store" });
});
