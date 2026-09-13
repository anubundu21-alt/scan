// POST /api/ilove/process
//
// Body:  { kind, token, server, task, tool, files | serverFilename, filename,
//          options }
// Reply: { engine, downloadUrl, token, filename }
//
// The files are already on the worker by the time this runs. All this does is
// ask for the job — with convert_to=docx for PDF to Word, a compression level
// for compressing, a mode for splitting — and hand back where to fetch the
// result from.

import {
  looksLikePdf,
  looksLikeWord,
  looksLikeZip,
  assertSessionToken,
  processTask,
} from "../_lib/ilovepdf.js";
import { guardMethod, readJson, sendError, sendJson } from "../_lib/http.js";

const KINDS = new Set([
  "pdf-to-word",
  "word-to-pdf",
  "compress",
  "merge",
  "split",
]);

/// A job can finish and still hand back the wrong sort of file. Saying so here
/// is better than the device downloading it and finding out.
function wrongResult(kind, processed) {
  switch (kind) {
    case "pdf-to-word":
      return looksLikeWord(processed)
        ? null
        : "That finished without returning a Word file.";
    case "split":
      // One range comes back as a PDF, several as a zip of them.
      return looksLikePdf(processed) || looksLikeZip(processed)
        ? null
        : "Splitting finished without returning any pages.";
    default:
      return looksLikePdf(processed)
        ? null
        : "That finished without returning a PDF.";
  }
}

/// Older builds send one file; merging sends several.
function filesIn(body) {
  if (Array.isArray(body.files) && body.files.length > 0) return body.files;
  return [{ serverFilename: body.serverFilename, filename: body.filename }];
}

export default async function handler(req, res) {
  if (guardMethod(req, res, "POST")) return;
  try {
    const body = await readJson(req);
    const kind = KINDS.has(body.kind) ? body.kind : "pdf-to-word";
    const token = assertSessionToken(body.token);

    const processed = await processTask({
      token,
      server: body.server,
      task: body.task,
      tool: body.tool,
      files: filesIn(body),
      convertTo: kind === "pdf-to-word" ? "docx" : undefined,
      options: body.options,
    });

    const wrong = wrongResult(kind, processed);
    if (wrong) throw Object.assign(new Error(wrong), { statusCode: 502 });

    sendJson(res, 200, {
      engine: "ilovepdf",
      downloadUrl: processed.downloadUrl,
      token,
      filename: processed.downloadFilename,
    });
  } catch (error) {
    sendError(res, error);
  }
}
