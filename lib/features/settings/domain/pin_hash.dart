import 'dart:convert';

import 'package:crypto/crypto.dart';

/// SHA-256 of the PIN, salted so a leaked prefs file is not a raw PIN list.
String hashPin(String pin) =>
    sha256.convert(utf8.encode('scanella|$pin')).toString();
