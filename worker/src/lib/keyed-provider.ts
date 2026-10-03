// FR-008b. Resolves WHICH provider one learner-keyed request goes to.
//
// Before per-key routing there was a single `cfg.provider` for everyone, so a
// learner pasting a Gemini key while the config said Groq had their key sent
// to the wrong host — it could not work, and the failure looked like a bad
// key rather than a misroute. The learner chooses the provider by choosing
// which key to paste, so the choice has to travel with the request.
//
// The host itself is NOT configurable. KEYED_PROVIDER_BASE_URLS is compiled
// into the Worker, so no config write can redirect a learner's own credential
// to an arbitrary origin (Constitution VI). Only the model is remote-tunable,
// because free-tier catalogues churn.
import { AppError } from "./errors";
import { KEYED_PROVIDER_BASE_URLS } from "./provider";
import type { RuntimeConfig } from "./runtime-config";

/** The header the app sends alongside X-User-Key. Absent = use cfg.provider. */
export const PROVIDER_HEADER = "X-Provider";

export interface KeyedProvider {
  id: string;
  baseUrl: string;
  model: string;
  condenseModel: string;
  repairModel: string;
}

/** Providers a learner may bring a key for, in the order key entry should offer them. */
export function offeredProviders(cfg: RuntimeConfig): string[] {
  return cfg.keyed_providers ?? [cfg.provider];
}

/**
 * `header` is the raw X-Provider value, or undefined. Unknown, unsupported,
 * or not-offered values are BAD_REQUEST rather than a silent fallback to the
 * default: quietly relaying a Gemini key to Groq is exactly the misroute this
 * exists to stop, and it would surface to the learner as "your key was
 * rejected".
 */
export function resolveKeyedProvider(cfg: RuntimeConfig, header: string | undefined): KeyedProvider {
  const id = header?.trim().toLowerCase() || cfg.provider;

  const baseUrl = KEYED_PROVIDER_BASE_URLS[id];
  if (!baseUrl) throw new AppError("BAD_REQUEST");
  if (!offeredProviders(cfg).includes(id)) throw new AppError("BAD_REQUEST");

  const overrides = cfg.providers?.[id];
  return {
    id,
    baseUrl,
    model: overrides?.model ?? cfg.model,
    condenseModel: overrides?.condense_model ?? cfg.trim.condense_model,
    repairModel: overrides?.repair_model ?? cfg.repair?.model ?? cfg.model,
  };
}
