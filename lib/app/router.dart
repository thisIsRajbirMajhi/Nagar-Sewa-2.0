import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/widgets/bottom_nav_bar.dart';
import '../core/widgets/offline_banner.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/password_reset_sent_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dashboard/screens/filtered_issues_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/map/screens/live_map_screen.dart';
import '../features/report/screens/report_screen.dart';
import '../features/issue_detail/screens/issue_detail_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/static_page_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/drafts/screens/drafts_screen.dart';
import '../features/officer/screens/officer_dashboard_screen.dart';
import '../features/officer/screens/officer_history_screen.dart';
import '../features/officer/screens/officer_map_screen.dart';
import '../features/officer/screens/officer_issue_detail_screen.dart';

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
final routerProvider = Provider<GoRouter>((ref) {
  final userProfile = ref.watch(userProfileProvider).asData?.value;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = SupabaseService.isAuthenticated;
      final isAuthRoute = _authRoutes.contains(state.matchedLocation);

      // If user is on splash, let it handle its own navigation
      if (state.matchedLocation == '/') return null;

      if (!isLoggedIn) {
        if (!isAuthRoute) return '/login';
        return null;
      }

      // User is logged in
      final role = userProfile?.role ?? 'citizen';

      // Redirect based on role
      if (role == 'officer') {
        if (state.matchedLocation.startsWith('/officer')) return null;
        if (isAuthRoute || state.matchedLocation == '/dashboard') {
          return '/officer/dashboard';
        }
      } else {
        // Citizen redirection
        if (isAuthRoute) return '/dashboard';
        if (state.matchedLocation.startsWith('/officer')) return '/dashboard';
      }

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

      // Citizen app with bottom nav
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
        ],
      ),

      // Officer app with bottom nav
      ShellRoute(
        navigatorKey: GlobalKey<NavigatorState>(),
        builder: (context, state, child) => _OfficerShell(child: child),
        routes: [
          GoRoute(
            path: '/officer/dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OfficerDashboardScreen()),
          ),
          GoRoute(
            path: '/officer/history',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OfficerHistoryScreen()),
          ),
          GoRoute(
            path: '/officer/map',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OfficerMapScreen()),
          ),
          GoRoute(
            path: '/officer/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),

      // Full-screen routes (no bottom nav)
      GoRoute(
        path: '/report',
        builder: (context, state) => const ReportScreen(),
      ),
      GoRoute(
        path: '/issue/:id',
        builder: (context, state) {
          final userProfile = ref.watch(userProfileProvider).asData?.value;
          final role = userProfile?.role ?? 'citizen';
          final issueId = state.pathParameters['id']!;

          if (role == 'officer') {
            return OfficerIssueDetailScreen(issueId: issueId);
          }
          return IssueDetailScreen(issueId: issueId);
        },
      ),
      GoRoute(
        path: '/drafts',
        builder: (context, state) => const DraftsScreen(),
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
});

class _AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  int _currentIndex = 0;

  static const _routes = ['/dashboard', '/history', '/map'];

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

class _OfficerShell extends ConsumerStatefulWidget {
  final Widget child;
  const _OfficerShell({required this.child});

  @override
  ConsumerState<_OfficerShell> createState() => _OfficerShellState();
}

class _OfficerShellState extends ConsumerState<_OfficerShell> {
  int _currentIndex = 0;

  static const _routes = [
    '/officer/dashboard',
    '/officer/history',
    '/officer/map',
    '/officer/profile',
  ];

  @override
  Widget build(BuildContext context) {
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
          const OfflineBanner(),
          const BackOnlineBanner(),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            context.go(_routes[index]);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF132D46),
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded),
              activeIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
