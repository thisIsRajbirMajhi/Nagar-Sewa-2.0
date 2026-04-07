import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../providers/theme_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.getProfile();
      if (mounted) {
        setState(() {
          _user = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider); // Rebuild when theme changes

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          _user?.avatarUrl == null || _user!.avatarUrl!.isEmpty
                          ? LinearGradient(
                              colors: AppColors.avatarGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      image:
                          _user?.avatarUrl != null &&
                              _user!.avatarUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_user!.avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _user?.avatarUrl == null || _user!.avatarUrl!.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 40,
                          )
                        : null,
                  ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
                  const SizedBox(height: 16),
                  Text(
                    _user?.fullName ?? 'User',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyPrimary,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  Text(
                    SupabaseService.currentUser?.email ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 8),
                  // Civic score badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greenAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: AppColors.greenAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Civic Score: ${_user?.civicScore ?? 0}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 32),

                  // Settings sections
                  _buildSection('Account', [
                    _buildTile(Icons.person_outline, 'Edit Profile', () async {
                      final updated = await context.push('/edit-profile');
                      if (updated == true) {
                        _loadProfile();
                      }
                    }),
                    _buildTile(
                      Icons.phone_outlined,
                      'Phone: ${_user?.phone ?? "Not set"}',
                      () {},
                    ),
                    _buildTile(
                      Icons.location_on_outlined,
                      'Ward: ${_user?.ward ?? "Not set"}',
                      () {},
                    ),
                  ]).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 16),
                  _buildSection('Preferences', [
                    _buildTile(
                      Icons.notifications_outlined,
                      'Notifications',
                      () => context.push('/notifications'),
                    ),
                    _buildTile(Icons.language, 'Language', () {}),
                    SwitchListTile(
                      value: ref.watch(themeProvider) == ThemeMode.dark,
                      onChanged: (_) {
                        ref.read(themeProvider.notifier).toggleTheme();
                      },
                      title: Text(
                        'Toggle Dark Mode',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      secondary: Icon(
                        Icons.nightlight_round,
                        color: AppColors.navyPrimary,
                        size: 22,
                      ),
                      activeThumbColor: AppColors.greenAccent,
                    ),
                  ]).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 16),
                  _buildSection('About', [
                    _buildTile(Icons.help_outline, 'Help & Support', () {
                      context.push(
                        '/static',
                        extra: {
                          'title': 'Help & Support',
                          'content':
                              'Welcome to NagarSewa Support.\n\n'
                              '1. Reporting Issues: Tap the plus icon in the bottom bar, take a photo, select a category, and submit.\n\n'
                              '2. Tracking Progress: Check the "History" tab to see real-time updates on your submitted issues.\n\n'
                              '3. Civic Score: You earn 10 Civic Score points for every issue that gets resolved. Help your community to climb the ranks!\n\n'
                              'If you face technical difficulties, please contact our support desk at support@nagar-sewa.in.',
                        },
                      );
                    }),
                    _buildTile(Icons.privacy_tip_outlined, 'Privacy Policy', () {
                      context.push(
                        '/static',
                        extra: {
                          'title': 'Privacy Policy',
                          'content':
                              'NagarSewa Privacy Policy\n\n'
                              'Last Updated: March 2026\n\n'
                              '1. Data Collection: We collect location data and media (photos/videos) explicitly provided by you when reporting an issue. Your personal profile information (Name, Email, Phone) is used solely for verification and communication.\n\n'
                              '2. Location Services: Location is required to accurately map issues for municipal response. Location is only captured when you interact with the app.\n\n'
                              '3. Data Protection: Your data is encrypted in transit and at rest using industry standards provided by Supabase.\n\n'
                              '4. Third Parties: We do not sell your personal data. Aggregated, anonymized issue data may be shared with municipal authorities for planning purposes.',
                        },
                      );
                    }),
                    _buildTile(Icons.info_outline, 'About NagarSewa', () {
                      context.push(
                        '/static',
                        extra: {
                          'title': 'About NagarSewa',
                          'content':
                              'NagarSewa - Empowering Citizens, Transforming Cities.\n\n'
                              'Version 1.0.0\n\n'
                              'NagarSewa is a civic issue reporting and resolution platform. Our mission is to bridge the gap between citizens and municipal authorities by providing a transparent, real-time, and efficient digital infrastructure.\n\n'
                              'With integrated features like issue categorization, location tracking, and an automated civic rewarding system, NagarSewa brings power back to the people.',
                        },
                      );
                    }),
                  ]).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 24),

                  // Logout
                  AppButton(
                    text: 'Logout',
                    backgroundColor: AppColors.urgentRed,
                    icon: Icons.logout_rounded,
                    onPressed: () async {
                      await SupabaseService.signOut();
                      if (context.mounted) context.go('/login');
                    },
                  ).animate().fadeIn(delay: 700.ms),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _buildTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.navyPrimary, size: 22),
      title: Text(title, style: GoogleFonts.inter(fontSize: 14)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textLight),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
