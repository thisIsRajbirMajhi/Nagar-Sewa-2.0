import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_header.dart';
import '../../../models/verification_result.dart';
import '../../../models/ai_models.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/verification_service.dart';
import '../notifiers/ai_image_analysis_notifier.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  final _verificationService = VerificationService();
  MapLibreMapController? _mapController;

  XFile? _photo;
  XFile? _video;
  Uint8List? _photoBytes;
  double? _latitude;
  double? _longitude;
  String? _address;
  bool _locationFetched = false;
  bool _isSubmitting = false;
  String _selectedCategory = 'pothole';
  bool _showVerificationWarning = false;
  String _verificationWarningMessage = '';
  ConfidenceLevel _verificationConfidence = ConfidenceLevel.high;
  bool _isVerifying = false;
  bool _isAnalyzing = false;

  final List<Map<String, dynamic>> _categories = [
    {'value': 'pothole', 'label': 'Pothole', 'icon': Icons.warning_rounded},
    {
      'value': 'garbage_overflow',
      'label': 'Garbage',
      'icon': Icons.delete_rounded,
    },
    {
      'value': 'broken_streetlight',
      'label': 'Streetlight',
      'icon': Icons.lightbulb_outline,
    },
    {'value': 'sewage_leak', 'label': 'Sewage', 'icon': Icons.water_drop},
    {
      'value': 'open_manhole',
      'label': 'Manhole',
      'icon': Icons.circle_outlined,
    },
    {'value': 'waterlogging', 'label': 'Waterlogging', 'icon': Icons.waves},
    {'value': 'encroachment', 'label': 'Encroachment', 'icon': Icons.fence},
    {'value': 'road', 'label': 'Road', 'icon': Icons.add_road},
    {'value': 'water', 'label': 'Water', 'icon': Icons.water},
    {
      'value': 'electricity',
      'label': 'Electricity',
      'icon': Icons.electric_bolt,
    },
    {
      'value': 'sanitation',
      'label': 'Sanitation',
      'icon': Icons.cleaning_services,
    },
    {'value': 'garbage', 'label': 'Garbage', 'icon': Icons.delete},
    {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position != null && mounted) {
      final address = await LocationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _address = address ?? 'Location fetched';
        _locationFetched = true;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _photo = file;
        _photoBytes = bytes;
      });
      await _verifyMedia();
    }
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );
    if (file != null) {
      setState(() => _video = file);
      await _verifyMedia();
    }
  }

  Future<void> _verifyMedia() async {
    if (_photoBytes == null && _video == null) return;
    if (_latitude == null || _longitude == null) return;

    setState(() => _isVerifying = true);

    try {
      Uint8List? videoBytes;
      if (_video != null) {
        videoBytes = await _video!.readAsBytes();
      }

      final result = await _verificationService.verifyMedia(
        photoBytes: _photoBytes,
        videoBytes: videoBytes,
        userLat: _latitude!,
        userLng: _longitude!,
        submissionTime: DateTime.now(),
      );

      setState(() {
        _showVerificationWarning = result.hasIssues;
        _verificationWarningMessage = result.failureReason;
        _verificationConfidence = result.confidence;
      });
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _analyzeImage() async {
    if (_photoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a photo first')),
      );
      return;
    }

    final locale = Platform.localeName;
    setState(() => _isAnalyzing = true);

    try {
      await ref
          .read(aiImageAnalysisProvider.notifier)
          .analyzeImage(_photoBytes!, locale);

      final resultAsync = ref.read(aiImageAnalysisProvider);
      final result = resultAsync is AsyncData<ImageAnalysisResult?>
          ? resultAsync.value
          : null;
      if (result != null && mounted) {
        _applyAnalysisResult(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _applyAnalysisResult(ImageAnalysisResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnalysisResultSheet(
        result: result,
        onApply: () {
          setState(() {
            if (result.title.isNotEmpty) {
              _descriptionController.text =
                  '${result.title}\n\n${result.description}';
            }
            _selectedCategory = _mapAiCategory(result.category);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  String _mapAiCategory(String aiCategory) {
    final categoryMap = {
      'road': 'pothole',
      'water': 'waterlogging',
      'electricity': 'broken_streetlight',
      'sanitation': 'sewage_leak',
      'garbage': 'garbage_overflow',
      'other': 'other',
    };
    return categoryMap[aiCategory] ?? 'other';
  }

  Future<void> _submit({bool isDraft = false}) async {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Waiting for location...')));
      return;
    }

    if (_verificationConfidence == ConfidenceLevel.low && !isDraft) {
      final confirmed = await _showLowConfidenceDialog();
      if (!confirmed) return;
    }

    setState(() => _isSubmitting = true);
    try {
      Uint8List? videoBytes;
      if (_video != null) {
        videoBytes = await _video!.readAsBytes();
      }

      final (photoUrls, videoUrl) = await SupabaseService.uploadMedia(
        photoBytes: _photoBytes,
        videoBytes: videoBytes,
      );

      final title = _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim().split('\n').first
          : '${_categories.firstWhere((c) => c['value'] == _selectedCategory)['label']} Issue';

      await SupabaseService.createIssue({
        'reporter_id': SupabaseService.userId,
        'title': title,
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'latitude': _latitude,
        'longitude': _longitude,
        'address': _address,
        'photo_urls': photoUrls,
        'video_url': videoUrl,
        'is_draft': isDraft,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDraft ? 'Draft saved!' : 'Issue reported successfully!',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _showLowConfidenceDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verification Warning'),
            content: const Text(
              'This report has been flagged due to verification issues. '
              'It will be reviewed by an admin before publication. '
              'Do you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit Anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildVerificationWarning() {
    if (!_showVerificationWarning) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _verificationWarningMessage,
              style: TextStyle(color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            userName: 'Report',
            subtitle: 'Submit a new issue',
            onMenuTap: () => context.pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Issue',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyPrimary,
                    ),
                  ).animate().fadeIn(),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickPhoto,
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.navyPrimary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _photo != null
                                      ? Icons.check_circle
                                      : Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _photo != null
                                      ? 'Photo Added'
                                      : 'Click Photo',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickVideo,
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.urgentRed,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _video != null
                                      ? Icons.check_circle
                                      : Icons.videocam_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _video != null
                                      ? 'Video Added'
                                      : 'Record Video',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms),

                  if (_photo != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isAnalyzing ? null : _analyzeImage,
                        icon: _isAnalyzing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          _isAnalyzing ? 'Analyzing...' : 'Analyze with AI',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.greenAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                  ],

                  const SizedBox(height: 8),
                  if (_isVerifying)
                    const LinearProgressIndicator()
                  else
                    _buildVerificationWarning(),

                  const SizedBox(height: 20),

                  Text(
                    'Category',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat['value'];
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat['value']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.navyPrimary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.navyPrimary
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat['icon'] as IconData,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cat['label'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 20),
                  _buildLocationSection(),
                  const SizedBox(height: 20),
                  _buildDescriptionSection(),
                  const SizedBox(height: 20),
                  _buildMapPreview(),
                  const SizedBox(height: 24),
                  _buildSubmitButtons(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Location (Read Only)',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.greenAccent,
              ),
            ),
            const Spacer(),
            if (_locationFetched)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Auto Fetch',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle,
                    color: AppColors.greenAccent,
                    size: 16,
                  ),
                ],
              )
            else
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                _address ?? 'Fetching location...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_latitude != null && _longitude != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Lat: ${_latitude!.toStringAsFixed(6)} | Lng: ${_longitude!.toStringAsFixed(6)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.navyPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write briefly about the Issue',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 350.ms);
  }

  Widget _buildMapPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Live Map',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.greenAccent,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 160,
            child: _latitude != null
                ? MapLibreMap(
                    styleString: 'https://tiles.openfreemap.org/styles/liberty',
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_latitude!, _longitude!),
                      zoom: 15,
                    ),
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    myLocationEnabled: false,
                    onStyleLoadedCallback: () async {
                      if (_mapController != null) {
                        await _mapController!.addCircle(
                          CircleOptions(
                            geometry: LatLng(_latitude!, _longitude!),
                            circleColor: '#FF0000',
                            circleRadius: 8,
                            circleOpacity: 1.0,
                            circleStrokeWidth: 2,
                            circleStrokeColor: '#FFFFFF',
                            circleStrokeOpacity: 1.0,
                          ),
                        );
                      }
                    },
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                  )
                : Container(
                    color: AppColors.surface,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildSubmitButtons() {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            text: 'Submit',
            onPressed: () => _submit(),
            isLoading: _isSubmitting,
            backgroundColor: AppColors.greenAccent,
            icon: Icons.send_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            text: 'Draft',
            onPressed: () => _submit(isDraft: true),
            isOutlined: true,
            icon: Icons.drafts_rounded,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }
}

class _AnalysisResultSheet extends StatelessWidget {
  final ImageAnalysisResult result;
  final VoidCallback onApply;

  const _AnalysisResultSheet({required this.result, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.navyPrimary),
              const SizedBox(width: 8),
              Text(
                'AI Analysis Results',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (result.title.isNotEmpty) ...[
            Text(
              'Title',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Description',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(result.description, style: GoogleFonts.inter(fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildChip('Category: ${result.category}', Icons.category),
              const SizedBox(width: 8),
              _buildChip('Severity: ${result.severity}', Icons.priority_high),
            ],
          ),
          if (result.hasLowConfidence) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.orange.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI confidence is low. Please verify the information before submitting.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (result.extractedText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Detected Text',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: result.extractedText
                  .map(
                    (text) => Chip(
                      label: Text(text, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.greenAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navyPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.navyPrimary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.navyPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
