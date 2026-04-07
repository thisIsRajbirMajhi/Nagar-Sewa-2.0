import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/issue_model.dart';
import '../../../services/location_service.dart';
import '../providers/officer_provider.dart';


class OfficerMapScreen extends ConsumerStatefulWidget {
  const OfficerMapScreen({super.key});

  @override
  ConsumerState<OfficerMapScreen> createState() => _OfficerMapScreenState();
}

class _OfficerMapScreenState extends ConsumerState<OfficerMapScreen> {
  MapLibreMapController? _mapController;
  LatLng? _currentPosition;
  StreamSubscription? _positionStream;
  String? _selectedCategory;
  bool _showLegend = false;

  final Map<String, Color> _categoryColors = {
    'pothole': AppColors.catPothole,
    'garbage_overflow': AppColors.catGarbage,
    'broken_streetlight': AppColors.catStreetlight,
    'sewage_leak': AppColors.catSewage,
    'waterlogging': AppColors.catWater,
    'damaged_road': AppColors.catRoad,
    'open_manhole': AppColors.catManhole,
  };

  final Map<String, String> _categoryLabels = {
    'pothole': 'Pothole',
    'garbage_overflow': 'Garbage',
    'broken_streetlight': 'Streetlight',
    'sewage_leak': 'Sewage',
    'waterlogging': 'Waterlogging',
    'damaged_road': 'Road Damage',
    'open_manhole': 'Manhole',
    'encroachment': 'Encroachment',
    'other': 'Other',
  };

  final Map<String, IconData> _categoryIcons = {
    'pothole': Icons.warning_rounded,
    'garbage_overflow': Icons.delete_rounded,
    'broken_streetlight': Icons.lightbulb_outline,
    'sewage_leak': Icons.water_drop,
    'waterlogging': Icons.waves,
    'damaged_road': Icons.add_road_rounded,
    'open_manhole': Icons.circle_outlined,
    'encroachment': Icons.fence,
    'other': Icons.more_horiz,
  };

  final Map<String, IssueModel> _circleToIssueMap = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      _positionStream = LocationService.getPositionStream().listen((pos) {
        if (!mounted) return;
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
        });
      });
    } else if (mounted) {
      setState(() {
        _currentPosition = const LatLng(20.5937, 78.9629);
      });
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _mapController!.onCircleTapped.add(_onCircleTapped);
  }

  void _onStyleLoaded() {
    _updateMapFeatures();
  }

  void _onCircleTapped(Circle circle) {
    final issue = _circleToIssueMap[circle.id];
    if (issue != null) {
      _showIssuePreview(issue);
    }
  }

  /// Compute circle radius based on severity
  double _getSeverityRadius(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 16;
      case 'high':
        return 13;
      case 'medium':
        return 10;
      case 'low':
        return 8;
      default:
        return 10;
    }
  }

  Future<void> _updateMapFeatures() async {
    if (_mapController == null) return;

    final issuesAsync = ref.read(officerIssuesProvider);
    if (!issuesAsync.hasValue) return;

    await _mapController!.clearCircles();
    _circleToIssueMap.clear();

    final issues = issuesAsync.value!;
    final filteredIssues = issues.where((i) {
      if (i.isResolved) {
        return false;
      }
      if (_selectedCategory != null && i.category != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();

    for (final issue in filteredIssues) {
      final color = _categoryColors[issue.category] ?? AppColors.catOther;
      final hexColor =
          '#${color.toARGB32().toRadixString(16).substring(2).padLeft(6, '0')}';

      // Severity-based radius
      double radius = _getSeverityRadius(issue.severity);

      // Boost for high upvotes
      if (issue.upvoteCount > 50) radius += 2;
      if (issue.upvoteCount > 100) radius += 4;

      final opacity = 0.8; // Default opacity

      final circle = await _mapController!.addCircle(
        CircleOptions(
          geometry: LatLng(issue.latitude, issue.longitude),
          circleColor: hexColor,
          circleRadius: radius,
          circleOpacity: opacity,
          circleStrokeWidth: 2,
          circleStrokeColor: '#FFFFFF',
        ),
      );
      _circleToIssueMap[circle.id] = issue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(officerIssuesProvider);

    if (issuesAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateMapFeatures());
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map
          if (_currentPosition != null)
            MapLibreMap(
              styleString: 'https://tiles.openfreemap.org/styles/liberty',
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 13,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              myLocationEnabled: true,
              myLocationRenderMode: MyLocationRenderMode.gps,
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.map_rounded,
                    color: AppColors.navyPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Task Map',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          issuesAsync.when(
                            data: (list) =>
                                '${list.where((i) => !i.isResolved).length} active tasks in your area',
                            loading: () => 'Loading...',
                            error: (_, _) => 'Error loading tasks',
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Legend toggle
                  IconButton(
                    icon: Icon(
                      _showLegend ? Icons.info : Icons.info_outline_rounded,
                      color: _showLegend
                          ? AppColors.navyPrimary
                          : AppColors.textLight,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _showLegend = !_showLegend),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),
          ),

          // Category filter
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip(null, 'All', Icons.layers_rounded),
                  ..._categoryColors.entries.map(
                    (e) => _buildFilterChip(
                      e.key,
                      _categoryLabels[e.key] ?? e.key,
                      _categoryIcons[e.key] ?? Icons.info,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Legend overlay
          if (_showLegend)
            Positioned(
              top: MediaQuery.of(context).padding.top + 116,
              right: 16,
              child: _buildLegend(),
            ),

          // Bottom controls
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Re-center
                FloatingActionButton.small(
                  heroTag: 'recenter',
                  onPressed: () {
                    if (_currentPosition != null) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_currentPosition!, 14),
                      );
                    }
                  },
                  backgroundColor: AppColors.cardBg,
                  child: Icon(
                    Icons.my_location,
                    color: AppColors.navyPrimary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    final color = category != null
        ? (_categoryColors[category] ?? AppColors.catOther)
        : AppColors.navyPrimary;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedCategory = isSelected ? null : category);
          _updateMapFeatures();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 4)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legend',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Categories',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          ..._categoryColors.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _categoryLabels[e.key] ?? e.key,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Size = Severity',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.textLight,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Low',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.textLight,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Med',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.textLight,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Crit',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Opacity = AI Confidence',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.1);
  }

  void _showIssuePreview(IssueModel issue) {
    final statusColor = AppColors.getStatusColor(issue.status);
    final severityColor = _getSeverityColorForDisplay(issue.severity);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Title + Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    issue.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    issue.statusLabel.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Location
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    issue.address ?? 'Location not specified',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Meta row: severity + AI confidence + upvotes + date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    issue.severity.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: severityColor,
                    ),
                  ),
                ),

                Icon(
                  Icons.arrow_upward_rounded,
                  size: 14,
                  color: AppColors.communityOrange,
                ),
                Text(
                  '${issue.upvoteCount}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.communityOrange,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM dd').format(issue.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final lat = issue.latitude;
                      final lng = issue.longitude;
                      final url = Uri.parse(
                        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: Icon(
                      Icons.directions_rounded,
                      size: 16,
                      color: AppColors.reportedBlue,
                    ),
                    label: Text(
                      'Navigate',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.reportedBlue,
                      side: BorderSide(
                        color: AppColors.reportedBlue.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/issue/${issue.id}');
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(
                      'View Details',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColorForDisplay(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFEA580C);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF22C55E);
      default:
        return Colors.grey;
    }
  }
}
