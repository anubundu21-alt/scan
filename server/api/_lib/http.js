// Request and response helpers, so one handler body works on Vercel and
// behind a plain Node server.

export function sendJson(res, status, body) {
  res.statusCode = status;
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.setHeader("cache-control", "no-store");
  res.end(JSON.stringify(body));
}

export function sendError(res, error) {
  const status = Number(error?.statusCode) || 500;
  sendJson(res, status, {
    error: error?.message || "Conversion service failed",
  });
}

/** Vercel pre-parses the body and drains the stream; a bare server does not. */
export function readJson(req) {
  if (req.body && typeof req.body === "object") return Promise.resolve(req.body);
  if (typeof req.body === "string") {
    try {
      return Promise.resolve(JSON.parse(req.body || "{}"));
    } catch {
      return Promise.resolve({});
    }
  }
  return new Promise((resolve) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
    req.on("end", () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}"));
      } catch {
        resolve({});
      }
    });
    req.on("error", () => resolve({}));
  });
}

/** True when the request was already answered: a preflight or the wrong verb. */
export function guardMethod(req, res, method) {
  if (String(req.method || "").toUpperCase() === "OPTIONS") {
    res.statusCode = 204;
    res.end();
    return true;
  }
  if (String(req.method || "").toUpperCase() !== method) {
    sendJson(res, 405, { error: `Use ${method} for this endpoint.` });
    return true;
  }
  return false;
}
