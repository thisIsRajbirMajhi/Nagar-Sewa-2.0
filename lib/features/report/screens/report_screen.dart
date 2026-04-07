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
import '../../../services/location_service.dart';
import '../../../services/supabase_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
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

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;

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
    _initSpeech();
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

  Future<void> _initSpeech() async {
    bool available = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done') {
          setState(() => _isListening = false);
        }
      },
      onError: (val) => debugPrint('onError: $val'),
    );
    if (!available) {
      debugPrint("Speech recognition not available");
    }
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (val) {
            setState(() {
              _descriptionController.text = val.recognizedWords;
            });
          },
        );
      } else {
        await Permission.microphone.request();
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
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
    }
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );
    if (file != null) {
      setState(() => _video = file);
    }
  }

  Future<void> _submit({bool isDraft = false}) async {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Waiting for location...')));
      return;
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
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.navyPrimary),
                      ),
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat['value'],
                        child: Row(
                          children: [
                            Icon(cat['icon'] as IconData, size: 20, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(cat['label'] as String),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Description',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.navyPrimary,
              ),
            ),
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.red : AppColors.navyPrimary,
              ),
              onPressed: _toggleListening,
              tooltip: 'Speech to Text',
            ),
          ],
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
