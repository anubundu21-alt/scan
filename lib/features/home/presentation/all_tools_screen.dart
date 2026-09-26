import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/home/domain/import_service.dart';
import 'package:scan2/features/home/presentation/tool_art.dart';
import 'package:scan2/features/ocr/domain/on_device_ocr.dart';
import 'package:scan2/features/ocr/presentation/ocr_result_screen.dart';
import 'package:scan2/features/pro/presentation/coming_soon_tool_screen.dart';

/// Every tool that is not one of the three home shortcuts.
class AllToolsScreen extends ConsumerStatefulWidget {
  const AllToolsScreen({super.key});

  @override
  ConsumerState<AllToolsScreen> createState() => _AllToolsScreenState();
}

class _AllToolsScreenState extends ConsumerState<AllToolsScreen> {
  static const _importer = ImportService();
  static final _ocr = OnDeviceOcr();
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 600 ? 4 : 3;
    const maxGridWidth = 680.0;
    final sidePad = width > maxGridWidth + 36
        ? (width - maxGridWidth) / 2
        : 18.0;

    return Scaffold(
      backgroundColor: isLight ? const Color(0xFFF7F9FC) : scheme.surface,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: isLight ? const Color(0xFFF7F9FC) : scheme.surface,
        leadingWidth: 48,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              Navigator.of(context).maybePop();
            }
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isLight ? Brand.ink : scheme.onSurface,
          ),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All tools',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: isLight ? Brand.ink : scheme.onSurface,
              ),
            ),
            Text(
              'PDF, text, sign, convert and more',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isLight
                    ? const Color(0xFF68748A)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                // On an iPad the grid stays phone-sized and centred, so the
                // tiles do not stretch into huge empty cards.
                padding: EdgeInsets.fromLTRB(sidePad, 12, sidePad, 28),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.88,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: _allTools.length,
                    (context, index) => _ToolCard(
                      tool: _allTools[index],
                      onPressed: () => _open(_allTools[index]),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_working)
            Positioned.fill(
              child: ColoredBox(
                color: Brand.ink.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 18),
                      Text(
                        'Reading the text…',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(_ToolItem tool) async {
    if (_working) return;
    switch (tool.id) {
      case 'pdf-word':
        context.push('/pdf/word');
      case 'word-pdf':
        context.push('/word/pdf');
      case 'img-pdf':
        context.push('/pdf/from-images');
      case 'compress':
        context.push('/pdf/compress');
      case 'merge':
        context.push('/pdf/merge');
      case 'split':
        context.push('/pdf/split');
      case 'jpg':
        context.push('/pdf/images');
      case 'pages':
        context.push('/pdf/pages');
      case 'watermark':
        context.push('/pdf/watermark');
      case 'rotate':
        context.push('/pdf/rotate');
      case 'unlock':
        context.push('/pdf/unlock');
      case 'sign':
        context.push('/pdf/sign');
      case 'extract':
        await _extractText();
      default:
        _soon(tool.title);
    }
  }

  void _soon(String title) {
    context.push(
      '/tools/unavailable',
      extra: ComingSoonTool(
        title: title,
        detail: '$title is not in this version of Scanella yet.',
      ),
    );
  }

  Future<void> _extractText() async {
    try {
      final bytes = await _importer.pickImageBytes();
      if (bytes == null) return;
      if (!mounted) return;
      setState(() => _working = true);
      final text = await _ocr.recognize(bytes);
      if (!mounted) return;
      setState(() => _working = false);
      await AppHaptics.success();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => OcrResultScreen(text: text)),
      );
    } catch (e) {
      await AppHaptics.error();
      if (mounted) setState(() => _working = false);
    }
  }
}

class _ToolItem {
  const _ToolItem({
    required this.id,
    required this.title,
    required this.wash,
    required this.ink,
  });

  final String id;
  final String title;
  final Color wash;
  final Color ink;
}

const _allTools = <_ToolItem>[
  _ToolItem(
    id: 'pdf-word',
    title: 'PDF to Word',
    wash: Color(0xFFD4E4FF),
    ink: Color(0xFF1A5CFF),
  ),
  _ToolItem(
    id: 'word-pdf',
    title: 'Word to PDF',
    wash: Color(0xFFD4E4FF),
    ink: Color(0xFF1A5CFF),
  ),
  _ToolItem(
    id: 'img-pdf',
    title: 'Image to PDF',
    wash: Color(0xFFFFE7A8),
    ink: Color(0xFFF2A100),
  ),
  _ToolItem(
    id: 'compress',
    title: 'Compress PDF',
    wash: Color(0xFFE2D4FF),
    ink: Color(0xFF7B2FF7),
  ),
  _ToolItem(
    id: 'merge',
    title: 'Merge PDF',
    wash: Color(0xFFFFDDC2),
    ink: Color(0xFFFF6B00),
  ),
  _ToolItem(
    id: 'jpg',
    title: 'PDF to JPG',
    wash: Color(0xFFFFE7A8),
    ink: Color(0xFFF2A100),
  ),
  _ToolItem(
    id: 'split',
    title: 'Split PDF',
    wash: Color(0xFFFFD1D1),
    ink: Color(0xFFE8252A),
  ),
  _ToolItem(
    id: 'pages',
    title: 'Page numbers',
    wash: Color(0xFFD9DCFF),
    ink: Color(0xFF4C4DDC),
  ),
  _ToolItem(
    id: 'watermark',
    title: 'Watermark',
    wash: Color(0xFFD2F5D8),
    ink: Color(0xFF18A83B),
  ),
  _ToolItem(
    id: 'rotate',
    title: 'Rotate PDF',
    wash: Color(0xFFD9DCFF),
    ink: Color(0xFF4C4DDC),
  ),
  _ToolItem(
    id: 'unlock',
    title: 'Unlock PDF',
    wash: Color(0xFFC9F2EA),
    ink: Color(0xFF00A88F),
  ),
  _ToolItem(
    id: 'sign',
    title: 'Sign PDF',
    wash: Color(0xFFC9F2EA),
    ink: Color(0xFF00A88F),
  ),
];

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool, required this.onPressed});

  final _ToolItem tool;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return PressableScale(
      onPressed: onPressed,
      haptic: AppHaptic.impactLight,
      scale: Tactile.pressScaleCard,
      borderRadius: BorderRadius.circular(22),
      minSize: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 11),
        decoration: BoxDecoration(
          // Plain card: the colour lives in the icon, not behind it.
          color: isLight
              ? Colors.white
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isLight
                ? const Color(0xFFE6EAF2)
                : theme.colorScheme.outlineVariant,
          ),
          boxShadow: isLight
              ? [
                  BoxShadow(
                    color: const Color(0xFF101D41).withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                // Scale down rather than clip: three columns on a 320pt phone
                // leave the art less room than the stage wants.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AllToolsMark(toolId: tool.id, ink: tool.ink, size: 78),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tool.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                height: 1.15,
                letterSpacing: -0.1,
                color: isLight
                    ? const Color(0xFF101D41)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
