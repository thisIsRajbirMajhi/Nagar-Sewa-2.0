import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../services/supabase_service.dart';
import '../../../models/user_model.dart';
import '../../../services/cache_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _wardController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  File? _newAvatar;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _wardController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final cached = CacheService.getCachedProfile();
      if (cached != null) {
        _populateFields(cached);
      }

      final profile = await SupabaseService.getProfile();
      if (profile != null) {
        if (mounted) {
          _populateFields(profile);
          CacheService.cacheProfile(profile);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load profile')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateFields(UserModel user) {
    _nameController.text = user.fullName;
    _phoneController.text = user.phone ?? '';
    _wardController.text = user.ward ?? '';
    _currentAvatarUrl = user.avatarUrl;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() {
        _newAvatar = File(picked.path);
      });
    }
  }

  Future<void> _autoFetchWard() async {
    try {
      // Show loading in ward field
      _wardController.text = 'Fetching location...';

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _wardController.text = '';
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _wardController.text = '';
          throw Exception('Location permissions are denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _wardController.text = '';
        throw Exception('Location permissions are permanently denied.');
      }

      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Construct a pseudo ward/area string
        setState(() {
          _wardController.text =
              '${place.subLocality ?? ''} ${place.locality ?? ''}'.trim();
        });
      } else {
        setState(() {
          _wardController.text = 'Location found, but address unknown';
        });
      }
    } catch (e) {
      setState(() {
        _wardController.text = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to auto-fetch ward: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      String? avatarUrl = _currentAvatarUrl;

      if (_newAvatar != null) {
        final bytes = await _newAvatar!.readAsBytes();
        final uid = SupabaseService.userId ?? 'anon';
        final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

        avatarUrl = await SupabaseService.uploadImage(
          path,
          bytes,
          bucket: 'avatars',
        );
      }

      final updates = {
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'ward': _wardController.text.trim(),
        'avatar_url': ?avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.updateProfile(updates);

      // Refresh cached profile
      final updatedProfile = await SupabaseService.getProfile();
      if (updatedProfile != null) {
        await CacheService.cacheProfile(updatedProfile);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.navyPrimary,
          title: const Text('Edit Profile'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.navyPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Section
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.border,
                          image: _newAvatar != null
                              ? DecorationImage(
                                  image: FileImage(_newAvatar!),
                                  fit: BoxFit.cover,
                                )
                              : _currentAvatarUrl != null &&
                                    _currentAvatarUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_currentAvatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            _newAvatar == null &&
                                (_currentAvatarUrl == null ||
                                    _currentAvatarUrl!.isEmpty)
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: AppColors.textLight,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Fields
              Text(
                'Full Name',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter your full name',
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),

              Text(
                'Phone Number',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'e.g., +91 9876543210',
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Ward No / Area',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _wardController,
                      decoration: const InputDecoration(
                        hintText: 'Enter ward or locality',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _autoFetchWard,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.navyPrimary.withValues(
                        alpha: 0.1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.my_location, color: AppColors.navyPrimary),
                    tooltip: 'Auto-detect Location',
                  ),
                ],
              ),
              const SizedBox(height: 40),

              AppButton(
                text: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
