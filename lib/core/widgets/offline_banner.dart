import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../services/cache_service.dart';

/// A slim animated banner that appears when the app is offline.
/// Shows pending sync count and auto-hides when connectivity returns.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: isOnline
          ? const SizedBox(width: double.infinity, height: 0)
          : _buildBannerContent(),
    );
  }

  Widget _buildBannerContent() {
    final pendingCount = CacheService.pendingCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFE53935)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pendingCount > 0
                  ? 'Offline · $pendingCount report${pendingCount > 1 ? 's' : ''} pending sync'
                  : 'Offline · Showing cached data',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 800.ms)
              .then()
              .fadeOut(duration: 800.ms),
        ],
      ),
    );
  }
}

/// A banner that briefly appears when the connection is restored.
class BackOnlineBanner extends ConsumerStatefulWidget {
  const BackOnlineBanner({super.key});

  @override
  ConsumerState<BackOnlineBanner> createState() => _BackOnlineBannerState();
}

class _BackOnlineBannerState extends ConsumerState<BackOnlineBanner> {
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(connectionEventProvider, (prev, next) {
        next.whenData((event) {
          if (event == ConnectionEvent.cameOnline && mounted) {
            setState(() => _showBanner = true);
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _showBanner = false);
            });
          }
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: _showBanner
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Back online',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

/// A banner that shows when pending items have been synced. 
/// Use this as a one-shot notification after sync completes.
class SyncSuccessBanner extends StatelessWidget {
  final int syncedCount;
  const SyncSuccessBanner({super.key, required this.syncedCount});

  @override
  Widget build(BuildContext context) {
    if (syncedCount <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$syncedCount report${syncedCount > 1 ? 's' : ''} synced successfully!',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: -1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
