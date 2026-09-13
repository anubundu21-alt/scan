// Conversion client for /api/ilove/*.
//
// Flow (https://developer.ilovepdf.com/docs/api-reference):
//   GET  https://api.ilovepdf.com/v1/start/{tool}  -> { server, task }
//   POST https://{server}/v1/upload                   (the device, multipart)
//   POST https://{server}/v1/process                  { task, tool, files }
//   GET  https://{server}/v1/download/{task}
//
// The developer catalogue has Office to PDF (`officepdf`) but no PDF to Word.
// The tool behind the website is `pdfoffice` with convert_to=docx, and a
// developer JWT gets a 404 from that start route — only the public session
// token the tool page hands out can open it. So both directions start the
// same way the website does, which also means this runs without project keys.
//
// The file never passes through here. Only the job details do.

const API_HOST = "api.ilovepdf.com";
const WEBSITE = "https://www.ilovepdf.com";
const PDF_WORD_TOOL = "pdfoffice";
const WORD_PDF_TOOL = "officepdf";
const COMPRESS_TOOL = "compress";
const MERGE_TOOL = "merge";
const SPLIT_TOOL = "split";

export class ConversionError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.statusCode = statusCode;
  }
}

function strip(value) {
  return String(value ?? "")
    .trim()
    .replace(/^['"]+|['"]+$/g, "")
    .trim();
}

// One session token covers every job until the page rotates it, so it is
// worth keeping between invocations that land on a warm instance.
const sessionTokens = new Map();

/** Pulls the session token out of a tool page's inline config. */
function parseConfig(html) {
  const marker = "var ilovepdfConfig = ";
  const start = html.indexOf("{", html.indexOf(marker));
  if (start < 0) return null;
  let depth = 0;
  for (let i = start; i < html.length; i += 1) {
    if (html[i] === "{") depth += 1;
    else if (html[i] === "}") {
      depth -= 1;
      if (depth === 0) {
        try {
          return JSON.parse(html.slice(start, i + 1));
        } catch {
          return null;
        }
      }
    }
  }
  return null;
}

export async function sessionToken(pagePath) {
  if (sessionTokens.has(pagePath)) return sessionTokens.get(pagePath);
  const res = await fetch(`${WEBSITE}${pagePath}`, {
    headers: {
      Accept: "text/html",
      "User-Agent": "Mozilla/5.0 (compatible; Scanella/1.0)",
    },
  });
  if (!res.ok) throw new ConversionError("Could not start conversion.", 502);
  const config = parseConfig(await res.text());
  if (!config?.token) {
    throw new ConversionError("Could not start a conversion session.", 502);
  }
  sessionTokens.set(pagePath, config.token);
  return config.token;
}

async function readError(res) {
  const text = await res.text().catch(() => "");
  if (!text) return `HTTP ${res.status}`;
  try {
    const parsed = JSON.parse(text);
    return (
      parsed.message ||
      parsed.error?.message ||
      (typeof parsed.error === "string" ? parsed.error : "") ||
      text.slice(0, 200)
    );
  } catch {
    return text.slice(0, 200);
  }
}

export async function startTool(tool, token) {
  const name = strip(tool);
  if (!/^[a-z0-9_]{2,40}$/i.test(name)) {
    throw new ConversionError("Invalid tool name.", 400);
  }
  const res = await fetch(`https://${API_HOST}/v1/start/${name}`, {
    headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
  });
  const text = await res.text();
  let body = {};
  try {
    body = JSON.parse(text);
  } catch {
    body = {};
  }
  if (!res.ok) {
    return {
      ok: false,
      status: res.status,
      message: body.error?.message || body.message || text.slice(0, 200),
    };
  }
  if (!body.server || !body.task) {
    return { ok: false, status: 502, message: "No worker was returned." };
  }
  return { ok: true, server: body.server, task: body.task };
}

async function startWithSession(tool, pagePath, label) {
  const token = await sessionToken(pagePath);
  const started = await startTool(tool, token);
  if (started.ok) return { ...started, token, tool };
  throw new ConversionError(
    started.message || `Could not start ${label}.`,
    started.status === 401 || started.status === 403 ? 503 : 502
  );
}

export function startPdfToWord() {
  const tool = strip(process.env.ILOVEPDF_TOOL) || PDF_WORD_TOOL;
  return startWithSession(tool, "/pdf_to_word", "PDF to Word");
}

export function startWordToPdf() {
  const tool = strip(process.env.ILOVEPDF_WORD_TOOL) || WORD_PDF_TOOL;
  return startWithSession(tool, "/word_to_pdf", "Word to PDF");
}

export function startCompress() {
  const tool = strip(process.env.ILOVEPDF_COMPRESS_TOOL) || COMPRESS_TOOL;
  return startWithSession(tool, "/compress_pdf", "compressing");
}

export function startMerge() {
  const tool = strip(process.env.ILOVEPDF_MERGE_TOOL) || MERGE_TOOL;
  return startWithSession(tool, "/merge_pdf", "merging");
}

export function startSplit() {
  const tool = strip(process.env.ILOVEPDF_SPLIT_TOOL) || SPLIT_TOOL;
  return startWithSession(tool, "/split_pdf", "splitting");
}

// Everything below comes off the wire from the device, so none of it is
// trusted. Without the host check in particular, a caller could name any
// address and have this function make the request for them.

export function assertWorkerHost(server) {
  const host = String(server || "")
    .replace(/^https?:\/\//, "")
    .split("/")[0]
    .toLowerCase();
  if (!/^[a-z0-9-]+(?:\.[a-z0-9-]+)*\.ilovepdf\.com$/.test(host)) {
    throw new ConversionError("Invalid worker host.", 400);
  }
  return host;
}

export function assertTaskId(task) {
  const id = String(task || "").trim();
  if (!/^[A-Za-z0-9]{16,200}$/.test(id)) {
    throw new ConversionError("Invalid task id.", 400);
  }
  return id;
}

export function assertSessionToken(value) {
  const token = String(value || "").trim();
  if (!/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token)) {
    throw new ConversionError("Invalid session.", 400);
  }
  return token;
}

export function assertServerFilename(name) {
  const value = String(name || "").trim();
  if (!/^[A-Za-z0-9._-]{16,200}$/.test(value)) {
    throw new ConversionError("Invalid upload name.", 400);
  }
  return value;
}

/** Merging needs every file in one job, so this always takes a list. */
export function assertFiles(files) {
  const list = Array.isArray(files) ? files : [];
  if (list.length < 1) {
    throw new ConversionError("No file was uploaded.", 400);
  }
  if (list.length > 20) {
    throw new ConversionError("That is more files than one job can take.", 400);
  }
  return list.map((file) => ({
    server_filename: assertServerFilename(file?.serverFilename),
    filename: String(file?.filename || "document.pdf").slice(0, 200),
  }));
}

const COMPRESSION_LEVELS = new Set(["low", "recommended", "extreme"]);

/** Only what the tools below accept, and only in the shape they accept it. */
export function assertOptions(tool, options) {
  const given = options && typeof options === "object" ? options : {};
  const out = {};

  if (tool === COMPRESS_TOOL) {
    const level = strip(given.compressionLevel) || "recommended";
    if (!COMPRESSION_LEVELS.has(level)) {
      throw new ConversionError("Unknown compression level.", 400);
    }
    out.compression_level = level;
    return out;
  }

  if (tool === SPLIT_TOOL) {
    if (given.everyPages != null) {
      const every = Number(given.everyPages);
      if (!Number.isInteger(every) || every < 1 || every > 10000) {
        throw new ConversionError("Invalid page count to split by.", 400);
      }
      out.split_mode = "fixed_range";
      out.fixed_range = every;
      return out;
    }
    const ranges = strip(given.ranges);
    if (!/^\d{1,6}(?:-\d{1,6})?(?:\s*,\s*\d{1,6}(?:-\d{1,6})?)*$/.test(ranges)) {
      throw new ConversionError("Invalid page range.", 400);
    }
    out.split_mode = "ranges";
    out.ranges = ranges.replace(/\s+/g, "");
    // One file back is far more use on a phone than a zip of one.
    if (given.mergeAfter) out.merge_after = true;
    return out;
  }

  return out;
}

export async function processTask({
  token,
  server,
  task,
  tool,
  files,
  convertTo,
  options,
}) {
  const host = assertWorkerHost(server);
  const taskId = assertTaskId(task);
  const payload = {
    task: taskId,
    tool,
    output_filename: "{filename}",
    files: assertFiles(files),
    ...assertOptions(tool, options),
  };
  if (convertTo) payload.convert_to = convertTo;

  const res = await fetch(`https://${host}/v1/process`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    throw new ConversionError(
      `Could not convert this file: ${await readError(res)}`,
      res.status >= 400 && res.status < 500 ? 422 : 502
    );
  }
  const body = await res.json().catch(() => ({}));
  return {
    downloadUrl: `https://${host}/v1/download/${taskId}`,
    outputExtensions: String(body.output_extensions || ""),
    downloadFilename: body.download_filename || "",
    status: body.status || "",
  };
}

export function looksLikeWord(processed) {
  const ext = String(processed.outputExtensions || "").toLowerCase();
  const name = String(processed.downloadFilename || "").toLowerCase();
  return ext.includes("doc") || /\.docx?$/.test(name);
}

export function looksLikePdf(processed) {
  const ext = String(processed.outputExtensions || "").toLowerCase();
  const name = String(processed.downloadFilename || "").toLowerCase();
  return ext.includes("pdf") || /\.pdf$/.test(name);
}

/// Splitting into more than one file comes back as a zip of them.
export function looksLikeZip(processed) {
  const ext = String(processed.outputExtensions || "").toLowerCase();
  const name = String(processed.downloadFilename || "").toLowerCase();
  return ext.includes("zip") || /\.zip$/.test(name);
}
