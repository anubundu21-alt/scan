import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:scan2/features/pro/data/docx_images.dart';

/// The jobs that run off the device.
///
/// Scanning, OCR, signing and export still run on the phone. These are the
/// jobs that want a PDF engine no phone ships with: keeping a document's text
/// and vectors through a conversion, a shrink or a page copy is not something
/// worth reimplementing badly.
enum ConversionKind {
  pdfToWord(
    wire: 'pdf-to-word',
    sourceExtensions: ['pdf'],
    resultExtension: 'docx',
    resultMimeType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ),
  wordToPdf(
    wire: 'word-to-pdf',
    sourceExtensions: ['doc', 'docx', 'odt', 'rtf'],
    resultExtension: 'pdf',
    resultMimeType: 'application/pdf',
  ),
  compress(
    wire: 'compress',
    sourceExtensions: ['pdf'],
    resultExtension: 'pdf',
    resultMimeType: 'application/pdf',
  ),
  merge(
    wire: 'merge',
    sourceExtensions: ['pdf'],
    resultExtension: 'pdf',
    resultMimeType: 'application/pdf',
    takesSeveralFiles: true,
  ),
  split(
    wire: 'split',
    sourceExtensions: ['pdf'],
    resultExtension: 'pdf',
    resultMimeType: 'application/pdf',
    // Asked for one range it returns a PDF; asked for several files it
    // returns a zip of them, and only the service knows which until it has.
    mayReturnZip: true,
  );

  const ConversionKind({
    required this.wire,
    required this.sourceExtensions,
    required this.resultExtension,
    required this.resultMimeType,
    this.takesSeveralFiles = false,
    this.mayReturnZip = false,
  });

  /// The name the service knows this job by.
  final String wire;

  /// What the file picker should let someone choose.
  final List<String> sourceExtensions;

  final String resultExtension;
  final String resultMimeType;
  final bool takesSeveralFiles;
  final bool mayReturnZip;
}

/// How hard to squeeze, in the same three steps the web tool offers.
enum CompressionLevel {
  /// Around 300 DPI. Meant for something that will be printed.
  light(wire: 'low', label: 'Less', blurb: 'Best quality, smallest saving'),

  /// Around 200 DPI.
  balanced(
    wire: 'recommended',
    label: 'Recommended',
    blurb: 'Good quality, much smaller',
  ),

  /// Around 100 DPI.
  hard(wire: 'extreme', label: 'Most', blurb: 'Smallest file, softer images');

  const CompressionLevel({
    required this.wire,
    required this.label,
    required this.blurb,
  });

  final String wire;
  final String label;
  final String blurb;
}

/// What to ask a job for beyond the files themselves.
class ConversionOptions {
  const ConversionOptions({this.compression, this.ranges, this.everyPages});

  /// Compressing only.
  final CompressionLevel? compression;

  /// Splitting: the pages to keep, as someone would write them — `1-3, 8`.
  final String? ranges;

  /// Splitting: cut the document into files of this many pages each.
  final int? everyPages;

  /// Splitting by ranges gives one file back rather than a zip holding one.
  Map<String, Object?>? toWire() {
    final out = <String, Object?>{
      if (compression != null) 'compressionLevel': compression!.wire,
      if (everyPages != null) 'everyPages': everyPages,
      if (everyPages == null && ranges != null) ...{
        'ranges': ranges,
        'mergeAfter': true,
      },
    };
    return out.isEmpty ? null : out;
  }
}

/// One file on its way into a job.
class ConversionSource {
  const ConversionSource({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// Where a job has got to. [fraction] is null while the service is working and
/// there is nothing honest to put on a bar.
enum ConversionStage { starting, uploading, converting, downloading, done }

class ConversionStatus {
  const ConversionStatus({
    required this.stage,
    required this.message,
    this.fraction,
  });

  final ConversionStage stage;
  final String message;
  final double? fraction;
}

typedef ConversionProgress = void Function(ConversionStatus status);

/// A converted file, in memory. Nothing is written until the caller decides
/// where it goes.
class ConvertedFile {
  const ConvertedFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

/// A conversion that did not finish, with a [code] the UI can turn into one
/// line someone can act on.
class ConversionFailure implements Exception {
  const ConversionFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Runs a file through the conversion service.
///
/// Four steps, and the file itself only ever travels between the phone and the
/// conversion servers:
///
///   1. `POST /api/ilove/start` — our backend opens a job and hands back the
///      one-job credentials.
///   2. the phone uploads straight to the address that came back, so the bytes
///      never pass through our own function.
///   3. `POST /api/ilove/process` — our backend asks for the conversion.
///   4. the phone downloads the result.
///
/// We keep no copy: our backend sees filenames and job ids, never file
/// contents, and the conversion servers drop both input and output once the
/// job closes.
class ConversionService {
  ConversionService({
    Uri? baseUrl,
    this.timeouts = const ConversionTimeouts(),
    this.websiteOrigin,
    this.apiOrigin,
  }) : baseUrl = baseUrl ?? defaultBaseUrl;

  /// A service with nowhere to send a file, so the screens can be seen in the
  /// state they fall back to if the built-in host is ever taken out.
  const ConversionService.withoutHost({
    this.timeouts = const ConversionTimeouts(),
    this.websiteOrigin,
    this.apiOrigin,
  }) : baseUrl = null;

  /// The host that answers when a build names no other one. It serves the
  /// same two endpoints this client speaks, so a plain build converts.
  static const _fallbackBaseUrl = 'https://pdf-palette-2.vercel.app';

  /// Point a build somewhere else with
  /// `--dart-define=SCANELLA_CONVERT_API=https://your-host`.
  static const _configuredBaseUrl = String.fromEnvironment(
    'SCANELLA_CONVERT_API',
  );

  static Uri? get defaultBaseUrl =>
      _parse(_configuredBaseUrl) ?? _parse(_fallbackBaseUrl);

  static Uri? _parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri;
  }

  /// Null only when a caller passes no host and the built-in one is unusable.
  final Uri? baseUrl;
  final ConversionTimeouts timeouts;

  /// Origin of the public tool pages, used when the conversion host opens the
  /// wrong job. Null means the real site. Tests point this at loopback.
  final Uri? websiteOrigin;

  /// Origin of `/v1/start/{tool}`, used with [websiteOrigin]. Null means the
  /// real workers.
  final Uri? apiOrigin;

  bool get isConfigured => baseUrl != null;

  /// Session tokens from the tool pages, kept for the life of the isolate.
  static final Map<String, String> _sessionTokens = {};

  /// Tests that hit different fake hosts need a clean slate.
  @visibleForTesting
  static void clearSessionCache() => _sessionTokens.clear();

  Future<ConvertedFile> convert({
    required Uint8List bytes,
    required String filename,
    required ConversionKind kind,
    ConversionOptions? options,
    ConversionProgress? onProgress,
  }) {
    return convertAll(
      sources: [ConversionSource(bytes: bytes, filename: filename)],
      kind: kind,
      options: options,
      onProgress: onProgress,
    );
  }

  /// Merging is the reason this takes a list: every file goes up to the one
  /// job before it is asked to run.
  Future<ConvertedFile> convertAll({
    required List<ConversionSource> sources,
    required ConversionKind kind,
    ConversionOptions? options,
    ConversionProgress? onProgress,
  }) async {
    final base = baseUrl;
    if (base == null) {
      throw const ConversionFailure(
        'unconfigured',
        'Converting is not switched on in this build of the app.',
      );
    }
    if (sources.isEmpty) {
      throw const ConversionFailure('empty', 'There is nothing to work on.');
    }
    if (sources.any((source) => source.bytes.isEmpty)) {
      throw const ConversionFailure('empty', 'That file is empty.');
    }

    final filename = sources.first.filename;
    final client = HttpClient()
      ..connectionTimeout = timeouts.connect
      ..userAgent = 'Scanella';
    try {
      onProgress?.call(
        const ConversionStatus(
          stage: ConversionStage.starting,
          message: 'Getting ready…',
          fraction: 0,
        ),
      );
      var job = await _start(client, base, kind, filename);
      if (_wrongTool(kind, job.tool)) {
        // The live conversion host still opens a Word job for compress,
        // merge and split. The phone then talks to the workers itself.
        job = await _startDirect(client, kind, filename);
      }
      final uploaded = <Map<String, String>>[];
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        final serverFilename = await _upload(
          client,
          job,
          source.bytes,
          source.filename,
          onProgress,
          fileNumber: i + 1,
          fileCount: sources.length,
        );
        uploaded.add({
          'serverFilename': serverFilename,
          'filename': source.filename,
        });
      }
      final ready = await _process(
        client,
        base,
        job,
        kind,
        uploaded,
        filename,
        options,
        onProgress,
      );
      final file = await _download(client, ready, kind, filename, onProgress);
      final finished = await _repair(file, kind, onProgress);
      onProgress?.call(
        const ConversionStatus(
          stage: ConversionStage.done,
          message: 'Done',
          fraction: 1,
        ),
      );
      return finished;
    } on ConversionFailure {
      rethrow;
    } on TimeoutException {
      throw const ConversionFailure(
        'timeout',
        'Converting took too long. Try again, or try a smaller file.',
      );
    } on SocketException {
      throw const ConversionFailure('offline', _offlineMessage);
    } on HandshakeException {
      throw const ConversionFailure('offline', _offlineMessage);
    } on HttpException {
      throw const ConversionFailure('offline', _offlineMessage);
    } finally {
      client.close(force: true);
    }
  }

  static const _offlineMessage =
      'Could not reach the converter. Check your connection and try again.';

  Future<_ConversionJob> _start(
    HttpClient client,
    Uri base,
    ConversionKind kind,
    String filename,
  ) async {
    final body = await _postJson(
      client,
      endpointFor(base, '/api/ilove/start'),
      {'kind': kind.wire, 'filename': filename},
      timeouts.start,
    );

    // The backend answers with the engine it opened the job on, and a reason
    // when it could not open one at all.
    final engine = _string(body['engine']);
    if (engine != null && engine != 'ilovepdf') {
      throw ConversionFailure(
        'service',
        _string(body['reason']) ?? 'Converting is not available right now.',
      );
    }

    final token = _string(body['token']);
    final server = _string(body['server']);
    final task = _string(body['task']);
    final tool = _string(body['tool']);
    final uploadUrl = _string(body['uploadUrl']) ?? _string(body['upload_url']);
    if (token == null || task == null || uploadUrl == null) {
      throw const ConversionFailure('service', _brokenReplyMessage);
    }
    final upload = Uri.tryParse(uploadUrl);
    if (upload == null || !upload.hasScheme) {
      throw const ConversionFailure('service', _brokenReplyMessage);
    }
    return _ConversionJob(
      token: token,
      server: server ?? upload.host,
      task: task,
      tool: tool ?? kind.wire,
      uploadUrl: upload,
      resultFilename: _string(body['filename']),
    );
  }

  static const _brokenReplyMessage =
      'The converter sent back something we could not read. Try again.';

  static const _website = 'https://www.ilovepdf.com';
  static const _api = 'https://api.ilovepdf.com';

  /// The conversion host used to treat every unknown kind as PDF to Word.
  static bool _wrongTool(ConversionKind kind, String tool) {
    final expected = switch (kind) {
      ConversionKind.compress => 'compress',
      ConversionKind.merge => 'merge',
      ConversionKind.split => 'split',
      _ => null,
    };
    if (expected == null) return false;
    return tool != expected;
  }

  static String _pagePath(ConversionKind kind) => switch (kind) {
    ConversionKind.compress => '/compress_pdf',
    ConversionKind.merge => '/merge_pdf',
    ConversionKind.split => '/split_pdf',
    ConversionKind.wordToPdf => '/word_to_pdf',
    ConversionKind.pdfToWord => '/pdf_to_word',
  };

  static String _directTool(ConversionKind kind) => switch (kind) {
    ConversionKind.compress => 'compress',
    ConversionKind.merge => 'merge',
    ConversionKind.split => 'split',
    ConversionKind.wordToPdf => 'officepdf',
    ConversionKind.pdfToWord => 'pdfoffice',
  };

  Future<_ConversionJob> _startDirect(
    HttpClient client,
    ConversionKind kind,
    String filename,
  ) async {
    final token = await _sessionToken(client, _pagePath(kind));
    final tool = _directTool(kind);
    final api = apiOrigin ?? Uri.parse(_api);
    final started = await _getJson(
      client,
      api.replace(path: '/v1/start/$tool'),
      token,
      timeouts.start,
    );
    final server = _string(started['server']);
    final task = _string(started['task']);
    if (server == null || task == null) {
      throw const ConversionFailure('service', _brokenReplyMessage);
    }
    if (!_isLoopback(api) && !_isWorkerHost(server)) {
      throw const ConversionFailure('service', _brokenReplyMessage);
    }
    return _ConversionJob(
      token: token,
      server: server,
      task: task,
      tool: tool,
      uploadUrl: _workerUrl(api, server, '/v1/upload'),
      resultFilename: _directResultName(filename, kind),
      direct: true,
    );
  }

  Future<String> _sessionToken(HttpClient client, String pagePath) async {
    final cached = _sessionTokens[pagePath];
    if (cached != null) return cached;
    final site = websiteOrigin ?? Uri.parse(_website);
    final html = await _getText(
      client,
      site.replace(path: pagePath),
      timeouts.start,
    );
    final token = parseToolPageToken(html);
    if (token == null) {
      throw const ConversionFailure(
        'service',
        'Could not start this job. Try again in a moment.',
      );
    }
    _sessionTokens[pagePath] = token;
    return token;
  }

  Future<Map<String, dynamic>> _getJson(
    HttpClient client,
    Uri uri,
    String token,
    Duration timeout,
  ) async {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(timeout);
    return _readJson(response);
  }

  Future<String> _getText(HttpClient client, Uri uri, Duration timeout) async {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'text/html');
    final response = await request.close().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ConversionFailure(
        'service',
        'Could not start this job. Try again in a moment.',
      );
    }
    return _readBody(response);
  }

  Uri _workerUrl(Uri api, String server, String path) {
    if (_isLoopback(api)) return api.replace(path: path);
    return Uri(scheme: 'https', host: server, path: path);
  }

  static bool _isLoopback(Uri uri) =>
      uri.host == '127.0.0.1' || uri.host == 'localhost';

  static bool _isWorkerHost(String host) => RegExp(
    r'^[a-z0-9-]+(?:\.[a-z0-9-]+)*\.ilovepdf\.com$',
  ).hasMatch(host.toLowerCase());

  static String _directResultName(String filename, ConversionKind kind) {
    final stem = filename
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'\.[^.]*$'), '')
        .trim();
    final base = stem.isEmpty ? 'document' : stem;
    final suffix = switch (kind) {
      ConversionKind.compress => '-compressed',
      ConversionKind.merge => '-merged',
      ConversionKind.split => '-split',
      _ => '',
    };
    return '$base$suffix.${kind.resultExtension}';
  }

  /// Pulls the session token out of a tool page's inline config.
  @visibleForTesting
  static String? parseToolPageToken(String html) {
    const marker = 'var ilovepdfConfig = ';
    final marked = html.indexOf(marker);
    if (marked < 0) return null;
    final start = html.indexOf('{', marked);
    if (start < 0) return null;
    var depth = 0;
    for (var i = start; i < html.length; i++) {
      final ch = html[i];
      if (ch == '{') {
        depth += 1;
      } else if (ch == '}') {
        depth -= 1;
        if (depth == 0) {
          try {
            final decoded = jsonDecode(html.substring(start, i + 1));
            if (decoded is Map) return _string(decoded['token']);
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }

  /// Straight from the device to the upload address. Deliberately not through
  /// our own backend: it would double the transfer and put the file on a
  /// server we promised not to keep it on.
  Future<String> _upload(
    HttpClient client,
    _ConversionJob job,
    Uint8List bytes,
    String filename,
    ConversionProgress? onProgress, {
    int fileNumber = 1,
    int fileCount = 1,
  }) async {
    // Merging several files is one long upload as far as anyone watching is
    // concerned, so the bar runs across all of them rather than restarting.
    final message = fileCount > 1
        ? 'Uploading $fileNumber of $fileCount…'
        : 'Uploading…';
    double overall(double withinFile) =>
        (fileNumber - 1 + withinFile) / fileCount;

    onProgress?.call(
      ConversionStatus(
        stage: ConversionStage.uploading,
        message: message,
        fraction: overall(0),
      ),
    );

    final boundary = _boundary();
    final head = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="task"\r\n\r\n'
      '${job.task}\r\n'
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="file"; '
      'filename="${_headerSafe(filename)}"\r\n'
      'Content-Type: ${mimeTypeFor(filename)}\r\n\r\n',
    );
    final tail = utf8.encode('\r\n--$boundary--\r\n');

    final request = await client.postUrl(job.uploadUrl);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${job.token}');
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );
    request.contentLength = head.length + bytes.length + tail.length;
    request.add(head);

    const chunk = 64 * 1024;
    for (var sent = 0; sent < bytes.length; sent += chunk) {
      final end = math.min(sent + chunk, bytes.length);
      request.add(Uint8List.sublistView(bytes, sent, end));
      await request.flush();
      onProgress?.call(
        ConversionStatus(
          stage: ConversionStage.uploading,
          message: message,
          fraction: overall(end / bytes.length),
        ),
      );
    }
    request.add(tail);

    final response = await request.close().timeout(timeouts.upload);
    final body = await _readJson(response);
    final serverFilename =
        _string(body['server_filename']) ?? _string(body['serverFilename']);
    if (serverFilename == null) {
      throw const ConversionFailure('service', _brokenReplyMessage);
    }
    return serverFilename;
  }

  Future<_ReadyFile> _process(
    HttpClient client,
    Uri base,
    _ConversionJob job,
    ConversionKind kind,
    List<Map<String, String>> files,
    String filename,
    ConversionOptions? options,
    ConversionProgress? onProgress,
  ) async {
    onProgress?.call(
      ConversionStatus(
        stage: ConversionStage.converting,
        message: switch (kind) {
          ConversionKind.compress => 'Compressing…',
          ConversionKind.merge => 'Merging…',
          ConversionKind.split => 'Splitting…',
          _ => 'Converting…',
        },
      ),
    );
    if (job.direct) {
      return _processDirect(client, job, kind, files, filename, options);
    }
    final wire = options?.toWire();
    final body = await _postJson(
      client,
      endpointFor(base, '/api/ilove/process'),
      {
        'kind': kind.wire,
        'token': job.token,
        'server': job.server,
        'task': job.task,
        'tool': job.tool,
        'files': files,
        // Still sent on its own so an older backend understands the job.
        'serverFilename': files.first['serverFilename'],
        'filename': filename,
        if (wire != null) 'options': wire,
      },
      timeouts.process,
    );

    final engine = _string(body['engine']);
    if (engine != null && engine != 'ilovepdf') {
      throw ConversionFailure(
        'service',
        _string(body['reason']) ?? 'Converting failed. Try again.',
      );
    }

    final downloadUrl =
        _string(body['downloadUrl']) ?? _string(body['download_url']);
    if (downloadUrl == null) {
      throw const ConversionFailure('service', _brokenReplyMessage);
    }
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null || !uri.hasScheme) {
      throw const ConversionFailure('service', _brokenReplyMessage);
    }
    return _ReadyFile(
      url: uri,
      // The download can be handed a token of its own; when it is not, the
      // one the job started with still works.
      token: _string(body['token']) ?? job.token,
      filename:
          _string(body['filename']) ??
          _string(body['download_filename']) ??
          job.resultFilename ??
          resultNameFor(filename, kind),
    );
  }

  /// Same process call the backend would make, but straight at the worker,
  /// so a host that still thinks this is a Word job cannot rewrite it.
  Future<_ReadyFile> _processDirect(
    HttpClient client,
    _ConversionJob job,
    ConversionKind kind,
    List<Map<String, String>> files,
    String filename,
    ConversionOptions? options,
  ) async {
    final api = apiOrigin ?? Uri.parse(_api);
    final payload = <String, Object?>{
      'task': job.task,
      'tool': job.tool,
      'output_filename': '{filename}',
      'files': [
        for (final file in files)
          {
            'server_filename': file['serverFilename'],
            'filename': file['filename'],
          },
      ],
      ...?_directOptions(kind, options),
    };
    final body = await _postJson(
      client,
      _workerUrl(api, job.server, '/v1/process'),
      payload,
      timeouts.process,
      token: job.token,
    );
    return _ReadyFile(
      url: _workerUrl(api, job.server, '/v1/download/${job.task}'),
      token: job.token,
      filename:
          _string(body['download_filename']) ??
          job.resultFilename ??
          resultNameFor(filename, kind),
    );
  }

  static Map<String, Object?>? _directOptions(
    ConversionKind kind,
    ConversionOptions? options,
  ) {
    if (kind == ConversionKind.compress) {
      return {'compression_level': options?.compression?.wire ?? 'recommended'};
    }
    if (kind != ConversionKind.split) return null;
    if (options?.everyPages != null) {
      return {'split_mode': 'fixed_range', 'fixed_range': options!.everyPages};
    }
    final ranges = options?.ranges?.trim() ?? '';
    return {
      'split_mode': 'ranges',
      'ranges': ranges.replaceAll(RegExp(r'\s+'), ''),
      if (options?.ranges != null) 'merge_after': true,
    };
  }

  Future<ConvertedFile> _download(
    HttpClient client,
    _ReadyFile ready,
    ConversionKind kind,
    String sourceName,
    ConversionProgress? onProgress,
  ) async {
    onProgress?.call(
      const ConversionStatus(
        stage: ConversionStage.downloading,
        message: 'Downloading…',
        fraction: 0,
      ),
    );

    final request = await client.getUrl(ready.url);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${ready.token}',
    );
    final response = await request.close().timeout(timeouts.download);
    if (response.statusCode != HttpStatus.ok) {
      throw _failureFrom(response.statusCode, await _readBody(response));
    }

    final total = response.contentLength;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(timeouts.download)) {
      builder.add(chunk);
      if (total > 0) {
        onProgress?.call(
          ConversionStatus(
            stage: ConversionStage.downloading,
            message: 'Downloading…',
            fraction: math.min(1, builder.length / total),
          ),
        );
      }
    }

    final bytes = builder.takeBytes();
    if (!_looksLike(kind, bytes)) {
      // A converter that fails late can answer 200 with an error page where
      // the document should be.
      throw ConversionFailure(
        'service',
        _messageIn(utf8.decode(bytes, allowMalformed: true)) ??
            _brokenReplyMessage,
      );
    }
    return ConvertedFile(
      bytes: bytes,
      filename: _ensureExtension(ready.filename, kind, sourceName, bytes),
      mimeType: _mimeTypeFor(kind, bytes),
    );
  }

  /// A Word file the service built can carry page pictures that some readers
  /// draw as solid black. Only Word files have them, and only some of those,
  /// so this usually hands the same bytes straight back.
  Future<ConvertedFile> _repair(
    ConvertedFile file,
    ConversionKind kind,
    ConversionProgress? onProgress,
  ) async {
    if (kind != ConversionKind.pdfToWord) return file;
    onProgress?.call(
      const ConversionStatus(
        stage: ConversionStage.downloading,
        message: 'Finishing…',
        fraction: 1,
      ),
    );
    final Uint8List repaired;
    try {
      repaired = await compute(repairDocxImages, file.bytes);
    } catch (_) {
      // A page we could not rewrite is still better than no document.
      return file;
    }
    if (identical(repaired, file.bytes)) return file;
    return ConvertedFile(
      bytes: repaired,
      filename: file.filename,
      mimeType: file.mimeType,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    HttpClient client,
    Uri uri,
    Map<String, Object?> payload,
    Duration timeout, {
    String? token,
  }) async {
    final request = await client.postUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    request.add(utf8.encode(jsonEncode(payload)));
    final response = await request.close().timeout(timeout);
    return _readJson(response);
  }

  Future<Map<String, dynamic>> _readJson(HttpClientResponse response) async {
    final body = await _readBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failureFrom(response.statusCode, body);
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Falls through to the same failure as a reply of the wrong shape.
    }
    throw const ConversionFailure('service', _brokenReplyMessage);
  }

  Future<String> _readBody(HttpClientResponse response) =>
      response.transform(utf8.decoder).join().timeout(timeouts.start);

  /// Turns whatever the service said into a code and a sentence.
  static ConversionFailure _failureFrom(int status, String body) {
    final said = _messageIn(body) ?? '';
    if (RegExp('password|encrypt', caseSensitive: false).hasMatch(said)) {
      return const ConversionFailure(
        'password',
        'That file is password-protected. Unlock it first, then convert it.',
      );
    }
    if (RegExp(
      'damaged|corrupt|unreadable',
      caseSensitive: false,
    ).hasMatch(said)) {
      return const ConversionFailure(
        'corrupt',
        'That file could not be read. It may be damaged.',
      );
    }
    return switch (status) {
      HttpStatus.requestEntityTooLarge => const ConversionFailure(
        'too-large',
        'That file is too big to convert. Try a smaller one.',
      ),
      HttpStatus.tooManyRequests => const ConversionFailure(
        'busy',
        'The converter is busy right now. Try again in a moment.',
      ),
      HttpStatus.unauthorized ||
      HttpStatus.forbidden => const ConversionFailure(
        'service',
        'The converter turned this job down. Try again in a moment.',
      ),
      HttpStatus.notImplemented ||
      HttpStatus.serviceUnavailable => const ConversionFailure(
        'unconfigured',
        'Converting is not available right now. Try again later.',
      ),
      _ => ConversionFailure(
        'service',
        said.isEmpty ? 'Converting failed. Try again.' : said,
      ),
    };
  }

  /// Digs the human part out of an error body, whether it came back as
  /// `{"error": "…"}`, `{"error": {"message": "…"}}` or plain text.
  static String? _messageIn(String body) {
    final text = body.trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final error = decoded['error'] ?? decoded['message'];
        if (error is String && error.trim().isNotEmpty) return error.trim();
        if (error is Map) {
          final nested = error['message'];
          if (nested is String && nested.trim().isNotEmpty) {
            return nested.trim();
          }
        }
      }
    } on FormatException {
      // Not JSON. An HTML error page is no use to anyone, so drop it.
      if (text.startsWith('<')) return null;
      return text.length > 200 ? null : text;
    }
    return null;
  }

  static bool _isZip(Uint8List bytes) => bytes[0] == 0x50 && bytes[1] == 0x4B;

  static bool _isPdf(Uint8List bytes) =>
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;

  static bool _looksLike(ConversionKind kind, Uint8List bytes) {
    if (bytes.length < 4) return false;
    return switch (kind) {
      // Word packages are zips.
      ConversionKind.pdfToWord => _isZip(bytes),
      // Several files come back zipped together.
      ConversionKind.split => _isPdf(bytes) || _isZip(bytes),
      _ => _isPdf(bytes),
    };
  }

  /// What a job actually returned, which for splitting is only known now.
  static String _extensionOf(ConversionKind kind, Uint8List bytes) =>
      kind.mayReturnZip && _isZip(bytes) ? 'zip' : kind.resultExtension;

  static String _mimeTypeFor(ConversionKind kind, Uint8List bytes) =>
      _extensionOf(kind, bytes) == 'zip'
      ? 'application/zip'
      : kind.resultMimeType;

  static String _ensureExtension(
    String candidate,
    ConversionKind kind,
    String sourceName,
    Uint8List bytes,
  ) {
    final extension = _extensionOf(kind, bytes);
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) return resultNameFor(sourceName, kind, extension);
    if (trimmed.toLowerCase().endsWith('.$extension')) return trimmed;
    return resultNameFor(trimmed, kind, extension);
  }

  static String _boundary() {
    final random = math.Random();
    final tail = List.generate(
      16,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    return '----scanella$tail';
  }

  static String _headerSafe(String name) =>
      name.replaceAll(RegExp(r'[\r\n"]'), '_');

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// `/api/ilove/start` under whatever prefix the host was given as.
  static Uri endpointFor(Uri base, String path) {
    final prefix = base.path.replaceAll(RegExp(r'/+$'), '');
    return base.replace(path: '$prefix$path', query: null, fragment: null);
  }

  /// What to call the result: the source name with the new extension.
  static String resultNameFor(
    String sourceName,
    ConversionKind kind, [
    String? extension,
  ]) {
    final base = sourceName
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'\.[^.]*$'), '')
        .trim();
    final name = base.isEmpty ? 'document' : base;
    return '$name.${extension ?? kind.resultExtension}';
  }

  static String mimeTypeFor(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    return switch (extension) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'odt' => 'application/vnd.oasis.opendocument.text',
      'rtf' => 'application/rtf',
      _ => 'application/octet-stream',
    };
  }
}

/// How long each step may take. Uploading and converting a long document is
/// slow on a phone connection, so these are generous.
class ConversionTimeouts {
  const ConversionTimeouts({
    this.connect = const Duration(seconds: 20),
    this.start = const Duration(seconds: 30),
    this.upload = const Duration(minutes: 5),
    this.process = const Duration(minutes: 10),
    this.download = const Duration(minutes: 5),
  });

  final Duration connect;
  final Duration start;
  final Duration upload;
  final Duration process;
  final Duration download;
}

class _ConversionJob {
  const _ConversionJob({
    required this.token,
    required this.server,
    required this.task,
    required this.tool,
    required this.uploadUrl,
    required this.resultFilename,
    this.direct = false,
  });

  final String token;
  final String server;
  final String task;
  final String tool;
  final Uri uploadUrl;

  /// What the backend says the finished file should be called, if it said.
  final String? resultFilename;

  /// True when start and process talk to the workers, not our own endpoints.
  final bool direct;
}

class _ReadyFile {
  const _ReadyFile({
    required this.url,
    required this.token,
    required this.filename,
  });

  final Uri url;
  final String token;
  final String filename;
}
