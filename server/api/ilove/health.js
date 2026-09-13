// GET /api/ilove/health — is the converter reachable from this deployment?

import { sessionToken } from "../_lib/ilovepdf.js";
import { sendJson } from "../_lib/http.js";

export default async function handler(req, res) {
  let ok = false;
  let reason;
  try {
    await sessionToken("/pdf_to_word");
    ok = true;
  } catch (error) {
    reason = error?.message || "Could not reach the converter.";
  }
  sendJson(res, ok ? 200 : 503, {
    status: ok ? "ok" : "degraded",
    checks: { converter: ok },
    ...(reason ? { reason } : {}),
    timestamp: new Date().toISOString(),
  });
}
