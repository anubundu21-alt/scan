import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/src/priv.dart';

/// PDF 1.4 Standard Security Handler, revision 3, 128-bit RC4.
///
/// The `pdf` package only ships the abstract [PdfEncryption] hook. This is a
/// real user-password handler so Preview / Adobe ask for the password.
class PdfStandardSecurity extends PdfEncryption {
  PdfStandardSecurity(PdfDocument pdfDocument, {required String userPassword})
    : super(pdfDocument) {
    final user = _padPassword(userPassword);
    final owner = user;
    final fileId = pdfDocument.documentID;
    _o = _computeO(owner, user);
    _key = _computeKey(user, _o, fileId, _permissions);
    _u = _computeU(_key, fileId);

    params['/Filter'] = const PdfName('/Standard');
    params['/V'] = const PdfNum(2);
    params['/R'] = const PdfNum(3);
    params['/Length'] = const PdfNum(128);
    params['/P'] = PdfNum(_permissions);
    params['/O'] = PdfString(
      _o,
      format: PdfStringFormat.binary,
      encrypted: false,
    );
    params['/U'] = PdfString(
      _u,
      format: PdfStringFormat.binary,
      encrypted: false,
    );
  }

  /// Print, copy, and modify allowed once the file is open.
  static const _permissions = -4;

  static final _padding = Uint8List.fromList(const [
    0x28,
    0xbf,
    0x4e,
    0x5e,
    0x4e,
    0x75,
    0x8a,
    0x41,
    0x64,
    0x00,
    0x4e,
    0x56,
    0xff,
    0xfa,
    0x01,
    0x08,
    0x2e,
    0x2e,
    0x00,
    0xb6,
    0xd0,
    0x68,
    0x3e,
    0x80,
    0x2f,
    0x0c,
    0xa9,
    0xfe,
    0x64,
    0x53,
    0x69,
    0x7a,
  ]);

  late final Uint8List _key;
  late final Uint8List _o;
  late final Uint8List _u;

  @override
  Uint8List encrypt(Uint8List input, PdfObjectBase object) {
    final seed = Uint8List(21);
    seed.setAll(0, _key);
    seed[16] = object.objser & 0xff;
    seed[17] = (object.objser >> 8) & 0xff;
    seed[18] = (object.objser >> 16) & 0xff;
    seed[19] = object.objgen & 0xff;
    seed[20] = (object.objgen >> 8) & 0xff;
    final hash = md5.convert(seed).bytes;
    final n = _key.length + 5;
    return _rc4(Uint8List.fromList(hash.sublist(0, n < 16 ? n : 16)), input);
  }

  static Uint8List _padPassword(String password) {
    final raw = password.codeUnits;
    final out = Uint8List(32);
    final take = raw.length < 32 ? raw.length : 32;
    for (var i = 0; i < take; i++) {
      out[i] = raw[i] & 0xff;
    }
    if (take < 32) {
      out.setRange(take, 32, _padding);
    }
    return out;
  }

  static Uint8List _computeO(Uint8List owner, Uint8List user) {
    var hash = md5.convert(owner).bytes;
    for (var i = 0; i < 50; i++) {
      hash = md5.convert(hash).bytes;
    }
    var key = Uint8List.fromList(hash.sublist(0, 16));
    var data = Uint8List.fromList(user);
    data = _rc4(key, data);
    for (var i = 1; i <= 19; i++) {
      data = _rc4(_xorKey(key, i), data);
    }
    return data;
  }

  static Uint8List _computeKey(
    Uint8List user,
    Uint8List o,
    Uint8List fileId,
    int permissions,
  ) {
    final input = <int>[
      ...user,
      ...o,
      permissions & 0xff,
      (permissions >> 8) & 0xff,
      (permissions >> 16) & 0xff,
      (permissions >> 24) & 0xff,
      ...fileId,
    ];
    var hash = md5.convert(input).bytes;
    for (var i = 0; i < 50; i++) {
      hash = md5.convert(hash.sublist(0, 16)).bytes;
    }
    return Uint8List.fromList(hash.sublist(0, 16));
  }

  static Uint8List _computeU(Uint8List key, Uint8List fileId) {
    final input = Uint8List(32 + fileId.length);
    input.setAll(0, _padding);
    input.setAll(32, fileId);
    var data = _rc4(key, input);
    for (var i = 1; i <= 19; i++) {
      data = _rc4(_xorKey(key, i), data);
    }
    final u = Uint8List(32);
    u.setAll(0, data.sublist(0, 16));
    return u;
  }

  static Uint8List _xorKey(Uint8List key, int value) {
    return Uint8List.fromList([for (final b in key) b ^ value]);
  }

  static Uint8List _rc4(Uint8List key, Uint8List data) {
    final s = List<int>.generate(256, (i) => i);
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + s[i] + key[i % key.length]) & 0xff;
      final t = s[i];
      s[i] = s[j];
      s[j] = t;
    }
    final out = Uint8List(data.length);
    var x = 0;
    var y = 0;
    for (var n = 0; n < data.length; n++) {
      x = (x + 1) & 0xff;
      y = (y + s[x]) & 0xff;
      final t = s[x];
      s[x] = s[y];
      s[y] = t;
      out[n] = data[n] ^ s[(s[x] + s[y]) & 0xff];
    }
    return out;
  }
}
