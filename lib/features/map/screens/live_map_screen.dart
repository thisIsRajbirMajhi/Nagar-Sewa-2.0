import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_header.dart';
import '../../../models/issue_model.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_service.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with AutomaticKeepAliveClientMixin {
  MapLibreMapController? _mapController;
  LatLng? _currentPosition;
  List<IssueModel> _nearbyIssues = [];
  bool _isLoading = true;
  StreamSubscription? _positionStream;
  String? _selectedCategory;

  final Map<String, Color> _categoryColors = {
    'pothole': AppColors.catPothole,
    'garbage_overflow': AppColors.catGarbage,
    'broken_streetlight': AppColors.catStreetlight,
    'sewage_leak': AppColors.catSewage,
    'waterlogging': AppColors.catWater,
    'damaged_road': AppColors.catRoad,
    'open_manhole': AppColors.catManhole,
  };

  final Map<String, IconData> _categoryIcons = {
    'pothole': Icons.warning_rounded,
    'garbage_overflow': Icons.delete_rounded,
    'broken_streetlight': Icons.lightbulb_outline,
    'sewage_leak': Icons.water_drop,
    'waterlogging': Icons.waves,
    'open_manhole': Icons.circle_outlined,
    'encroachment': Icons.fence,
    'other': Icons.more_horiz,
  };

  // Maps Issue ID to the MapLibre Circle Id
  final Map<String, IssueModel> _circleToIssueMap = {};

  @override
  bool get wantKeepAlive => true;

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
      await _loadNearbyIssues();

      // Listen for location changes
      _positionStream = LocationService.getPositionStream().listen((pos) {
        final newPos = LatLng(pos.latitude, pos.longitude);
        if (!mounted) return;
        if (_currentPosition != null) {
          final distance = LocationService.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            newPos.latitude,
            newPos.longitude,
          );
          if (distance > 500) {
            setState(() => _currentPosition = newPos);
            _loadNearbyIssues();
          } else {
            setState(() => _currentPosition = newPos);
          }
        } else {
          setState(() => _currentPosition = newPos);
        }
      });
    } else if (mounted) {
      // Fallback: use a default position (center of India) if location fails
      setState(() {
        _currentPosition = const LatLng(20.5937, 78.9629);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNearbyIssues() async {
    if (_currentPosition == null) return;
    setState(() => _isLoading = true);
    try {
      final issues = await SupabaseService.getNearbyIssues(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        5.0, // Strict 5km radius
      );
      if (mounted) {
        setState(() {
          _nearbyIssues = issues;
          _isLoading = false;
        });
        _updateMapFeatures();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _updateMapFeatures() async {
    if (_mapController == null) return;
    try {
      await _mapController!.clearCircles();
      await _mapController!.clearFills();
      _circleToIssueMap.clear();

      // Draw the 5km radius Fill
      if (_currentPosition != null) {
        final polygon = _createCirclePolygon(_currentPosition!, 5000);
        await _mapController!.addFill(
          FillOptions(
            geometry: [polygon],
            fillColor: '#ADD8E6', // Light blue fill
            fillOpacity: 0.15,
            fillOutlineColor: '#0000FF',
          ),
        );
      }

      // Draw Issue circles
      for (final issue in _filteredIssues) {
        final color = _categoryColors[issue.category] ?? AppColors.catOther;
        final hexColor =
            '#${color.toARGB32().toRadixString(16).substring(2).padLeft(6, '0')}';

        final circle = await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(issue.latitude, issue.longitude),
            circleColor: hexColor,
            circleRadius: 10,
            circleOpacity: 1.0,
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
            circleStrokeOpacity: 1.0,
          ),
        );
        _circleToIssueMap[circle.id] = issue;
      }
    } catch (e) {
      debugPrint("Error updating map features: $e");
    }
  }

  List<LatLng> _createCirclePolygon(LatLng center, double radiusInMeters) {
    final points = <LatLng>[];
    const earthRadius = 6371000.0;
    final lat = center.latitude * math.pi / 180.0;
    final lng = center.longitude * math.pi / 180.0;

    for (int i = 0; i <= 360; i += 5) {
      final bearing = i * math.pi / 180.0;
      final endLat = math.asin(
        math.sin(lat) * math.cos(radiusInMeters / earthRadius) +
            math.cos(lat) *
                math.sin(radiusInMeters / earthRadius) *
                math.cos(bearing),
      );
      final endLng =
          lng +
          math.atan2(
            math.sin(bearing) *
                math.sin(radiusInMeters / earthRadius) *
                math.cos(lat),
            math.cos(radiusInMeters / earthRadius) -
                math.sin(lat) * math.sin(endLat),
          );
      points.add(LatLng(endLat * 180.0 / math.pi, endLng * 180.0 / math.pi));
    }
    return points;
  }

  List<IssueModel> get _filteredIssues {
    if (_selectedCategory == null) return _nearbyIssues;
    return _nearbyIssues.where((i) => i.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            userName: 'Live Map',
            subtitle: '${_nearbyIssues.length} issues within 5km',
            onMenuTap: () {},
          ),
          Expanded(
            child: _currentPosition == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Getting your location...'),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      SizedBox.expand(
                        child: MapLibreMap(
                          // OpenFreeMap URL for vector map tiles
                          styleString:
                              'https://tiles.openfreemap.org/styles/liberty',
                          initialCameraPosition: CameraPosition(
                            target: _currentPosition!,
                            zoom: 12.5,
                          ),
                          onMapCreated: _onMapCreated,
                          onStyleLoadedCallback: _onStyleLoaded,
                          myLocationEnabled: true,
                          myLocationTrackingMode: MyLocationTrackingMode.none,
                          myLocationRenderMode: MyLocationRenderMode.gps,
                          compassEnabled: true,
                          zoomGesturesEnabled: true,
                        ),
                      ),

                      // Category filter chips
                      Positioned(
                        top: 12,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              _buildFilterChip(null, 'All', Icons.layers),
                              ..._categoryColors.entries.map((entry) {
                                return _buildFilterChip(
                                  entry.key,
                                  entry.key
                                      .replaceAll('_', ' ')
                                      .split(' ')
                                      .map(
                                        (w) =>
                                            '${w[0].toUpperCase()}${w.substring(1)}',
                                      )
                                      .join(' '),
                                  _categoryIcons[entry.key] ??
                                      Icons.report_problem,
                                );
                              }),
                            ],
                          ),
                        ),
                      ),

                      // Loading indicator
                      if (_isLoading)
                        Positioned(
                          top: 56,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.shadow,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Loading issues...',
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Re-center button
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton.small(
                          onPressed: () {
                            if (_currentPosition != null &&
                                _mapController != null) {
                              _mapController!.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  _currentPosition!,
                                  12.5,
                                ),
                              );
                            }
                          },
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.my_location,
                            color: AppColors.navyPrimary,
                          ),
                        ),
                      ),

                      // Issue count chip
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navyPrimary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadow.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_filteredIssues.length} issues',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
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
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = category;
          });
          _updateMapFeatures();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.navyPrimary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.08),
                blurRadius: 4,
              ),
            ],
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
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIssuePreview(IssueModel issue) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.getCategoryColor(
                      issue.category,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _categoryIcons[issue.category] ?? Icons.report_problem,
                    color: AppColors.getCategoryColor(issue.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        issue.categoryLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.getStatusColor(issue.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    issue.statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (issue.address != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      issue.address!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/issue/${issue.id}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'View Details',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
