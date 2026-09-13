import test from "node:test";
import assert from "node:assert";

import start from "../api/ilove/start.js";
import processHandler from "../api/ilove/process.js";

const TASK = "A1b2C3d4E5f6G7h8i9";
const UPLOADED = "abcdef0123456789.pdf";
const SESSION = "aaaaaa.bbbbbb.cccccc";
const WORKER = "api99o.ilovepdf.com";

function request(body, method = "POST") {
  return { method, body, headers: {} };
}

function response() {
  return {
    statusCode: 0,
    body: null,
    headers: {},
    setHeader(key, value) {
      this.headers[key] = value;
    },
    end(payload) {
      this.body = payload ? JSON.parse(payload) : null;
      return this;
    },
  };
}

/// Stands in for the tool pages and the workers, and records what we asked.
function stubFetch(overrides = {}) {
  const calls = [];
  globalThis.fetch = async (url, options = {}) => {
    calls.push({
      url,
      method: options.method || "GET",
      headers: options.headers || {},
      body: options.body ? JSON.parse(options.body) : null,
    });

    if (url.includes("www.ilovepdf.com")) {
      return reply(
        200,
        `<html><script>var ilovepdfConfig = {"token":"${SESSION}","x":{"y":1}};</script></html>`,
        true
      );
    }
    if (url.includes("/v1/start/")) {
      const start_ = overrides.start || {
        status: 200,
        body: { server: WORKER, task: TASK },
      };
      return reply(start_.status, JSON.stringify(start_.body));
    }
    if (url.includes("/v1/process")) {
      const processed = overrides.process || {
        status: 200,
        body: {
          download_filename: "Offer letter.docx",
          output_extensions: '["docx"]',
          status: "TaskSuccess",
        },
      };
      return reply(processed.status, JSON.stringify(processed.body));
    }
    throw new Error(`unexpected request to ${url}`);
  };
  return calls;
}

function reply(status, text) {
  return { ok: status < 400, status, text: async () => text, json: async () => JSON.parse(text) };
}

// Runs first on purpose: the session cache lives for the life of the module,
// so this is the only point at which it is known to be empty.
test("the tool page is read once, then the session is reused", async () => {
  const calls = stubFetch();

  await start(request({ kind: "pdf-to-word", filename: "a.pdf" }), response());
  await start(request({ kind: "pdf-to-word", filename: "b.pdf" }), response());

  const pageReads = calls.filter((call) => call.url.includes("www.ilovepdf.com"));
  assert.equal(pageReads.length, 1);
  assert.equal(pageReads[0].url, "https://www.ilovepdf.com/pdf_to_word");
});

test("start opens a job and hands back an upload address", async () => {
  const calls = stubFetch();
  const res = response();

  await start(request({ kind: "pdf-to-word", filename: "Offer letter.pdf" }), res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.engine, "ilovepdf");
  assert.equal(res.body.token, SESSION);
  assert.equal(res.body.server, WORKER);
  assert.equal(res.body.task, TASK);
  assert.equal(res.body.uploadUrl, `https://${WORKER}/v1/upload`);
  // The finished file's name, not the one being sent.
  assert.equal(res.body.filename, "Offer letter.docx");

  // PDF to Word is not in the developer catalogue; the website tool is.
  const started = calls.find((call) => call.url.includes("/v1/start/"));
  assert.equal(started.url, "https://api.ilovepdf.com/v1/start/pdfoffice");
  assert.equal(started.headers.Authorization, `Bearer ${SESSION}`);

  // Nothing here should ever have carried a file.
  assert.ok(calls.every((call) => !call.body || !call.body.file));
});

test("word to pdf uses the office tool and its own page", async () => {
  const calls = stubFetch();
  const res = response();

  await start(request({ kind: "word-to-pdf", filename: "Contract.docx" }), res);

  assert.equal(res.body.filename, "Contract.pdf");
  assert.ok(
    calls.some((call) => call.url === "https://www.ilovepdf.com/word_to_pdf")
  );
  assert.ok(
    calls.some((call) => call.url.endsWith("/v1/start/officepdf"))
  );
});

test("an odt keeps its own name when it becomes a pdf", async () => {
  stubFetch();
  const res = response();
  await start(request({ kind: "word-to-pdf", filename: "Notes.odt" }), res);
  assert.equal(res.body.filename, "Notes.pdf");
});

test("the tool name can be changed without a code change", async () => {
  process.env.ILOVEPDF_TOOL = "somethingelse";
  const calls = stubFetch();
  await start(request({ kind: "pdf-to-word", filename: "a.pdf" }), response());
  delete process.env.ILOVEPDF_TOOL;

  assert.ok(calls.some((call) => call.url.endsWith("/v1/start/somethingelse")));
});

test("a start the converter refuses is reported, not swallowed", async () => {
  stubFetch({
    start: { status: 404, body: { error: { message: "No such tool" } } },
  });
  const res = response();

  await start(request({ kind: "pdf-to-word", filename: "a.pdf" }), res);

  assert.equal(res.statusCode, 502);
  assert.match(res.body.error, /No such tool/);
});

test("process asks for docx and returns where to fetch it", async () => {
  const calls = stubFetch();
  const res = response();

  await processHandler(
    request({
      kind: "pdf-to-word",
      token: SESSION,
      server: WORKER,
      task: TASK,
      tool: "pdfoffice",
      serverFilename: UPLOADED,
      filename: "Offer letter.pdf",
    }),
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.downloadUrl, `https://${WORKER}/v1/download/${TASK}`);
  assert.equal(res.body.token, SESSION);
  assert.equal(res.body.filename, "Offer letter.docx");

  const asked = calls[0];
  assert.equal(asked.headers.Authorization, `Bearer ${SESSION}`);
  assert.equal(asked.body.convert_to, "docx");
  assert.equal(asked.body.output_filename, "{filename}");
  assert.deepEqual(asked.body.files, [
    { server_filename: UPLOADED, filename: "Offer letter.pdf" },
  ]);
});

test("word to pdf does not ask for a docx back", async () => {
  const calls = stubFetch({
    process: {
      status: 200,
      body: { download_filename: "Contract.pdf", output_extensions: '["pdf"]' },
    },
  });
  const res = response();

  await processHandler(
    request({
      kind: "word-to-pdf",
      token: SESSION,
      server: WORKER,
      task: TASK,
      tool: "officepdf",
      serverFilename: UPLOADED,
      filename: "Contract.docx",
    }),
    res
  );

  assert.equal(calls[0].body.convert_to, undefined);
  assert.equal(res.body.filename, "Contract.pdf");
});

// A job can finish and still hand back the wrong sort of file. Catching it
// here beats the phone downloading something Word will not open.
test("a job that returns the wrong sort of file is refused", async () => {
  stubFetch({
    process: {
      status: 200,
      body: { download_filename: "out.pdf", output_extensions: '["pdf"]' },
    },
  });
  const res = response();

  await processHandler(
    request({
      kind: "pdf-to-word",
      token: SESSION,
      server: WORKER,
      task: TASK,
      tool: "pdfoffice",
      serverFilename: UPLOADED,
      filename: "a.pdf",
    }),
    res
  );

  assert.equal(res.statusCode, 502);
  assert.match(res.body.error, /without returning a Word file/);
});

// `server` comes from the device. Without this check, a caller could name any
// host and have this function make the request for them.
test("process will only talk to the conversion service", async () => {
  stubFetch();
  const res = response();

  await processHandler(
    request({
      kind: "pdf-to-word",
      token: SESSION,
      server: "evil.example.com",
      task: TASK,
      tool: "pdfoffice",
      serverFilename: UPLOADED,
      filename: "a.pdf",
    }),
    res
  );

  assert.equal(res.statusCode, 400);
  assert.match(res.body.error, /worker host/);
});

test("a job with a made-up session is refused", async () => {
  stubFetch();
  const res = response();

  await processHandler(
    request({
      kind: "pdf-to-word",
      token: "not-a-token",
      server: WORKER,
      task: TASK,
      tool: "pdfoffice",
      serverFilename: UPLOADED,
      filename: "a.pdf",
    }),
    res
  );

  assert.equal(res.statusCode, 400);
});

test("a file the worker rejects reads as the customer's problem, not ours", async () => {
  stubFetch({
    process: {
      status: 400,
      body: { error: { message: "File has a password" } },
    },
  });
  const res = response();

  await processHandler(
    request({
      kind: "pdf-to-word",
      token: SESSION,
      server: WORKER,
      task: TASK,
      tool: "pdfoffice",
      serverFilename: UPLOADED,
      filename: "a.pdf",
    }),
    res
  );

  assert.equal(res.statusCode, 422);
  assert.match(res.body.error, /password/i);
});

test("a browser preflight is answered without doing any work", async () => {
  const res = response();
  await start(request({}, "OPTIONS"), res);
  assert.equal(res.statusCode, 204);
});

test("a GET is refused", async () => {
  const res = response();
  await start(request({}, "GET"), res);
  assert.equal(res.statusCode, 405);
});

// --- Compressing, merging and splitting ------------------------------------

function pdfResult(name = "a-compressed.pdf") {
  return {
    status: 200,
    body: {
      download_filename: name,
      output_extensions: '["pdf"]',
      status: "TaskSuccess",
    },
  };
}

function processed(kind, body) {
  const res = response();
  return processHandler(
    request({
      kind,
      token: SESSION,
      server: WORKER,
      task: TASK,
      ...body,
    }),
    res
  ).then(() => res);
}

test("each job starts on its own tool and its own page", async () => {
  for (const [kind, page, tool] of [
    ["compress", "/compress_pdf", "compress"],
    ["merge", "/merge_pdf", "merge"],
    ["split", "/split_pdf", "split"],
  ]) {
    const calls = stubFetch();
    const res = response();
    await start(request({ kind, filename: "Report.pdf" }), res);

    assert.equal(res.statusCode, 200, kind);
    assert.equal(
      calls.find((call) => call.url.includes("www.ilovepdf.com")).url,
      `https://www.ilovepdf.com${page}`
    );
    assert.equal(
      calls.find((call) => call.url.includes("/v1/start/")).url,
      `https://api.ilovepdf.com/v1/start/${tool}`
    );
  }
});

test("the finished file is named for what was done to it", async () => {
  stubFetch();
  for (const [kind, expected] of [
    ["compress", "Report-compressed.pdf"],
    ["merge", "Report-merged.pdf"],
    ["split", "Report-split.pdf"],
  ]) {
    const res = response();
    await start(request({ kind, filename: "Report.pdf" }), res);
    assert.equal(res.body.filename, expected);
  }
});

test("a compression level is passed through, and only a known one", async () => {
  const calls = stubFetch({ process: pdfResult() });
  const res = await processed("compress", {
    tool: "compress",
    files: [{ serverFilename: UPLOADED, filename: "a.pdf" }],
    options: { compressionLevel: "extreme" },
  });

  assert.equal(res.statusCode, 200);
  const sent = calls.find((call) => call.url.includes("/v1/process")).body;
  assert.equal(sent.compression_level, "extreme");

  const bad = await processed("compress", {
    tool: "compress",
    files: [{ serverFilename: UPLOADED, filename: "a.pdf" }],
    options: { compressionLevel: "flatten-everything" },
  });
  assert.equal(bad.statusCode, 400);
});

test("a level nobody chose is the balanced one", async () => {
  const calls = stubFetch({ process: pdfResult() });
  await processed("compress", {
    tool: "compress",
    files: [{ serverFilename: UPLOADED, filename: "a.pdf" }],
  });

  const sent = calls.find((call) => call.url.includes("/v1/process")).body;
  assert.equal(sent.compression_level, "recommended");
});

test("merging sends every file, in the order they were given", async () => {
  const calls = stubFetch({ process: pdfResult("merged.pdf") });
  const res = await processed("merge", {
    tool: "merge",
    files: [
      { serverFilename: "1111111111111111.pdf", filename: "Cover.pdf" },
      { serverFilename: "2222222222222222.pdf", filename: "Body.pdf" },
    ],
  });

  assert.equal(res.statusCode, 200);
  const sent = calls.find((call) => call.url.includes("/v1/process")).body;
  assert.deepEqual(
    sent.files.map((file) => file.filename),
    ["Cover.pdf", "Body.pdf"]
  );
});

test("splitting by ranges asks for one file back", async () => {
  const calls = stubFetch({ process: pdfResult("a-split.pdf") });
  const res = await processed("split", {
    tool: "split",
    files: [{ serverFilename: UPLOADED, filename: "a.pdf" }],
    options: { ranges: "1-3, 8", mergeAfter: true },
  });

  assert.equal(res.statusCode, 200);
  const sent = calls.find((call) => call.url.includes("/v1/process")).body;
  assert.equal(sent.split_mode, "ranges");
  assert.equal(sent.ranges, "1-3,8");
  assert.equal(sent.merge_after, true);
});

test("splitting every N pages comes back as a zip of them", async () => {
  const calls = stubFetch({
    process: {
      status: 200,
      body: {
        download_filename: "a-split.zip",
        output_extensions: '["zip"]',
        status: "TaskSuccess",
      },
    },
  });
  const res = await processed("split", {
    tool: "split",
    files: [{ serverFilename: UPLOADED, filename: "a.pdf" }],
    options: { everyPages: 5 },
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.filename, "a-split.zip");
  const sent = calls.find((call) => call.url.includes("/v1/process")).body;
  assert.equal(sent.split_mode, "fixed_range");
  assert.equal(sent.fixed_range, 5);
});

test("a page range that is not one is refused before the worker sees it", async () => {
  stubFetch({ process: pdfResult() });
  for (const ranges of ["all of them", "1-", "-4", "1;2", "", "9999999"]) {
    const res = await processed("split", {
      tool: "split",
      files: [{ serverFilename: UPLOADED, filename: "a.pdf" }],
      options: { ranges },
    });
    assert.equal(res.statusCode, 400, `should refuse ${JSON.stringify(ranges)}`);
  }
});

test("splitting into nothing is refused, however it is asked for", async () => {
  stubFetch({ process: pdfResult() });
  for (const every of [0, -2, 1.5, "lots"]) {
    const res = await processed("split", {
      tool: "split",
      files: [{ serverFilename: UPLOADED, filename: "a.pdf" }],
      options: { everyPages: every },
    });
    assert.equal(res.statusCode, 400, `should refuse ${every}`);
  }
});

test("more files than a job can take is refused", async () => {
  stubFetch({ process: pdfResult("merged.pdf") });
  const res = await processed("merge", {
    tool: "merge",
    files: Array.from({ length: 21 }, (_, i) => ({
      serverFilename: `${String(i).padStart(16, "0")}.pdf`,
      filename: `${i}.pdf`,
    })),
  });

  assert.equal(res.statusCode, 400);
  assert.match(res.body.error, /more files/i);
});

test("a compress job that hands back something else is refused", async () => {
  stubFetch({
    process: {
      status: 200,
      body: {
        download_filename: "a.docx",
        output_extensions: '["docx"]',
        status: "TaskSuccess",
      },
    },
  });
  const res = await processed("compress", {
    tool: "compress",
    files: [{ serverFilename: UPLOADED, filename: "a.pdf" }],
  });

  assert.equal(res.statusCode, 502);
  assert.match(res.body.error, /without returning a PDF/);
});
