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
import '../../../models/orchestration_result.dart';
import '../../../models/confidence_tier.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/verification_service.dart';
import '../notifiers/orchestration_notifier.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/voice_recorder_button.dart';
import '../widgets/orchestration_result_sheet.dart';

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
  Uint8List? _audioBytes;
  OrchestrationResult? _orchestrationResult;
  ConfidenceTier? _aiConfidenceTier;
  double? _aiConfidence;
  String? _aiLocationHint;
  // ignore: unused_field
  List<String> _aiSecondaryIssues = [];
  // ignore: unused_field
  List<String> _aiTags = [];

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
    {
      'value': 'damaged_road_divider',
      'label': 'Divider',
      'icon': Icons.traffic,
    },
    {
      'value': 'broken_footpath',
      'label': 'Footpath',
      'icon': Icons.directions_walk,
    },
    {
      'value': 'construction_debris',
      'label': 'Debris',
      'icon': Icons.construction,
    },
    {'value': 'illegal_dumping', 'label': 'Dumping', 'icon': Icons.no_crash},
    {
      'value': 'traffic_signal_issue',
      'label': 'Signal',
      'icon': Icons.traffic_outlined,
    },
    {'value': 'road_crack', 'label': 'Road Crack', 'icon': Icons.add_road},
    {'value': 'drainage_blockage', 'label': 'Drainage', 'icon': Icons.water},
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
      await _runOrchestration();
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

      if (mounted) {
        setState(() {
          _showVerificationWarning = result.hasIssues;
          _verificationWarningMessage = result.failureReason;
          _verificationConfidence = result.confidence;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _runOrchestration() async {
    if (_photoBytes == null) return;

    setState(() => _isAnalyzing = true);

    try {
      await ref
          .read(orchestrationProvider.notifier)
          .analyzeReport(
            imageBytes: _photoBytes!,
            audioBytes: _audioBytes,
            userText: _descriptionController.text.trim().isNotEmpty
                ? _descriptionController.text.trim()
                : null,
            latitude: _latitude,
            longitude: _longitude,
            locale: Platform.localeName,
          );

      if (!mounted) return;
      final resultAsync = ref.read(orchestrationProvider);
      final result = resultAsync is AsyncData<OrchestrationResult?>
          ? resultAsync.value
          : null;

      if (result != null && mounted) {
        _showOrchestrationResult(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI analysis failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showOrchestrationResult(OrchestrationResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrchestrationResultSheet(
        result: result,
        onApply: () {
          setState(() {
            _orchestrationResult = result;
            _aiConfidenceTier = result.confidenceTier;
            _aiConfidence = result.confidence;
            _aiLocationHint = result.locationHint;
            _aiSecondaryIssues = result.secondaryIssues;
            _aiTags = result.tags;
            if (result.description.isNotEmpty) {
              _descriptionController.text = result.description;
            }
            _selectedCategory = _mapAiCategory(result.category);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _onRecordingComplete(Uint8List? audioBytes) {
    setState(() => _audioBytes = audioBytes);
  }

  String _mapAiCategory(String aiCategory) {
    final normalized = aiCategory.toLowerCase().trim();

    final exactMap = {
      'pothole': 'pothole',
      'road_crack': 'road_crack',
      'road': 'pothole',
      'damaged_road': 'pothole',
      'broken_streetlight': 'broken_streetlight',
      'streetlight': 'broken_streetlight',
      'electricity': 'broken_streetlight',
      'power': 'broken_streetlight',
      'waterlogging': 'waterlogging',
      'water': 'waterlogging',
      'water_supply': 'waterlogging',
      'flooding': 'waterlogging',
      'drainage_blockage': 'drainage_blockage',
      'sewage_leak': 'sewage_leak',
      'sewage': 'sewage_leak',
      'sanitation': 'sanitation',
      'garbage_overflow': 'garbage_overflow',
      'garbage': 'garbage_overflow',
      'waste': 'garbage_overflow',
      'illegal_dumping': 'illegal_dumping',
      'construction_debris': 'construction_debris',
      'open_manhole': 'open_manhole',
      'manhole': 'open_manhole',
      'encroachment': 'encroachment',
      'encroach': 'encroachment',
      'damaged_road_divider': 'damaged_road_divider',
      'broken_footpath': 'broken_footpath',
      'footpath': 'broken_footpath',
      'sidewalk': 'broken_footpath',
      'traffic_signal_issue': 'traffic_signal_issue',
      'traffic': 'traffic_signal_issue',
      'signal': 'traffic_signal_issue',
      'other': 'other',
    };

    if (exactMap.containsKey(normalized)) {
      return exactMap[normalized]!;
    }

    if (normalized.contains('pothole') || normalized.contains('crack')) {
      return normalized.contains('crack') ? 'road_crack' : 'pothole';
    }
    if (normalized.contains('water') || normalized.contains('flood')) {
      return normalized.contains('drain')
          ? 'drainage_blockage'
          : 'waterlogging';
    }
    if (normalized.contains('light') || normalized.contains('electric')) {
      return 'broken_streetlight';
    }
    if (normalized.contains('sewage') || normalized.contains('sewer')) {
      return 'sewage_leak';
    }
    if (normalized.contains('garbage') ||
        normalized.contains('trash') ||
        normalized.contains('dump')) {
      return normalized.contains('illegal')
          ? 'illegal_dumping'
          : 'garbage_overflow';
    }
    if (normalized.contains('manhole') || normalized.contains('drain cover')) {
      return 'open_manhole';
    }
    if (normalized.contains('divider') || normalized.contains('median')) {
      return 'damaged_road_divider';
    }
    if (normalized.contains('footpath') ||
        normalized.contains('sidewalk') ||
        normalized.contains('pavement')) {
      return 'broken_footpath';
    }
    if (normalized.contains('traffic') || normalized.contains('signal')) {
      return 'traffic_signal_issue';
    }
    if (normalized.contains('debris') || normalized.contains('construction')) {
      return 'construction_debris';
    }
    if (normalized.contains('encroach')) {
      return 'encroachment';
    }

    return 'other';
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

      final issueData = {
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
      };

      if (_orchestrationResult != null) {
        issueData['ai_confidence'] = _orchestrationResult!.confidence;
        issueData['ai_confidence_tier'] =
            _orchestrationResult!.confidenceTier.value;
        issueData['ai_secondary_issues'] =
            _orchestrationResult!.secondaryIssues;
        if (_orchestrationResult!.locationHint.isNotEmpty) {
          issueData['ai_location_hint'] = _orchestrationResult!.locationHint;
        }
        if (_orchestrationResult!.visionSummary.isNotEmpty) {
          issueData['ai_vision_summary'] = _orchestrationResult!.visionSummary;
        }
        issueData['ai_extracted_text'] = _orchestrationResult!.extractedText;
        issueData['ai_warnings'] = _orchestrationResult!.warnings;
      }

      await SupabaseService.createIssue(issueData);

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      });
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

                  const SizedBox(height: 12),
                  VoiceRecorderButton(
                    onRecordingComplete: _onRecordingComplete,
                  ),

                  if (_photo != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isAnalyzing ? null : _runOrchestration,
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

                  if (_isAnalyzing) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'AI is analyzing your report...',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  if (_aiConfidenceTier != null && _aiConfidence != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ConfidenceBadge(
                          tier: _aiConfidenceTier!,
                          confidence: _aiConfidence!,
                        ),
                        const SizedBox(width: 8),
                        if (_orchestrationResult?.requiresImmediateAction ==
                            true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.urgentRed.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  size: 14,
                                  color: AppColors.urgentRed,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Urgent',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.urgentRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
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
                  if (_aiLocationHint != null &&
                      _aiLocationHint!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.navyPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.navyPrimary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.navyPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AI detected: $_aiLocationHint',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      final controller = _mapController;
                      if (controller != null && mounted && _latitude != null) {
                        try {
                          await controller.addCircle(
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
                        } catch (_) {}
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
