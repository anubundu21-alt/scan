// POST /api/ilove/start
//
// Body:  { kind, filename }
// Reply: { engine, token, server, task, tool, uploadUrl, filename }
//
// `filename` in the reply is what the *finished* file should be called. The
// device uploads to `uploadUrl` itself with `Authorization: Bearer {token}`,
// so the file never passes through here. Merging uploads several files to the
// one task before asking for the job.

import {
  startCompress,
  startMerge,
  startPdfToWord,
  startSplit,
  startWordToPdf,
} from "../_lib/ilovepdf.js";
import { guardMethod, readJson, sendError, sendJson } from "../_lib/http.js";

/// What each job starts, and what to call what comes back. `resultExtension`
/// is a guess for splitting: one range comes back as a PDF, several as a zip,
/// and only the process step knows which.
const JOBS = {
  "pdf-to-word": {
    start: startPdfToWord,
    strip: /\.pdf$/i,
    resultExtension: "docx",
    fallbackName: "document.pdf",
  },
  "word-to-pdf": {
    start: startWordToPdf,
    strip: /\.(docx?|odt|rtf)$/i,
    resultExtension: "pdf",
    fallbackName: "document.docx",
  },
  compress: {
    start: startCompress,
    strip: /\.pdf$/i,
    resultExtension: "pdf",
    fallbackName: "document.pdf",
    suffix: "-compressed",
  },
  merge: {
    start: startMerge,
    strip: /\.pdf$/i,
    resultExtension: "pdf",
    fallbackName: "document.pdf",
    suffix: "-merged",
  },
  split: {
    start: startSplit,
    strip: /\.pdf$/i,
    resultExtension: "pdf",
    fallbackName: "document.pdf",
    suffix: "-split",
  },
};

export default async function handler(req, res) {
  if (guardMethod(req, res, "POST")) return;
  try {
    const body = await readJson(req);
    const kind = Object.hasOwn(JOBS, body.kind) ? body.kind : "pdf-to-word";
    const job = JOBS[kind];

    const filename = String(body.filename || job.fallbackName);
    const base = filename.replace(job.strip, "") || "document";
    const started = await job.start();

    sendJson(res, 200, {
      engine: "ilovepdf",
      token: started.token,
      server: started.server,
      task: started.task,
      tool: started.tool,
      uploadUrl: `https://${started.server}/v1/upload`,
      filename: `${base}${job.suffix ?? ""}.${job.resultExtension}`,
    });
  } catch (error) {
    sendError(res, error);
  }
}
