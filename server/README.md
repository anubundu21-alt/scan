# Conversion backend

The endpoints behind the Pro file tools: PDF to Word, Word to PDF, Compress,
Merge and Split. Scanning, OCR, signing, export, and the library's merge/split
of camera scans still run on the phone. These jobs are here because keeping a
document's text and vectors through them needs an engine no phone ships with.

This mirrors what PDF Palette serves at the same paths, so you only need to
deploy it if the app is not pointed at the Palette site. The app does not care
which host answers, as long as the shapes below match.

## The flow

```
app                       this backend                conversion service
 |  POST /api/ilove/start ---->|                              |
 |                             |-- start task --------------->|
 |<---- token, task, uploadUrl-|                              |
 |                                                            |
 |------------- upload the file straight there -------------->|
 |<------------------------ server_filename ------------------|
 |                                                            |
 |  POST /api/ilove/process -->|                              |
 |                             |-- process ------------------>|
 |<---- downloadUrl -----------|                              |
 |                                                            |
 |------------- download the result straight back ------------|
```

The file never passes through this backend. That is deliberate: it halves the
transfer, keeps the function inside a serverless body-size limit, and means
there is no point in the pipeline where we hold a copy of someone's document.
Nothing is written to disk here and nothing is logged but status codes.

### `POST /api/ilove/start`

```json
{ "kind": "pdf-to-word", "filename": "Offer letter.pdf" }
```

```json
{
  "engine": "ilovepdf",
  "token": "…",
  "server": "api99o.ilovepdf.com",
  "task": "…",
  "tool": "pdfoffice",
  "uploadUrl": "https://api99o.ilovepdf.com/v1/upload",
  "filename": "Offer letter.docx"
}
```

`kind` is `pdf-to-word`, `word-to-pdf`, `compress`, `merge` or `split`. Merging
uploads several files to the same task before `/process`. Splitting by named
pages asks for one PDF back (`mergeAfter`); splitting every N pages comes back
as a zip of them.

Note that `filename` coming back is what the **finished** file should be
called. The upload and the process call both carry the name of the file being
sent, because that is the name the converter writes into the document.

The app then POSTs `multipart/form-data` to `uploadUrl` with the fields `task`
and `file`, and `Authorization: Bearer {token}`, and gets back
`{ "server_filename": "…" }`.

### `POST /api/ilove/process`

```json
{
  "kind": "pdf-to-word",
  "token": "…",
  "server": "api99o.ilovepdf.com",
  "task": "…",
  "tool": "pdfoffice",
  "serverFilename": "…",
  "filename": "Offer letter.pdf",
  "files": [{ "serverFilename": "…", "filename": "Offer letter.pdf" }],
  "options": { "compressionLevel": "recommended" }
}
```

```json
{
  "engine": "ilovepdf",
  "downloadUrl": "https://api99o.ilovepdf.com/v1/download/…",
  "token": "…",
  "filename": "Offer letter.docx"
}
```

The app downloads that URL with the token from this reply, falling back to the
one `/start` gave it.

### `GET /api/ilove/health`

Says whether a conversion session can be opened from this deployment.

## How the two directions are started

Word to PDF is `officepdf`, which is in the developer catalogue. PDF to Word
is not in that catalogue at all: the tool behind the website is `pdfoffice`
with `convert_to=docx`, and a developer JWT gets a 404 from its start route.
Only the public session token the tool page hands out can open it.

So both directions start the way the website does — read the session token off
`ilovepdf.com/pdf_to_word` or `/word_to_pdf`, then `GET /v1/start/{tool}` with
it. The token is cached for the life of the instance. A useful side effect is
that this runs with no project keys at all.

## Deploying

Point a Vercel project at this directory. Nothing has to be configured, but
two variables are there if a tool name ever changes:

| Variable | Required | What it is |
| --- | --- | --- |
| `ILOVEPDF_TOOL` | no | Overrides the PDF to Word tool. Defaults to `pdfoffice`. |
| `ILOVEPDF_WORD_TOOL` | no | Overrides the Word to PDF tool. Defaults to `officepdf`. |
| `ILOVEPDF_COMPRESS_TOOL` | no | Overrides compress. Defaults to `compress`. |
| `ILOVEPDF_MERGE_TOOL` | no | Overrides merge. Defaults to `merge`. |
| `ILOVEPDF_SPLIT_TOOL` | no | Overrides split. Defaults to `split`. |

## Tests

```
cd server && npm test
```

No dependencies and no network: the tool pages and the workers are stubbed, so
the tests check which tool each direction starts, that the session is read once
and reused, the `convert_to` and `output_filename` parameters, the host, task,
session and upload-name checks on everything that arrives from the device, and
that a job which returns the wrong sort of file is refused rather than passed
on.

## Pointing the app at it

The app ships pointed at the PDF Palette deployment, so a plain build
converts. To send a build somewhere else — this backend on your own project,
or a staging host:

```
flutter build ipa --dart-define=SCANELLA_CONVERT_API=https://your-host
```

CI reads that from the `CONVERT_API_BASE_URL` repository variable when it is
set. Leaving it unset is fine and means the built-in host.

Give the origin only: no trailing slash and no `/api`, since the app appends
the two paths itself. It has to be `https`; cleartext is blocked on both
platforms.

## A note on the bearer token

`/start` hands the device a token so it can upload and download without the
bytes passing through us. It is a session token scoped to the job and it
expires on its own.
