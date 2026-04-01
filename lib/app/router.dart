import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/widgets/bottom_nav_bar.dart';
import '../core/widgets/offline_banner.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/password_reset_sent_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dashboard/screens/filtered_issues_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/map/screens/live_map_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/report/screens/report_screen.dart';
import '../features/issue_detail/screens/issue_detail_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/static_page_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/drafts/screens/drafts_screen.dart';
import '../features/admin/screens/verification_queue_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Auth routes that don't require authentication.
const _authRoutes = [
  '/',
  '/login',
  '/register',
  '/forgot-password',
  '/reset-sent',
];

/// Check if user has a valid, confirmed session.
bool _isAuthenticated() {
  final user = Supabase.instance.client.auth.currentUser;
  return user != null && user.emailConfirmedAt != null;
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = _isAuthenticated();
    final isAuthRoute = _authRoutes.contains(state.matchedLocation);

    // If user is on splash, let it handle its own navigation
    if (state.matchedLocation == '/') return null;

    // If authenticated and trying to access auth routes, redirect to dashboard
    if (isLoggedIn && isAuthRoute) return '/dashboard';

    // If not authenticated and trying to access protected routes, redirect to login
    if (!isLoggedIn && !isAuthRoute) return '/login';

    return null;
  },
  routes: [
    // Auth routes (no bottom nav)
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-sent',
      builder: (context, state) =>
          PasswordResetSentScreen(email: state.extra as String?),
    ),

    // Main app with bottom nav
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/history',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HistoryScreen()),
        ),
        GoRoute(
          path: '/map',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LiveMapScreen()),
        ),
        GoRoute(
          path: '/chat',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ChatScreen()),
        ),
      ],
    ),

    // Full-screen routes (no bottom nav)
    GoRoute(path: '/report', builder: (context, state) => const ReportScreen()),
    GoRoute(
      path: '/issue/:id',
      builder: (context, state) =>
          IssueDetailScreen(issueId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/drafts', builder: (context, state) => const DraftsScreen()),
    GoRoute(
      path: '/admin/verification-queue',
      builder: (context, state) => const VerificationQueueScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/issues/:filter',
      builder: (context, state) =>
          FilteredIssuesScreen(filterType: state.pathParameters['filter']!),
    ),
    GoRoute(
      path: '/static',
      builder: (context, state) {
        final Map<String, dynamic> extra =
            state.extra as Map<String, dynamic>? ?? {};
        return StaticPageScreen(
          title: extra['title'] ?? 'Information',
          content: extra['content'] ?? 'Content coming soon.',
        );
      },
    ),
  ],
);

class _AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  int _currentIndex = 0;

  static const _routes = ['/dashboard', '/history', '/map', '/chat'];

  @override
  Widget build(BuildContext context) {
    // Sync index with current route
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _routes.length; i++) {
      if (location == _routes[i]) {
        if (_currentIndex != i) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentIndex = i);
          });
        }
        break;
      }
    }

    return Scaffold(
      body: Column(
        children: [
          // Connectivity banners (visible on all tabbed screens)
          const OfflineBanner(),
          const BackOnlineBanner(),

          // Screen content
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          context.go(_routes[index]);
        },
      ),
    );
  }
}
