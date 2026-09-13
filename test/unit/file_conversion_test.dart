import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/export_service.dart';
import 'package:scan2/features/library/domain/pdf_export_options.dart';
import 'package:scan2/features/pro/domain/file_conversion.dart';

import '../support/scanned_docx.dart';

/// Stands in for both halves of the pipeline: our own start/process endpoints
/// and the conversion server the device uploads to and downloads from. Running
/// a real server on loopback means these tests check the bytes that actually
/// go on the wire — the multipart body, the bearer tokens, the order of the
/// four calls — rather than a mock's idea of them.
class _FakeBackend {
  _FakeBackend._(this._server);

  final HttpServer _server;

  /// What the device sent, in order.
  final List<String> calls = [];
  Map<String, dynamic>? startBody;
  Map<String, dynamic>? processBody;
  int startContentLength = 0;
  int processContentLength = 0;
  String? uploadAuthorization;
  String? downloadAuthorization;
  String? uploadedTask;
  String? uploadedFilename;
  String? uploadedContentType;
  Uint8List? uploadedBytes;
  final List<String> uploadedFilenames = [];
  final List<Uint8List> uploadedFiles = [];
  int _uploads = 0;

  /// Knobs for the unhappy paths.
  int processStatus = HttpStatus.ok;
  String? processError;
  String startEngine = 'ilovepdf';
  String? startReason;
  String? startToolOverride;
  Uint8List result = Uint8List.fromList(const [0x50, 0x4B, 0x03, 0x04]);
  String? resultFilename = 'Offer letter.docx';
  String? downloadToken = 'download-token';
  String downloadContentType = 'application/octet-stream';

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<_FakeBackend> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final backend = _FakeBackend._(server);
    server.listen(backend._handle);
    return backend;
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    calls.add('${request.method} $path');
    switch (path) {
      case '/api/ilove/start':
        startContentLength = request.contentLength;
        startBody = jsonDecode(await _text(request)) as Map<String, dynamic>;
        final kind = startBody!['kind'];
        final tool =
            startToolOverride ??
            switch (kind) {
              'compress' => 'compress',
              'merge' => 'merge',
              'split' => 'split',
              _ => 'the-tool',
            };
        _json(request.response, {
          'engine': startEngine,
          if (startReason != null) 'reason': startReason,
          'token': 'job-token',
          'server': '127.0.0.1',
          'task': 'task-1',
          'tool': tool,
          'uploadUrl': '$baseUrl/v1/upload',
          // The name for the finished file, not the one being sent.
          if (resultFilename != null) 'filename': resultFilename,
        });
      case '/v1/upload':
        uploadAuthorization = request.headers.value(
          HttpHeaders.authorizationHeader,
        );
        _readMultipart(request.headers.contentType!, await _bytes(request));
        _uploads += 1;
        if (uploadedFilename != null) uploadedFilenames.add(uploadedFilename!);
        if (uploadedBytes != null) uploadedFiles.add(uploadedBytes!);
        // The first name is the one older tests already pin; later files in
        // a merge get their own so the process body can be checked in order.
        _json(request.response, {
          'server_filename': _uploads == 1 ? 'abc123.pdf' : 'file$_uploads.pdf',
        });
      case '/api/ilove/process':
        processContentLength = request.contentLength;
        processBody = jsonDecode(await _text(request)) as Map<String, dynamic>;
        if (processStatus != HttpStatus.ok) {
          request.response.statusCode = processStatus;
          _json(request.response, {'error': processError});
          return;
        }
        _json(request.response, {
          'engine': 'ilovepdf',
          'downloadUrl': '$baseUrl/v1/download/task-1',
          if (downloadToken != null) 'token': downloadToken,
          if (resultFilename != null) 'filename': resultFilename,
        });
      case '/v1/download/task-1':
      case '/v1/download/task-direct':
        downloadAuthorization = request.headers.value(
          HttpHeaders.authorizationHeader,
        );
        request.response.headers.contentType = ContentType.parse(
          downloadContentType,
        );
        request.response.add(result);
        await request.response.close();
      case '/compress_pdf':
      case '/merge_pdf':
      case '/split_pdf':
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          'var ilovepdfConfig = {"token":'
          '"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0In0.sig"};',
        );
        await request.response.close();
      case '/v1/start/compress':
      case '/v1/start/merge':
      case '/v1/start/split':
        _json(request.response, {'server': '127.0.0.1', 'task': 'task-direct'});
      case '/v1/process':
        processBody = jsonDecode(await _text(request)) as Map<String, dynamic>;
        _json(request.response, {
          'download_filename': resultFilename ?? 'out.pdf',
          'output_extensions': '["pdf"]',
          'status': 'TaskSuccess',
        });
      default:
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
    }
  }

  void _readMultipart(ContentType type, Uint8List body) {
    final boundary = type.parameters['boundary']!;
    // latin1 keeps every byte as it was, so the file part survives the round
    // trip through a String.
    for (final part in latin1.decode(body).split('--$boundary')) {
      final headerEnd = part.indexOf('\r\n\r\n');
      if (headerEnd < 0) continue;
      final headers = part.substring(0, headerEnd);
      var value = part.substring(headerEnd + 4);
      if (value.endsWith('\r\n')) {
        value = value.substring(0, value.length - 2);
      }
      if (headers.contains('name="task"')) {
        uploadedTask = value;
      } else if (headers.contains('name="file"')) {
        uploadedBytes = Uint8List.fromList(latin1.encode(value));
        uploadedFilename = RegExp(
          'filename="([^"]*)"',
        ).firstMatch(headers)?.group(1);
        uploadedContentType = RegExp(
          r'Content-Type: (.*)',
        ).firstMatch(headers)?.group(1)?.trim();
      }
    }
  }

  static Future<String> _text(HttpRequest request) async =>
      utf8.decode(await _bytes(request));

  static Future<Uint8List> _bytes(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static void _json(HttpResponse response, Map<String, Object?> body) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    response.close();
  }
}

class _FakeExporter implements ExportService {
  _FakeExporter(this.bytes);

  final Uint8List bytes;
  Document? seen;

  @override
  Future<Uint8List> buildPdfBytes(
    Document document, {
    PdfExportOptions options = const PdfExportOptions(),
  }) async {
    seen = document;
    return bytes;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Document _document({String title = 'Offer letter', int pages = 2}) => Document(
  id: 1,
  title: title,
  createdAt: DateTime(2026, 1, 1),
  pages: [for (var i = 0; i < pages; i++) ScanPage(path: '/tmp/page$i.jpg')],
);

void main() {
  late _FakeBackend backend;
  late FileConverter converter;

  setUp(() async {
    ConversionService.clearSessionCache();
    backend = await _FakeBackend.start();
    converter = FileConverter(
      service: ConversionService(baseUrl: backend.baseUrl),
    );
  });

  tearDown(() => backend.stop());

  final pdf = Uint8List.fromList('%PDF-1.7 a real enough file'.codeUnits);

  test('a PDF goes up, converts, and comes back as a Word file', () async {
    final result = await converter.convertFile(
      pdf,
      sourceName: 'Offer letter.pdf',
      kind: ConversionKind.pdfToWord,
    );

    expect(backend.calls, [
      'POST /api/ilove/start',
      'POST /v1/upload',
      'POST /api/ilove/process',
      'GET /v1/download/task-1',
    ]);
    expect(backend.startBody, {
      'kind': 'pdf-to-word',
      'filename': 'Offer letter.pdf',
    });
    expect(backend.uploadAuthorization, 'Bearer job-token');
    expect(backend.uploadedTask, 'task-1');
    expect(backend.uploadedBytes, pdf);
    // The upload and the process call carry the name of the file being sent,
    // not the name the result will be given. The converter writes that name
    // into the document, so getting it the wrong way round is visible.
    expect(backend.uploadedFilename, 'Offer letter.pdf');
    expect(backend.uploadedContentType, 'application/pdf');
    expect(backend.processBody, {
      'kind': 'pdf-to-word',
      'token': 'job-token',
      'server': '127.0.0.1',
      'task': 'task-1',
      'tool': 'the-tool',
      'files': [
        {'serverFilename': 'abc123.pdf', 'filename': 'Offer letter.pdf'},
      ],
      // Still sent on its own so a backend from before merging understands it.
      'serverFilename': 'abc123.pdf',
      'filename': 'Offer letter.pdf',
    });
    // Downloading uses the token the process step handed back.
    expect(backend.downloadAuthorization, 'Bearer download-token');
    expect(result.filename, 'Offer letter.docx');
    expect(result.bytes, backend.result);
    expect(result.mimeType, contains('wordprocessingml'));
  });

  // The whole point of the four-step flow: our own endpoints are told about
  // the job, never handed the document. If this ever regresses, every
  // conversion starts paying for the same bytes twice and our server starts
  // holding files it promised not to.
  test('the file itself never passes through our own endpoints', () async {
    await converter.convertFile(
      pdf,
      sourceName: 'Offer letter.pdf',
      kind: ConversionKind.pdfToWord,
    );

    expect(backend.startContentLength, lessThan(pdf.length));
    expect(backend.processContentLength, lessThan(pdf.length));
  });

  test(
    'progress runs from uploading through converting to downloading',
    () async {
      final stages = <ConversionStage>[];
      final fractions = <double?>[];

      await converter.convertFile(
        pdf,
        sourceName: 'a.pdf',
        kind: ConversionKind.pdfToWord,
        onProgress: (status) {
          stages.add(status.stage);
          fractions.add(status.fraction);
        },
      );

      expect(stages.first, ConversionStage.starting);
      expect(stages, contains(ConversionStage.uploading));
      expect(stages, contains(ConversionStage.converting));
      expect(stages, contains(ConversionStage.downloading));
      expect(stages.last, ConversionStage.done);
      expect(
        stages.indexOf(ConversionStage.uploading),
        lessThan(stages.indexOf(ConversionStage.converting)),
      );
      // Converting happens on the service with nothing to report, so the bar is
      // left indeterminate rather than made up.
      expect(fractions[stages.indexOf(ConversionStage.converting)], isNull);
      expect(fractions.last, 1);
    },
  );

  test('Word to PDF asks for the other conversion and gets a PDF back', () async {
    backend.result = Uint8List.fromList('%PDF-1.7 converted'.codeUnits);
    // A backend that names nothing leaves the app to work the name out.
    backend.resultFilename = null;
    final docx = Uint8List.fromList(const [0x50, 0x4B, 0x03, 0x04, 0x09]);

    final result = await converter.convertFile(
      docx,
      sourceName: 'Contract.docx',
      kind: ConversionKind.wordToPdf,
    );

    expect(backend.startBody!['kind'], 'word-to-pdf');
    expect(
      backend.uploadedContentType,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(result.filename, 'Contract.pdf');
    expect(result.mimeType, 'application/pdf');
  });

  // A book came back from TestFlight with its colour cover intact and every
  // scanned page after it solid black.
  test(
    'scanned pages come back drawable, not as pages that read black',
    () async {
      backend.result = docxWith({
        'word/media/image1.png': indexedPageWithBlackBackground(),
        'word/media/image2.png': indexedPageWithBlackBackground(),
      });

      final converted = await converter.convertFile(
        pdf,
        sourceName: 'Book.pdf',
        kind: ConversionKind.pdfToWord,
      );

      final pages = pageFactsIn(converted.bytes);
      expect(pages, hasLength(2));
      for (final page in pages) {
        expect(page.isIndexed, isFalse);
        expect(page.hasBackground, isFalse);
      }
    },
  );

  test('a Word file going the other way is never rewritten', () async {
    backend.result = Uint8List.fromList('%PDF-1.7 converted'.codeUnits);
    final docx = Uint8List.fromList(const [0x50, 0x4B, 0x03, 0x04, 0x09]);

    final converted = await converter.convertFile(
      docx,
      sourceName: 'Contract.docx',
      kind: ConversionKind.wordToPdf,
    );

    expect(converted.bytes, backend.result);
  });

  test('the job token still works when no download token comes back', () async {
    backend.downloadToken = null;

    await converter.convertFile(
      pdf,
      sourceName: 'a.pdf',
      kind: ConversionKind.pdfToWord,
    );

    expect(backend.downloadAuthorization, 'Bearer job-token');
  });

  // The backend answers with the engine it opened the job on. The web app can
  // fall back to converting in the browser when that is not the remote one;
  // there is no such fallback on a phone, so the reason has to be shown.
  test('a backend that could not open a job says why', () async {
    backend.startEngine = 'browser';
    backend.startReason = 'The converter is down for maintenance.';

    await expectLater(
      () => converter.convertFile(
        pdf,
        sourceName: 'a.pdf',
        kind: ConversionKind.pdfToWord,
      ),
      throwsA(
        isA<ConversionFailure>().having(
          (e) => e.message,
          'message',
          'The converter is down for maintenance.',
        ),
      ),
    );
    // It gave up before sending anything.
    expect(backend.calls, ['POST /api/ilove/start']);
  });

  test('a library PDF is rebuilt, then sent like any other file', () async {
    final built = Uint8List.fromList('%PDF-1.7 built here'.codeUnits);
    final exporter = _FakeExporter(built);
    final document = _document();
    final withExporter = FileConverter(
      service: ConversionService(baseUrl: backend.baseUrl),
      exporter: exporter,
    );

    final result = await withExporter.convertDocument(document);

    expect(exporter.seen, document);
    expect(backend.uploadedBytes, built);
    expect(result.filename, 'Offer letter.docx');
  });

  test('a document with no pages never reaches the network', () async {
    final exporter = _FakeExporter(Uint8List(0));
    final withExporter = FileConverter(
      service: ConversionService(baseUrl: backend.baseUrl),
      exporter: exporter,
    );

    await expectLater(
      () => withExporter.convertDocument(_document(pages: 0)),
      throwsA(isA<ConversionFailure>()),
    );
    expect(exporter.seen, isNull);
    expect(backend.calls, isEmpty);
  });

  test('an empty file is refused before anything is uploaded', () async {
    await expectLater(
      () => converter.convertFile(
        Uint8List(0),
        sourceName: 'a.pdf',
        kind: ConversionKind.pdfToWord,
      ),
      throwsA(isA<ConversionFailure>()),
    );
    expect(backend.calls, isEmpty);
  });

  test('a locked file is named as locked, not as a failure', () async {
    backend.processStatus = HttpStatus.badRequest;
    backend.processError = 'File has a password and none was given';

    await expectLater(
      () => converter.convertFile(
        pdf,
        sourceName: 'a.pdf',
        kind: ConversionKind.pdfToWord,
      ),
      throwsA(
        isA<ConversionFailure>()
            .having((e) => e.code, 'code', 'password')
            .having(
              (e) => e.message,
              'message',
              contains('password-protected'),
            ),
      ),
    );
  });

  test('the service saying why it failed is what the customer reads', () async {
    backend.processStatus = HttpStatus.badGateway;
    backend.processError = 'That tool is not on this plan';

    await expectLater(
      () => converter.convertFile(
        pdf,
        sourceName: 'a.pdf',
        kind: ConversionKind.pdfToWord,
      ),
      throwsA(
        isA<ConversionFailure>().having(
          (e) => e.message,
          'message',
          'That tool is not on this plan',
        ),
      ),
    );
  });

  // A converter that falls over late can still answer 200, with an error page
  // where the document should be. Saving that as a .docx would hand someone a
  // file Word refuses to open.
  test('an error page is not handed over as a Word file', () async {
    backend.result = Uint8List.fromList('<html>no</html>'.codeUnits);

    await expectLater(
      () => converter.convertFile(
        pdf,
        sourceName: 'a.pdf',
        kind: ConversionKind.pdfToWord,
      ),
      throwsA(isA<ConversionFailure>()),
    );
  });

  // Shipping 808 with the host left to a CI variable nobody had set is how
  // both converters reached TestFlight switched off.
  test('a build nobody configured still has somewhere to send a file', () {
    final plain = FileConverter(service: ConversionService());

    expect(plain.isConfigured, isTrue);
    expect(ConversionService.defaultBaseUrl!.scheme, 'https');
    expect(ConversionService.defaultBaseUrl!.host, isNotEmpty);
  });

  test('a build with no converter host says so up front', () async {
    final unconfigured = FileConverter(
      service: const ConversionService.withoutHost(),
    );

    expect(unconfigured.isConfigured, isFalse);
    await expectLater(
      () => unconfigured.convertFile(
        pdf,
        sourceName: 'a.pdf',
        kind: ConversionKind.pdfToWord,
      ),
      throwsA(
        isA<ConversionFailure>().having((e) => e.code, 'code', 'unconfigured'),
      ),
    );
  });

  test('a host given with a path keeps that path', () {
    expect(
      ConversionService.endpointFor(
        Uri.parse('https://example.com/tools/'),
        '/api/ilove/start',
      ).toString(),
      'https://example.com/tools/api/ilove/start',
    );
  });

  test('compressing sends the chosen level and comes back as a PDF', () async {
    backend.result = Uint8List.fromList('%PDF-1.7 smaller'.codeUnits);
    backend.resultFilename = 'Report-compressed.pdf';

    final result = await converter.convertFile(
      pdf,
      sourceName: 'Report.pdf',
      kind: ConversionKind.compress,
      options: const ConversionOptions(compression: CompressionLevel.hard),
    );

    expect(backend.startBody!['kind'], 'compress');
    expect(backend.processBody!['kind'], 'compress');
    expect(backend.processBody!['options'], {'compressionLevel': 'extreme'});
    expect(result.bytes, backend.result);
    expect(result.bytes.sublist(0, 5), '%PDF-'.codeUnits);
    expect(result.filename, 'Report-compressed.pdf');
    expect(result.mimeType, 'application/pdf');
    expect(backend.calls, [
      'POST /api/ilove/start',
      'POST /v1/upload',
      'POST /api/ilove/process',
      'GET /v1/download/task-1',
    ]);
    expect(backend.startContentLength, lessThan(pdf.length));
    expect(backend.processContentLength, lessThan(pdf.length));
  });

  test('compressing says so while the service is working', () async {
    backend.result = Uint8List.fromList('%PDF-1.7 smaller'.codeUnits);
    String? converting;

    await converter.convertFile(
      pdf,
      sourceName: 'a.pdf',
      kind: ConversionKind.compress,
      onProgress: (status) {
        if (status.stage == ConversionStage.converting) {
          converting = status.message;
        }
      },
    );

    expect(converting, 'Compressing…');
  });

  test('merging uploads every file in the order they were given', () async {
    backend.result = Uint8List.fromList('%PDF-1.7 merged'.codeUnits);
    backend.resultFilename = 'Cover-merged.pdf';
    final cover = Uint8List.fromList('%PDF-1.7 cover'.codeUnits);
    final body = Uint8List.fromList('%PDF-1.7 body pages'.codeUnits);

    final result = await converter.convertFiles([
      ConversionSource(bytes: cover, filename: 'Cover.pdf'),
      ConversionSource(bytes: body, filename: 'Body.pdf'),
    ], kind: ConversionKind.merge);

    expect(backend.startBody!['kind'], 'merge');
    expect(backend.calls, [
      'POST /api/ilove/start',
      'POST /v1/upload',
      'POST /v1/upload',
      'POST /api/ilove/process',
      'GET /v1/download/task-1',
    ]);
    expect(backend.uploadedFilenames, ['Cover.pdf', 'Body.pdf']);
    expect(backend.uploadedFiles, [cover, body]);
    expect(backend.processBody!['files'], [
      {'serverFilename': 'abc123.pdf', 'filename': 'Cover.pdf'},
      {'serverFilename': 'file2.pdf', 'filename': 'Body.pdf'},
    ]);
    expect(result.bytes.sublist(0, 5), '%PDF-'.codeUnits);
    expect(result.filename, 'Cover-merged.pdf');
    expect(result.mimeType, 'application/pdf');
  });

  test('splitting by ranges asks for one PDF back', () async {
    backend.result = Uint8List.fromList('%PDF-1.7 pages 1-3 and 8'.codeUnits);
    backend.resultFilename = 'Report-split.pdf';

    final result = await converter.convertFile(
      pdf,
      sourceName: 'Report.pdf',
      kind: ConversionKind.split,
      options: const ConversionOptions(ranges: '1-3, 8'),
    );

    expect(backend.startBody!['kind'], 'split');
    expect(backend.processBody!['options'], {
      'ranges': '1-3, 8',
      'mergeAfter': true,
    });
    expect(result.bytes.sublist(0, 5), '%PDF-'.codeUnits);
    expect(result.filename, 'Report-split.pdf');
    expect(result.mimeType, 'application/pdf');
  });

  test('splitting every N pages accepts a zip of them', () async {
    backend.result = Uint8List.fromList(const [0x50, 0x4B, 0x03, 0x04, 0x14]);
    backend.resultFilename = 'Report-split.zip';

    final result = await converter.convertFile(
      pdf,
      sourceName: 'Report.pdf',
      kind: ConversionKind.split,
      options: const ConversionOptions(everyPages: 2),
    );

    expect(backend.processBody!['options'], {'everyPages': 2});
    expect(result.bytes[0], 0x50);
    expect(result.bytes[1], 0x4B);
    expect(result.filename, 'Report-split.zip');
    expect(result.mimeType, 'application/zip');
  });

  test('a split that comes back as a zip is named as a zip', () async {
    backend.result = Uint8List.fromList(const [0x50, 0x4B, 0x03, 0x04]);
    // The start step guessed a PDF name; the bytes say otherwise.
    backend.resultFilename = 'Report-split.pdf';

    final result = await converter.convertFile(
      pdf,
      sourceName: 'Report.pdf',
      kind: ConversionKind.split,
      options: const ConversionOptions(everyPages: 1),
    );

    expect(result.filename, 'Report-split.zip');
    expect(result.mimeType, 'application/zip');
  });

  test('an HTML page is not handed over as a compressed PDF', () async {
    backend.result = Uint8List.fromList('<html>no</html>'.codeUnits);

    await expectLater(
      () => converter.convertFile(
        pdf,
        sourceName: 'a.pdf',
        kind: ConversionKind.compress,
      ),
      throwsA(isA<ConversionFailure>()),
    );
  });

  test('a host that opens a Word job for compress is not followed', () async {
    backend.startToolOverride = 'pdfoffice';
    backend.result = Uint8List.fromList('%PDF-1.7 smaller'.codeUnits);
    backend.resultFilename = 'Report-compressed.pdf';
    final withFallback = FileConverter(
      service: ConversionService(
        baseUrl: backend.baseUrl,
        websiteOrigin: backend.baseUrl,
        apiOrigin: backend.baseUrl,
      ),
    );

    final result = await withFallback.convertFile(
      pdf,
      sourceName: 'Report.pdf',
      kind: ConversionKind.compress,
      options: const ConversionOptions(compression: CompressionLevel.hard),
    );

    expect(backend.calls, contains('GET /compress_pdf'));
    expect(backend.calls, contains('GET /v1/start/compress'));
    expect(backend.calls, contains('POST /v1/process'));
    expect(backend.calls, isNot(contains('POST /api/ilove/process')));
    expect(backend.processBody!['tool'], 'compress');
    expect(backend.processBody!['compression_level'], 'extreme');
    expect(result.bytes.sublist(0, 5), '%PDF-'.codeUnits);
    expect(result.filename, 'Report-compressed.pdf');
  });

  test('a tool page token is read out of the inline config', () {
    expect(
      ConversionService.parseToolPageToken(
        'var ilovepdfConfig = {"token":"abc.def.ghi", "foo": 1};',
      ),
      'abc.def.ghi',
    );
    expect(ConversionService.parseToolPageToken('<html>no</html>'), isNull);
  });

  test('a nameless source still gets a sensible name', () {
    expect(
      ConversionService.resultNameFor('', ConversionKind.pdfToWord),
      'document.docx',
    );
    expect(
      ConversionService.resultNameFor(
        '/tmp/Some report.PDF',
        ConversionKind.pdfToWord,
      ),
      'Some report.docx',
    );
  });

  test('failures read as one line someone can act on', () {
    expect(
      readableConversionError(
        const ConversionFailure('password', 'whatever the service said'),
      ),
      'That file is password-protected. Unlock it first, then convert it.',
    );
    expect(
      readableConversionError(const SocketException('no route')),
      contains('Check your connection'),
    );
    expect(
      readableConversionError(StateError('That PDF could not be read.')),
      'That PDF could not be read.',
    );
  });
}
