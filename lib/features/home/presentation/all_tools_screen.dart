import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/home/domain/import_service.dart';
import 'package:scan2/features/home/presentation/tool_glyph.dart';
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
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
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
  const _ToolItem({required this.id, required this.title, required this.ink});

  final String id;
  final String title;

  /// The tool's bright colour. The tile wash and the icon square are made
  /// from it, so each tool needs only one colour.
  final Color ink;
}

const _allTools = <_ToolItem>[
  _ToolItem(id: 'img-pdf', title: 'Image to PDF', ink: Color(0xFF1E88E5)),
  _ToolItem(id: 'word-pdf', title: 'Word to PDF', ink: Color(0xFF2B6CEE)),
  _ToolItem(id: 'pdf-word', title: 'PDF to Word', ink: Color(0xFF2B6CEE)),
  _ToolItem(id: 'compress', title: 'Compress PDF', ink: Color(0xFF7C4DFF)),
  _ToolItem(id: 'merge', title: 'Merge PDF', ink: Color(0xFFFB8C00)),
  _ToolItem(id: 'jpg', title: 'PDF to JPG', ink: Color(0xFFF9A825)),
  _ToolItem(id: 'split', title: 'Split PDF', ink: Color(0xFFF4511E)),
  _ToolItem(id: 'pages', title: 'Page numbers', ink: Color(0xFF7E57C2)),
  _ToolItem(id: 'watermark', title: 'Watermark', ink: Color(0xFF2E9E4F)),
  _ToolItem(id: 'rotate', title: 'Rotate PDF', ink: Color(0xFF1E88E5)),
  _ToolItem(id: 'unlock', title: 'Unlock PDF', ink: Color(0xFF00A38C)),
  _ToolItem(id: 'sign', title: 'Sign PDF', ink: Color(0xFF3F51D8)),
  _ToolItem(id: 'extract', title: 'Extract text', ink: Color(0xFFE8457A)),
];

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool, required this.onPressed});

  final _ToolItem tool;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final ink = tool.ink;

    return PressableScale(
      onPressed: onPressed,
      haptic: AppHaptic.impactLight,
      scale: Tactile.pressScaleCard,
      borderRadius: BorderRadius.circular(20),
      minSize: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
        decoration: BoxDecoration(
          color: isLight
              ? Color.lerp(Colors.white, ink, 0.07)
              : ink.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ink.withValues(alpha: isLight ? 0.16 : 0.30),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ToolGlyph(toolId: tool.id, color: ink),
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
