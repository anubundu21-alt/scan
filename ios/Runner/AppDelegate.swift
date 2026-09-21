import Flutter
import PDFKit
import Security
import StoreKit
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScanellaOcr")!
    ScanellaOcrPlugin.register(with: registrar)
    let quotaRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScanellaQuota")!
    ScanellaQuotaPlugin.register(with: quotaRegistrar)
    let pdfRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScanellaPdf")!
    ScanellaPdfPlugin.register(with: pdfRegistrar)
    let proRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScanellaPro")!
    ScanellaProPlugin.register(with: proRegistrar)
  }
}

/// Whether this Apple ID is subscribed, and a copy that outlives an uninstall.
///
/// `currentEntitlement` asks StoreKit 2, which answers from the device without
/// a password prompt and reports a lapsed or refunded subscription as gone. It
/// needs iOS 15; below that it returns nil, meaning "unknown", and Dart falls
/// back to the cached answer plus the Restore button. The deployment target
/// stays where it is either way.
///
/// `readPro` / `writePro` keep that cached answer in the Keychain, which an
/// uninstall does not clear, so a subscriber who reinstalls is not shown a
/// paywall while the store is being asked.
///
/// `trialConsumed` answers the separate question of whether this Apple ID has
/// already had the introductory month. On iOS 15 it reads StoreKit's own
/// purchase history, which is authoritative and survives an uninstall; below
/// that it falls back to the Keychain flag `markTrialUsed` writes. Getting
/// this wrong offers a free month Apple will refuse to grant, so both sources
/// are ORed and neither can clear the other.
private enum ScanellaProPlugin {
  static let service = "com.scanella.mobile.pro"
  static let account = "entitled_v1"
  static let untilAccount = "entitled_until_v1"
  static let basisAccount = "entitled_basis_v1"
  static let trialAccount = "trial_used_v1"
  static let productIds: Set<String> = [
    "scanella_pro_monthly", "scanella_pro_yearly",
  ]

  /// Three days, matching the slack the Dart side uses.
  static let graceSeconds: TimeInterval = 3 * 24 * 60 * 60

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "scanella/pro",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "currentEntitlement":
        if #available(iOS 15.0, *) {
          Task {
            let live = await currentEntitlement()
            // StoreKit 2 knows exactly when this period runs out. Writing
            // that down keeps the cached answer honest for the one launch
            // where the store cannot be reached at all.
            writePro(live.entitled, untilMs: live.untilMs, basisMs: nil)
            DispatchQueue.main.async { result(live.entitled) }
          }
        } else {
          result(nil)
        }
      case "introEligible":
        if #available(iOS 15.0, *) {
          Task {
            let ok = await introOfferAvailable()
            DispatchQueue.main.async { result(ok) }
          }
        } else {
          result(nil)
        }
      case "trialConsumed":
        if #available(iOS 15.0, *) {
          Task {
            let fromStore = await hasPastPurchase()
            let used = fromStore || readFlag(trialAccount)
            DispatchQueue.main.async { result(used) }
          }
        } else {
          result(readFlag(trialAccount))
        }
      case "markTrialUsed":
        writeFlag(true, account: trialAccount)
        result(nil)
      case "clearTrialUsed":
        // Testing tools only. Apple still decides who is owed the
        // introductory month; this only clears what the app remembers.
        writeFlag(false, account: trialAccount)
        result(nil)
      case "readPro":
        result(readPro())
      case "readProStamp":
        result([
          "untilMs": readUntil().map { $0.timeIntervalSince1970 * 1000 },
          "basisMs": readMillis(basisAccount),
        ] as [String: Any?])
      case "writePro":
        // Either a bare Bool, or a map carrying the date the cached yes
        // stops being worth trusting.
        if let entitled = call.arguments as? Bool {
          writePro(entitled, untilMs: nil, basisMs: nil)
          result(nil)
          return
        }
        guard let args = call.arguments as? [String: Any],
              let entitled = args["entitled"] as? Bool
        else {
          result(
            FlutterError(
              code: "bad_args",
              message: "entitled is required",
              details: nil
            )
          )
          return
        }
        writePro(
          entitled,
          untilMs: (args["untilMs"] as? NSNumber)?.doubleValue,
          basisMs: (args["basisMs"] as? NSNumber)?.doubleValue
        )
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// A live subscription, and when its current period ends.
  ///
  /// Apple keeps serving while it retries a failed payment, so the date
  /// carries a few days' slack: noticing a lapse late is cheaper than
  /// locking out someone who is paying.
  @available(iOS 15.0, *)
  static func currentEntitlement() async -> (entitled: Bool, untilMs: Double?) {
    var latest: Date?
    var found = false
    for await entry in Transaction.currentEntitlements {
      guard case .verified(let transaction) = entry else { continue }
      guard productIds.contains(transaction.productID) else { continue }
      if transaction.revocationDate != nil { continue }
      if let expiry = transaction.expirationDate, expiry <= Date() { continue }
      found = true
      guard let expiry = transaction.expirationDate else { continue }
      if latest == nil || expiry > latest! { latest = expiry }
    }
    guard found else { return (false, nil) }
    guard let latest = latest else { return (true, nil) }
    let withGrace = latest.addingTimeInterval(graceSeconds)
    return (true, withGrace.timeIntervalSince1970 * 1000)
  }

  /// Whether Apple would actually grant the introductory month right now.
  ///
  /// Two things have to be true and only the store knows either: an
  /// introductory offer has to be configured in App Store Connect, and this
  /// Apple ID has to still be owed one. Someone who started the month and
  /// cancelled has already had it, so Apple says no and the app must not
  /// promise it. If no offer is configured at all, this is false and the
  /// app offers the plain plan instead of advertising a month that would
  /// bill immediately.
  @available(iOS 15.0, *)
  static func introOfferAvailable() async -> Bool {
    do {
      let products = try await Product.products(for: Array(productIds))
      for product in products {
        guard let subscription = product.subscription else { continue }
        guard subscription.introductoryOffer != nil else { continue }
        if await subscription.isEligibleForIntroOffer { return true }
      }
    } catch {
      return false
    }
    return false
  }

  /// Any transaction at all on a Scanella Pro product, current or lapsed.
  ///
  /// Apple grants the introductory month once per subscription group, so a
  /// single past transaction — even a trial that was cancelled and has since
  /// expired — means there is no free month left to offer.
  @available(iOS 15.0, *)
  static func hasPastPurchase() async -> Bool {
    for await entry in Transaction.all {
      guard case .verified(let transaction) = entry else { continue }
      if productIds.contains(transaction.productID) { return true }
    }
    return false
  }

  /// The cached yes, but only while it is still plausible.
  ///
  /// Below iOS 15 there is no silent way to notice that a subscription
  /// lapsed, and the Keychain outlives an uninstall, so an unqualified yes
  /// would keep a cancelled trial on Pro forever. A purchase made in this
  /// app stamps the date its period runs out; once that passes, the cached
  /// answer is thrown away and the customer is a free user again with the
  /// Restore button there to correct us.
  static func readPro() -> Bool {
    guard readFlag(account) else { return false }
    guard let until = readUntil() else { return true }
    if until > Date() { return true }
    writePro(false, untilMs: nil, basisMs: nil)
    return false
  }

  static func writePro(_ entitled: Bool, untilMs: Double?, basisMs: Double?) {
    writeFlag(entitled, account: account)
    if !entitled {
      clear(account: untilAccount)
      clear(account: basisAccount)
      return
    }
    // A yes with no date attached leaves any date already stored alone:
    // StoreKit 2 refreshes the flag on every launch and knows nothing about
    // our stamp, and it must not quietly turn the stamp off.
    guard let untilMs = untilMs else { return }
    writeText(String(untilMs), account: untilAccount)
    if let basisMs = basisMs {
      writeText(String(basisMs), account: basisAccount)
    } else {
      clear(account: basisAccount)
    }
  }

  static func readUntil() -> Date? {
    guard let ms = readMillis(untilAccount) else { return nil }
    return Date(timeIntervalSince1970: ms / 1000)
  }

  static func readMillis(_ account: String) -> Double? {
    guard let text = readText(account) else { return nil }
    return Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  static func readFlag(_ account: String) -> Bool {
    guard let text = readText(account) else { return false }
    return text.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
  }

  static func writeFlag(_ on: Bool, account: String) {
    writeText(on ? "1" : "0", account: account)
  }

  static func readText(_ account: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess,
          let data = item as? Data
    else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  static func writeText(_ text: String, account: String) {
    let data = text.data(using: .utf8)!
    var add = baseQuery(account)
    SecItemDelete(baseQuery(account) as CFDictionary)
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(add as CFDictionary, nil)
  }

  static func clear(account: String) {
    SecItemDelete(baseQuery(account) as CFDictionary)
  }

  static func baseQuery(_ account: String) -> [String: Any] {
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}

/// Used-scan count that survives uninstall on this iPhone.
private enum ScanellaQuotaPlugin {
  static let service = "com.scanella.mobile.quota"
  static let account = "used_v1"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "scanella/quota",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "readUsed":
        result(readUsed())
      case "writeUsed":
        let value: Int?
        if let n = call.arguments as? Int {
          value = n
        } else if let n = call.arguments as? NSNumber {
          value = n.intValue
        } else {
          value = nil
        }
        guard let used = value else {
          result(
            FlutterError(
              code: "bad_args",
              message: "used is required",
              details: nil
            )
          )
          return
        }
        writeUsed(used)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func readUsed() -> Int {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess,
          let data = item as? Data,
          let text = String(data: data, encoding: .utf8),
          let n = Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    else {
      return 0
    }
    return n
  }

  static func writeUsed(_ used: Int) {
    let data = String(used).data(using: .utf8)!
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
    var add = query
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(add as CFDictionary, nil)
  }
}

private enum ScanellaOcrPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "scanella/ocr",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let data: Data?
      var language: String?
      if let map = call.arguments as? [String: Any] {
        if let typed = map["bytes"] as? FlutterStandardTypedData {
          data = typed.data
        } else {
          data = map["bytes"] as? Data
        }
        language = map["language"] as? String
      } else if let typed = call.arguments as? FlutterStandardTypedData {
        data = typed.data
      } else {
        data = call.arguments as? Data
      }
      guard let imageData = data else {
        result(
          FlutterError(
            code: "bad_image",
            message: "Could not read that image.",
            details: nil
          )
        )
        return
      }
      recognize(data: imageData, language: language, result: result)
    }
  }

  static func recognize(
    data: Data,
    language: String?,
    result: @escaping FlutterResult
  ) {
    let request = VNRecognizeTextRequest { request, error in
      if let error = error {
        result(
          FlutterError(
            code: "ocr_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }
      let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
      var lines: [String] = []
      var blocks: [[String: Any]] = []
      for observation in observations {
        guard let candidate = observation.topCandidates(1).first else { continue }
        lines.append(candidate.string)
        let box = observation.boundingBox
        // Vision origin is bottom-left; the app paints from the top-left.
        blocks.append([
          "text": candidate.string,
          "l": box.origin.x,
          "t": 1 - box.origin.y - box.height,
          "w": box.width,
          "h": box.height,
        ])
      }
      result([
        "text": lines.joined(separator: "\n"),
        "blocks": blocks,
      ])
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    if let language, !language.isEmpty {
      request.recognitionLanguages = [language]
    }
    let handler = VNImageRequestHandler(data: data, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        result(
          FlutterError(
            code: "ocr_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }
}

/// PDF Palette's convert path: read the PDF text layer first, and only
/// render a page image when that layer is missing (scanned / image PDF).
private enum ScanellaPdfPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "scanella/pdf",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "extract":
        guard let data = bytes(from: call.arguments) else {
          result(
            FlutterError(
              code: "bad_pdf",
              message: "That PDF could not be read.",
              details: nil
            )
          )
          return
        }
        extract(data: data, result: result)
      case "renderPage":
        let map = call.arguments as? [String: Any]
        guard let data = bytes(from: map),
              let index = intValue(map?["index"]),
              let dpi = intValue(map?["dpi"])
        else {
          result(
            FlutterError(
              code: "bad_pdf",
              message: "That PDF could not be read.",
              details: nil
            )
          )
          return
        }
        renderPage(data: data, index: index, dpi: dpi, result: result)
      case "unlock":
        let map = call.arguments as? [String: Any]
        guard let data = bytes(from: map) else {
          result(
            FlutterError(
              code: "bad_pdf",
              message: "That PDF could not be read.",
              details: nil
            )
          )
          return
        }
        let password = map?["password"] as? String ?? ""
        unlock(data: data, password: password, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func bytes(from arguments: Any?) -> Data? {
    if let map = arguments as? [String: Any] {
      if let typed = map["bytes"] as? FlutterStandardTypedData {
        return typed.data
      }
      return map["bytes"] as? Data
    }
    if let typed = arguments as? FlutterStandardTypedData {
      return typed.data
    }
    return arguments as? Data
  }

  static func intValue(_ raw: Any?) -> Int? {
    if let n = raw as? Int { return n }
    if let n = raw as? NSNumber { return n.intValue }
    return nil
  }

  static func extract(data: Data, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let document = PDFDocument(data: data) else {
        finish(
          result,
          FlutterError(
            code: "bad_pdf",
            message: "That PDF could not be read.",
            details: nil
          )
        )
        return
      }
      if document.isLocked {
        finish(
          result,
          FlutterError(
            code: "encrypted",
            message: "That PDF is password-protected. Unlock it first.",
            details: nil
          )
        )
        return
      }
      var pages: [[String: Any]] = []
      for i in 0..<document.pageCount {
        guard let page = document.page(at: i) else { continue }
        let size = displaySize(page)
        let text = (page.string ?? "")
          .replacingOccurrences(of: "\r\n", with: "\n")
          .replacingOccurrences(of: "\r", with: "\n")
        var entry: [String: Any] = [
          "text": text,
          "widthPt": Double(size.width),
          "heightPt": Double(size.height),
        ]
        // A rotated page would need every box rotated with it; let those
        // fall through to the page-image path instead of landing wrong.
        if page.rotation % 360 == 0 {
          let box = page.bounds(for: .mediaBox)
          entry["runs"] = textRuns(page, box: box)
          let content = vectorContent(page, box: box)
          entry["rects"] = content.rects
          entry["images"] = pageImages(
            page,
            box: box,
            rects: content.imageRects,
            hasText: !(entry["runs"] as? [[String: Any]] ?? []).isEmpty
          )
        }
        pages.append(entry)
      }
      finish(result, pages)
    }
  }

  /// Text as the PDF drew it: one entry per run that shares a font,
  /// size and colour on a line, with the box it occupies. This is what
  /// keeps columns, headings and alignment in the Word file.
  static func textRuns(_ page: PDFPage, box: CGRect) -> [[String: Any]] {
    guard let content = page.string, !content.isEmpty else { return [] }
    let characters = content as NSString
    let attributed = page.attributedString
    let count = min(page.numberOfCharacters, characters.length)
    guard count > 0 else { return [] }

    var runs: [[String: Any]] = []
    var runText = ""
    var runRect = CGRect.null
    var runFont: UIFont?
    var runColor = "000000"

    func flush() {
      defer {
        runText = ""
        runRect = .null
        runFont = nil
        runColor = "000000"
      }
      let trimmed = runText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, !runRect.isNull, !runRect.isInfinite else {
        return
      }
      let size = runFont?.pointSize ?? max(6, runRect.height * 0.82)
      let traits = runFont?.fontDescriptor.symbolicTraits
      let name = runFont?.fontName.lowercased() ?? ""
      runs.append([
        "text": trimmed,
        "x": Double(runRect.minX - box.minX),
        "y": Double(box.maxY - runRect.maxY),
        "w": Double(runRect.width),
        "h": Double(runRect.height),
        "size": Double(size),
        "font": runFont?.familyName ?? "Helvetica",
        "bold": traits?.contains(.traitBold) ?? name.contains("bold"),
        "italic": traits?.contains(.traitItalic)
          ?? (name.contains("italic") || name.contains("oblique")),
        "color": runColor,
      ])
    }

    for i in 0..<count {
      let scalar = characters.character(at: i)
      if scalar == 10 || scalar == 13 {
        flush()
        continue
      }
      let isSpace = scalar == 32 || scalar == 9
      var font: UIFont?
      var color = "000000"
      if let attributed, i < attributed.length {
        let attributes = attributed.attributes(at: i, effectiveRange: nil)
        font = attributes[.font] as? UIFont
        if let raw = attributes[.foregroundColor] as? UIColor {
          color = hex(raw)
        }
      }
      let bounds = page.characterBounds(at: i)
      let usable =
        !bounds.isNull && !bounds.isInfinite && bounds.width > 0
        && bounds.height > 0

      if runRect.isNull {
        // Never open a run on a space: it would shift the box left.
        if isSpace || !usable { continue }
        runText = String(characters.substring(with: NSRange(location: i, length: 1)))
        runRect = bounds
        runFont = font
        runColor = color
        continue
      }

      if !usable {
        if isSpace {
          runText.append(" ")
          continue
        }
        flush()
        continue
      }

      let size = runFont?.pointSize ?? runRect.height
      let sameStyle =
        font?.fontName == runFont?.fontName
        && abs((font?.pointSize ?? 0) - (runFont?.pointSize ?? 0)) < 0.6
        && color == runColor
      let sameLine =
        abs(bounds.midY - runRect.midY) <= max(1.5, runRect.height * 0.6)
      // A wide gap is a column break, not a space. Splitting here is
      // what keeps table cells under their own heading.
      let gap = bounds.minX - runRect.maxX
      let continues = gap <= max(1.5, size * 0.45) && gap > -size

      if sameStyle && sameLine && continues {
        runText.append(
          characters.substring(with: NSRange(location: i, length: 1))
        )
        runRect = runRect.union(bounds)
        continue
      }

      flush()
      if isSpace { continue }
      runText = String(characters.substring(with: NSRange(location: i, length: 1)))
      runRect = bounds
      runFont = font
      runColor = color
    }
    flush()
    return runs
  }

  /// Rules, underlines and filled bands, plus where pictures sit. Word
  /// gets these as shapes so a table still reads as a table.
  static func vectorContent(
    _ page: PDFPage,
    box: CGRect
  ) -> (rects: [[String: Any]], imageRects: [CGRect]) {
    guard let pageRef = page.pageRef, let table = CGPDFOperatorTableCreate()
    else {
      return ([], [])
    }
    let stream = CGPDFContentStreamCreateWithPage(pageRef)
    let collector = PdfContentCollector()
    collector.stream = stream
    ScanellaPdfScan.install(table)
    let info = Unmanaged.passUnretained(collector).toOpaque()
    let scanner = CGPDFScannerCreate(stream, table, info)
    CGPDFScannerScan(scanner)
    CGPDFScannerRelease(scanner)
    CGPDFOperatorTableRelease(table)
    CGPDFContentStreamRelease(stream)

    let pageArea = max(1, box.width * box.height)
    var rects: [[String: Any]] = []
    for shape in collector.shapes {
      let rect = shape.rect
      guard rect.width > 0.3, rect.height > 0.3 else { continue }
      // A full-page white wash is just the paper.
      let covers = (rect.width * rect.height) / pageArea > 0.95
      if covers && shape.color == "FFFFFF" { continue }
      rects.append([
        "x": Double(rect.minX - box.minX),
        "y": Double(box.maxY - rect.maxY),
        "w": Double(rect.width),
        "h": Double(rect.height),
        "color": shape.color,
      ])
      if rects.count >= 1200 { break }
    }
    return (rects, collector.images)
  }

  static func pageImages(
    _ page: PDFPage,
    box: CGRect,
    rects: [CGRect],
    hasText: Bool
  ) -> [[String: Any]] {
    guard !rects.isEmpty else { return [] }
    let scale: CGFloat = 200.0 / 72.0
    let pixels = CGSize(
      width: max(1, (box.width * scale).rounded()),
      height: max(1, (box.height * scale).rounded())
    )
    guard let sheet = page.thumbnail(of: pixels, for: .mediaBox).cgImage else {
      return []
    }
    let pageArea = max(1, box.width * box.height)
    var images: [[String: Any]] = []
    for rect in rects.prefix(40) {
      guard rect.width > 2, rect.height > 2 else { continue }
      // A picture the size of the page under real text is the scan of
      // that text; drawing it would double every glyph.
      if hasText, (rect.width * rect.height) / pageArea > 0.9 { continue }
      let crop = CGRect(
        x: (rect.minX - box.minX) * scale,
        y: (box.maxY - rect.maxY) * scale,
        width: rect.width * scale,
        height: rect.height * scale
      ).integral.intersection(
        CGRect(
          x: 0,
          y: 0,
          width: CGFloat(sheet.width),
          height: CGFloat(sheet.height)
        )
      )
      guard !crop.isNull, crop.width >= 1, crop.height >= 1,
            let cut = sheet.cropping(to: crop),
            let jpeg = UIImage(cgImage: cut).jpegData(compressionQuality: 0.9)
      else {
        continue
      }
      images.append([
        "x": Double(rect.minX - box.minX),
        "y": Double(box.maxY - rect.maxY),
        "w": Double(rect.width),
        "h": Double(rect.height),
        "jpeg": FlutterStandardTypedData(bytes: jpeg),
      ])
    }
    return images
  }

  static func hex(_ color: UIColor) -> String {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else {
      return "000000"
    }
    return String(
      format: "%02X%02X%02X",
      Int((r * 255).rounded()),
      Int((g * 255).rounded()),
      Int((b * 255).rounded())
    )
  }

  static func unlock(
    data: Data,
    password: String,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let document = PDFDocument(data: data) else {
        finish(
          result,
          FlutterError(
            code: "bad_pdf",
            message: "That PDF could not be read.",
            details: nil
          )
        )
        return
      }
      if document.isLocked {
        if !document.unlock(withPassword: password) {
          finish(
            result,
            FlutterError(
              code: "wrong_password",
              message:
                "Could not open this locked PDF. Check the password and try again.",
              details: nil
            )
          )
          return
        }
      }
      guard let unlocked = rewriteUnlocked(document), unlocked.count > 5 else {
        finish(
          result,
          FlutterError(
            code: "bad_pdf",
            message: "That PDF could not be unlocked.",
            details: nil
          )
        )
        return
      }
      finish(result, FlutterStandardTypedData(bytes: unlocked))
    }
  }

  /// Pages from [document] into a new file with no Encrypt dictionary.
  static func rewriteUnlocked(_ document: PDFDocument) -> Data? {
    let copied = PDFDocument()
    for i in 0..<document.pageCount {
      guard let page = document.page(at: i) else { continue }
      if let clone = page.copy() as? PDFPage {
        copied.insert(clone, at: copied.pageCount)
      }
    }
    if let data = copied.dataRepresentation(), !containsEncrypt(data) {
      return data
    }
    return drawUnlocked(document)
  }

  static func containsEncrypt(_ data: Data) -> Bool {
    guard let text = String(data: data, encoding: .isoLatin1) else {
      return false
    }
    return text.contains("/Encrypt")
  }

  static func drawUnlocked(_ document: PDFDocument) -> Data? {
    let data = NSMutableData()
    UIGraphicsBeginPDFContextToData(data, .zero, nil)
    defer { UIGraphicsEndPDFContext() }
    for i in 0..<document.pageCount {
      guard let page = document.page(at: i) else { continue }
      let media = page.bounds(for: .mediaBox)
      var width = media.width
      var height = media.height
      let rotation = ((page.rotation % 360) + 360) % 360
      if rotation == 90 || rotation == 270 {
        swap(&width, &height)
      }
      if width < 1 { width = 612 }
      if height < 1 { height = 792 }
      let pageRect = CGRect(x: 0, y: 0, width: width, height: height)
      UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
      guard let ctx = UIGraphicsGetCurrentContext() else { continue }
      ctx.saveGState()
      ctx.translateBy(x: 0, y: pageRect.height)
      ctx.scaleBy(x: 1, y: -1)
      page.draw(with: .mediaBox, to: ctx)
      ctx.restoreGState()
    }
    guard data.length > 5 else { return nil }
    return data as Data
  }

  static func renderPage(
    data: Data,
    index: Int,
    dpi: Int,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let document = PDFDocument(data: data),
            let page = document.page(at: index)
      else {
        finish(
          result,
          FlutterError(
            code: "bad_pdf",
            message: "That PDF could not be read.",
            details: nil
          )
        )
        return
      }
      if document.isLocked {
        finish(
          result,
          FlutterError(
            code: "encrypted",
            message: "That PDF is password-protected. Unlock it first.",
            details: nil
          )
        )
        return
      }
      let size = displaySize(page)
      let scale = CGFloat(max(dpi, 72)) / 72.0
      let pixels = CGSize(
        width: max(1, (size.width * scale).rounded()),
        height: max(1, (size.height * scale).rounded())
      )
      let thumb = page.thumbnail(of: pixels, for: .mediaBox)
      let renderer = UIGraphicsImageRenderer(size: pixels)
      let image = renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: pixels))
        thumb.draw(in: CGRect(origin: .zero, size: pixels))
      }
      guard let jpeg = image.jpegData(compressionQuality: 0.92) else {
        finish(
          result,
          FlutterError(
            code: "bad_pdf",
            message: "That PDF could not be read.",
            details: nil
          )
        )
        return
      }
      finish(
        result,
        [
          "jpeg": FlutterStandardTypedData(bytes: jpeg),
          "width": Int(pixels.width),
          "height": Int(pixels.height),
        ]
      )
    }
  }

  static func displaySize(_ page: PDFPage) -> CGSize {
    let bounds = page.bounds(for: .mediaBox)
    let rotated = page.rotation % 180 == 90
    if rotated {
      return CGSize(width: bounds.height, height: bounds.width)
    }
    return bounds.size
  }

  static func finish(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }
}

/// Page content collected while walking the PDF's drawing operators:
/// where pictures are placed, and the filled or stroked rectangles that
/// make up rules, borders and bands.
private final class PdfContentCollector {
  var ctm: CGAffineTransform = .identity
  var stack: [CGAffineTransform] = []
  var fillColor = "000000"
  var strokeColor = "000000"
  var lineWidth: CGFloat = 1
  var pendingRects: [CGRect] = []
  var pendingLines: [(CGPoint, CGPoint)] = []
  var currentPoint: CGPoint = .zero
  var shapes: [(rect: CGRect, color: String)] = []
  var images: [CGRect] = []
  var stream: CGPDFContentStreamRef?

  var full: Bool { shapes.count >= 1500 }

  func clearPath() {
    pendingRects.removeAll()
    pendingLines.removeAll()
  }

  func paint(filling: Bool) {
    let color = filling ? fillColor : strokeColor
    let thickness = max(0.4, lineWidth * scale)
    for rect in pendingRects {
      if filling {
        add(rect, color)
      } else {
        add(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: thickness), color)
        add(CGRect(x: rect.minX, y: rect.maxY - thickness, width: rect.width, height: thickness), color)
        add(CGRect(x: rect.minX, y: rect.minY, width: thickness, height: rect.height), color)
        add(CGRect(x: rect.maxX - thickness, y: rect.minY, width: thickness, height: rect.height), color)
      }
    }
    for line in pendingLines {
      let dx = abs(line.1.x - line.0.x)
      let dy = abs(line.1.y - line.0.y)
      if dy <= 1, dx > 1 {
        add(
          CGRect(
            x: min(line.0.x, line.1.x),
            y: min(line.0.y, line.1.y) - thickness / 2,
            width: dx,
            height: thickness
          ),
          color
        )
      } else if dx <= 1, dy > 1 {
        add(
          CGRect(
            x: min(line.0.x, line.1.x) - thickness / 2,
            y: min(line.0.y, line.1.y),
            width: thickness,
            height: dy
          ),
          color
        )
      }
    }
    clearPath()
  }

  private var scale: CGFloat {
    let determinant = abs(ctm.a * ctm.d - ctm.b * ctm.c)
    return determinant > 0 ? sqrt(determinant) : 1
  }

  private func add(_ rect: CGRect, _ color: String) {
    guard !full, rect.width > 0, rect.height > 0 else { return }
    shapes.append((rect: rect.standardized, color: color))
  }
}

/// The drawing operators we care about. Text is read through PDFKit, so
/// this pass only follows the graphics state, paths and image placement.
private enum ScanellaPdfScan {
  static func install(_ table: CGPDFOperatorTableRef) {
    CGPDFOperatorTableSetCallback(table, "q") { _, info in
      guard let collector = ScanellaPdfScan.collector(info) else { return }
      collector.stack.append(collector.ctm)
    }
    CGPDFOperatorTableSetCallback(table, "Q") { _, info in
      guard let collector = ScanellaPdfScan.collector(info) else { return }
      if let last = collector.stack.popLast() { collector.ctm = last }
    }
    CGPDFOperatorTableSetCallback(table, "cm") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            let values = ScanellaPdfScan.numbers(scanner, 6)
      else { return }
      let step = CGAffineTransform(
        a: values[0],
        b: values[1],
        c: values[2],
        d: values[3],
        tx: values[4],
        ty: values[5]
      )
      collector.ctm = step.concatenating(collector.ctm)
    }
    CGPDFOperatorTableSetCallback(table, "w") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            let values = ScanellaPdfScan.numbers(scanner, 1)
      else { return }
      collector.lineWidth = values[0]
    }
    CGPDFOperatorTableSetCallback(table, "re") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            let values = ScanellaPdfScan.numbers(scanner, 4)
      else { return }
      let rect = CGRect(
        x: values[0],
        y: values[1],
        width: values[2],
        height: values[3]
      )
      collector.pendingRects.append(rect.applying(collector.ctm))
    }
    CGPDFOperatorTableSetCallback(table, "m") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            let values = ScanellaPdfScan.numbers(scanner, 2)
      else { return }
      collector.currentPoint = CGPoint(x: values[0], y: values[1])
        .applying(collector.ctm)
    }
    CGPDFOperatorTableSetCallback(table, "l") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            let values = ScanellaPdfScan.numbers(scanner, 2)
      else { return }
      let next = CGPoint(x: values[0], y: values[1])
        .applying(collector.ctm)
      collector.pendingLines.append((collector.currentPoint, next))
      collector.currentPoint = next
    }
    for name in ["f", "F", "f*", "B", "B*", "b", "b*"] {
      CGPDFOperatorTableSetCallback(table, name) { _, info in
        ScanellaPdfScan.collector(info)?.paint(filling: true)
      }
    }
    for name in ["S", "s"] {
      CGPDFOperatorTableSetCallback(table, name) { _, info in
        ScanellaPdfScan.collector(info)?.paint(filling: false)
      }
    }
    CGPDFOperatorTableSetCallback(table, "n") { _, info in
      ScanellaPdfScan.collector(info)?.clearPath()
    }
    CGPDFOperatorTableSetCallback(table, "rg") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            let values = ScanellaPdfScan.numbers(scanner, 3)
      else { return }
      collector.fillColor = ScanellaPdfScan.hex(values[0], values[1], values[2])
    }
    CGPDFOperatorTableSetCallback(table, "RG") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            let values = ScanellaPdfScan.numbers(scanner, 3)
      else { return }
      collector.strokeColor = ScanellaPdfScan.hex(values[0], values[1], values[2])
    }
    CGPDFOperatorTableSetCallback(table, "g") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            let values = ScanellaPdfScan.numbers(scanner, 1)
      else { return }
      collector.fillColor = ScanellaPdfScan.hex(values[0], values[0], values[0])
    }
    CGPDFOperatorTableSetCallback(table, "G") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            let values = ScanellaPdfScan.numbers(scanner, 1)
      else { return }
      collector.strokeColor = ScanellaPdfScan.hex(values[0], values[0], values[0])
    }
    CGPDFOperatorTableSetCallback(table, "k") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            let values = ScanellaPdfScan.numbers(scanner, 4)
      else { return }
      collector.fillColor = ScanellaPdfScan.cmyk(values)
    }
    CGPDFOperatorTableSetCallback(table, "K") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            let values = ScanellaPdfScan.numbers(scanner, 4)
      else { return }
      collector.strokeColor = ScanellaPdfScan.cmyk(values)
    }
    CGPDFOperatorTableSetCallback(table, "Do") { scanner, info in
      guard let collector = ScanellaPdfScan.collector(info),
            collector.images.count < 40,
            let stream = collector.stream
      else { return }
      var rawName: UnsafePointer<Int8>?
      guard CGPDFScannerPopName(scanner, &rawName), let rawName else { return }
      guard let object = CGPDFContentStreamGetResource(stream, "XObject", rawName)
      else { return }
      var xobject: CGPDFStreamRef?
      guard CGPDFObjectGetValue(object, .stream, &xobject),
            let xobject,
            let dictionary = CGPDFStreamGetDictionary(xobject)
      else { return }
      var subtype: UnsafePointer<Int8>?
      guard CGPDFDictionaryGetName(dictionary, "Subtype", &subtype),
            let subtype,
            String(cString: subtype) == "Image"
      else { return }
      let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
      collector.images.append(unit.applying(collector.ctm).standardized)
    }
  }

  private static func collector(
    _ info: UnsafeMutableRawPointer?
  ) -> PdfContentCollector? {
    guard let info else { return nil }
    return Unmanaged<PdfContentCollector>.fromOpaque(info)
      .takeUnretainedValue()
  }

  private static func numbers(
    _ scanner: CGPDFScannerRef,
    _ count: Int
  ) -> [CGFloat]? {
    var values: [CGFloat] = []
    for _ in 0..<count {
      var value: CGPDFReal = 0
      guard CGPDFScannerPopNumber(scanner, &value) else { return nil }
      values.insert(value, at: 0)
    }
    return values
  }

  private static func hex(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> String {
    func channel(_ value: CGFloat) -> Int {
      Int((min(max(value, 0), 1) * 255).rounded())
    }
    return String(
      format: "%02X%02X%02X",
      channel(r),
      channel(g),
      channel(b)
    )
  }

  private static func cmyk(_ values: [CGFloat]) -> String {
    let k = values[3]
    return hex(
      (1 - values[0]) * (1 - k),
      (1 - values[1]) * (1 - k),
      (1 - values[2]) * (1 - k)
    )
  }
}
