import 'package:flutter/material.dart';

/// Design tokens taken from the Scanella mockups.
///
/// Values are named after their role rather than their hue so screens read as
/// intent ("brand", "ink") and a palette change lands in one place.
class Brand {
  const Brand._();

  /// The bundled type face. One family, five weights, carrying every screen
  /// from the welcome hero down to a settings caption — the single change
  /// that stops the app reading as a stock Material template.
  ///
  /// Glyphs outside its coverage (CJK, Arabic, Indic) fall through to the
  /// platform face automatically, so a Japanese or Hindi locale still renders.
  static const font = 'PlusJakartaSans';

  /// Brand green used for primary buttons, links, the scan target and
  /// the "ella" half of the wordmark.
  static const accent = Color(0xFF1F9A6B);
  static const accentDark = Color(0xFF187A55);

  /// Deeper green for the home hero only — a shade more compact than the
  /// fill used on buttons and the launch screen.
  static const hero = Color(0xFF109B70);

  /// A lift of the accent, used on dark surfaces and glow.
  static const accentBright = Color(0xFF3BB888);

  /// True black for the "Scan" half of the wordmark.
  static const wordmarkScan = Color(0xFF111111);

  /// Near-black navy used for headings and body ink.
  static const ink = Color(0xFF0B1B3F);
  static const inkSoft = Color(0xFF16264D);

  /// Body copy and secondary labels.
  static const grey = Color(0xFF6B7385);
  static const greyLight = Color(0xFF9AA1B1);

  /// Page and card surfaces.
  static const surface = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF7F9FC);

  /// Input and card outlines.
  static const outline = Color(0xFFE2E8F0);
  static const outlineStrong = Color(0xFFC9D2E0);

  /// Tints of the accent, for containers and selected states.
  static const accentWash = Color(0xFFE4F3ED);
  static const accentTint = Color(0xFFBCE1D3);

  /// Dark-mode counterparts. The app is used at night, on a sofa, scanning a
  /// receipt — a white flash there is the least premium thing a phone can do.
  static const inkCanvas = Color(0xFF0C1424);
  static const inkSurface = Color(0xFF131D30);
  static const inkSurfaceHigh = Color(0xFF1B263C);
  static const inkOutline = Color(0xFF27334A);
  static const accentLight = Color(0xFF5EC9A0);
  static const greyOnDark = Color(0xFF9AA5BD);
  static const paperOnDark = Color(0xFFE8ECF6);

  /// Accents used by the file chips in the hero illustrations.
  static const pdfRed = Color(0xFFE8443A);
  static const docBlue = Color(0xFF2C7BE5);
  static const imageGreen = Color(0xFF16A75C);
  static const cloudBlue = Color(0xFF3A8DFF);

  /// "Nearly there" in the camera overlay. Material's stock amber is a shade
  /// too close to a warm brand fill, so this one stays clearly not-blue.
  static const amber = Color(0xFFF5A524);

  static const radiusField = 16.0;
  static const radiusButton = 16.0;
  static const radiusCard = 20.0;
  static const radiusSheet = 28.0;

  /// Docked scan target: a rounded square, not a circle.
  static const radiusFab = 12.0;
  static const fieldHeight = 58.0;
  static const buttonHeight = 58.0;
}

/// The "Scanella" wordmark: Scan in black, ella in brand green.
/// On a dark surface (the drawer header) both halves go white.
class ScanellaWordmark extends StatelessWidget {
  const ScanellaWordmark({super.key, this.fontSize = 44, this.onDark = false});

  final double fontSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: Brand.font,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
      height: 1.05,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Scan',
            style: base.copyWith(
              color: onDark ? Colors.white : Brand.wordmarkScan,
            ),
          ),
          TextSpan(
            text: 'ella',
            style: base.copyWith(color: onDark ? Colors.white : Brand.accent),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// The rounded app mark: the Scanella scanner icon on brand green.
class ScanellaAppMark extends StatelessWidget {
  const ScanellaAppMark({super.key, this.size = 116});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.235),
        boxShadow: [
          BoxShadow(
            color: Brand.accent.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/brand/app_mark.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Primary full-width action button from the mockups: solid brand fill, bold label,
/// optional trailing arrow.
class BrandButton extends StatelessWidget {
  const BrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showArrow = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool showArrow;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: Brand.buttonHeight,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Brand.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Brand.accent.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusButton),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showArrow) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 21),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Bordered text field matching the mockups: leading grey icon, hint text,
/// generous height.
class BrandField extends StatelessWidget {
  const BrandField({
    super.key,
    required this.hint,
    required this.icon,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.trailing,
    this.validator,
    this.autofillHints,
  });

  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? trailing;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      autofillHints: autofillHints,
      style: const TextStyle(fontSize: 16, color: Brand.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Brand.greyLight, fontSize: 16),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(icon, size: 21, color: Brand.greyLight),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: trailing,
        filled: true,
        fillColor: Brand.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 19),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brand.radiusField),
          borderSide: const BorderSide(color: Brand.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brand.radiusField),
          borderSide: const BorderSide(color: Brand.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brand.radiusField),
          borderSide: const BorderSide(color: Brand.pdfRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brand.radiusField),
          borderSide: const BorderSide(color: Brand.pdfRed, width: 1.6),
        ),
      ),
    );
  }
}
