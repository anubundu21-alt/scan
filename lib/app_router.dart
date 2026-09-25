import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/features/camera/presentation/native_scan_screen.dart';
import 'package:scan2/features/crop/domain/crop_args.dart';
import 'package:scan2/features/crop/presentation/crop_screen.dart';
import 'package:scan2/features/library/presentation/document_detail_screen.dart';
import 'package:scan2/features/library/presentation/help_screen.dart';
import 'package:scan2/features/library/presentation/scan_picker_screen.dart';
import 'package:scan2/features/library/presentation/sign_pdf_screen.dart';
import 'package:scan2/features/library/presentation/trash_screen.dart';
import 'package:scan2/features/pro/presentation/pdf_to_word_screen.dart';
import 'package:scan2/features/pro/presentation/compress_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/merge_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/split_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/word_to_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/pdf_to_image_screen.dart';
import 'package:scan2/features/pro/presentation/images_to_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/pdf_page_tool_screens.dart';
import 'package:scan2/features/home/presentation/all_tools_screen.dart';
import 'package:scan2/features/home/presentation/home_shell.dart';
import 'package:scan2/features/legal/legal_copy.dart';
import 'package:scan2/features/legal/legal_screen.dart';
import 'package:scan2/features/onboarding/presentation/onboarding_screen.dart';
import 'package:scan2/features/onboarding/presentation/welcome_screen.dart';
import 'package:scan2/features/pro/presentation/coming_soon_tool_screen.dart';
import 'package:scan2/features/pro/presentation/complete_features_screen.dart';
import 'package:scan2/features/settings/presentation/settings_screen.dart';
import 'package:scan2/features/onboarding/presentation/free_access_screen.dart';
import 'package:scan2/features/onboarding/presentation/pro_intro_screen.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/shared/providers/onboarding_provider.dart';
import 'package:scan2/features/signatures/presentation/place_signature_screen.dart';

/// Close the first run and drop the customer into the library.
void _leaveIntro(BuildContext context, Ref ref) {
  ref.read(onboardingCompletedProvider.notifier).complete();
  context.go('/library');
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/library',
    redirect: (context, state) {
      // Read rather than watch: rebuilding the router mid-navigation would
      // drop the current route stack.
      final seenIntro = ref.read(onboardingCompletedProvider);
      final location = state.matchedLocation;

      const intro = {'/welcome', '/onboarding', '/free-access', '/pro-intro'};
      const legal = {'/legal/terms', '/legal/privacy'};

      // First run: welcome, then the intro pages. Terms and Privacy are
      // reachable from the welcome footer so those links are not dead.
      if (!seenIntro) {
        return intro.contains(location) || legal.contains(location)
            ? null
            : '/welcome';
      }
      if (intro.contains(location)) return '/library';
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/free-access',
        builder: (context, state) => FreeAccessScreen(
          // Someone who already has Pro has no free allowance to explain and
          // no offer to see, so both screens are skipped for them.
          onContinue: () =>
              ref.read(proProvider).isPro && !ref.read(proProvider).testingBuild
              ? _leaveIntro(context, ref)
              : context.go('/pro-intro'),
        ),
      ),
      GoRoute(
        path: '/pro-intro',
        builder: (context, state) =>
            ProIntroScreen(onDone: () => _leaveIntro(context, ref)),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) =>
            const LegalScreen(document: LegalDocument.terms),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) =>
            const LegalScreen(document: LegalDocument.privacy),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const HomeShell(),
        routes: [
          GoRoute(
            path: 'document/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) return const _RouteError(message: 'Bad document');
              final extra = state.extra;
              final mode = extra is DocumentScreenMode
                  ? extra
                  : DocumentScreenMode.scan;
              return DocumentDetailScreen(documentId: id, mode: mode);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) {
          // The platform scanner (VisionKit / ML Kit) is the only capture
          // path. It finds edges far better than the in-app camera did, and
          // that camera is no longer reachable — see CameraScreen.
          return NativeScanScreen(idCard: state.extra == true);
        },
      ),
      GoRoute(path: '/trash', builder: (context, state) => const TrashScreen()),
      GoRoute(path: '/help', builder: (context, state) => const HelpScreen()),
      GoRoute(
        path: '/features',
        builder: (context, state) => const CompleteFeaturesScreen(),
      ),
      GoRoute(
        path: '/pdf/edit',
        builder: (context, state) =>
            const ScanPickerScreen(mode: DocumentScreenMode.editPdf),
      ),
      GoRoute(
        path: '/pdf/sign',
        builder: (context, state) => const SignPdfScreen(),
      ),
      GoRoute(
        path: '/pdf/word',
        builder: (context, state) => const PdfToWordScreen(),
      ),
      GoRoute(
        path: '/word/pdf',
        builder: (context, state) => const WordToPdfScreen(),
      ),
      GoRoute(
        path: '/pdf/compress',
        builder: (context, state) => const CompressPdfScreen(),
      ),
      GoRoute(
        path: '/pdf/merge',
        builder: (context, state) => const MergePdfScreen(),
      ),
      GoRoute(
        path: '/pdf/split',
        builder: (context, state) => const SplitPdfScreen(),
      ),
      GoRoute(
        path: '/pdf/images',
        builder: (context, state) => const PdfToImageScreen(),
      ),
      GoRoute(
        path: '/pdf/from-images',
        builder: (context, state) => const ImagesToPdfScreen(),
      ),
      GoRoute(
        path: '/pdf/rotate',
        builder: (context, state) => const PdfRotateScreen(),
      ),
      GoRoute(
        path: '/pdf/pages',
        builder: (context, state) => const PdfPageNumbersScreen(),
      ),
      GoRoute(
        path: '/pdf/watermark',
        builder: (context, state) => const PdfWatermarkScreen(),
      ),
      GoRoute(
        path: '/pdf/unlock',
        builder: (context, state) => const PdfUnlockScreen(),
      ),
      GoRoute(
        path: '/tools',
        builder: (context, state) => const AllToolsScreen(),
      ),
      GoRoute(
        path: '/tools/unavailable',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is ComingSoonTool) {
            return ComingSoonToolScreen(tool: extra);
          }
          return const ComingSoonToolScreen(
            tool: ComingSoonTool(
              title: 'Coming soon',
              detail: 'This conversion is not in this version of Scanella yet.',
            ),
          );
        },
      ),
      GoRoute(
        path: '/crop',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is CropArgs) return CropScreen.fromArgs(extra);
          if (extra is String) return CropScreen(imagePath: extra);
          return const _RouteError(message: 'Nothing to edit');
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/sign/place',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is PlaceSignatureArgs) {
            return PlaceSignatureScreen(args: extra);
          }
          return const _RouteError(message: 'Nothing to sign');
        },
      ),
    ],
    errorBuilder: (context, state) =>
        _RouteError(message: 'Page not found: ${state.uri}'),
  );

  ref.listen<bool>(onboardingCompletedProvider, (_, __) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

class _RouteError extends StatelessWidget {
  const _RouteError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/library'),
                child: const Text('Back to library'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
