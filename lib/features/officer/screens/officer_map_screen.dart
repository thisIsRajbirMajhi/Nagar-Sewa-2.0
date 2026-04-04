import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
        _currentPosition = const LatLng(20.5937, 78.9629); // India center
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

  Future<void> _updateMapFeatures() async {
    if (_mapController == null) return;
    
    final issuesAsync = ref.read(officerIssuesProvider);
    if (!issuesAsync.hasValue) return;

    await _mapController!.clearCircles();
    _circleToIssueMap.clear();

    final issues = issuesAsync.value!;
    final filteredIssues = issues.where((i) {
      if (i.isResolved) return false;
      if (_selectedCategory != null && i.category != _selectedCategory) return false;
      return true;
    }).toList();

    for (final issue in filteredIssues) {
      final color = _categoryColors[issue.category] ?? AppColors.catOther;
      final hexColor = '#${color.toARGB32().toRadixString(16).substring(2).padLeft(6, '0')}';

      // Higher radius for priority issues
      double radius = 10;
      if (issue.upvoteCount > 50) radius = 14;
      if (issue.upvoteCount > 100) radius = 18;

      final circle = await _mapController!.addCircle(
        CircleOptions(
          geometry: LatLng(issue.latitude, issue.longitude),
          circleColor: hexColor,
          circleRadius: radius,
          circleOpacity: 0.8,
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

    // Trigger update when issues change
    if (issuesAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateMapFeatures());
    }

    return Scaffold(
      body: Stack(
        children: [
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
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, color: AppColors.navyPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Officer Map View', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        Text(
                          issuesAsync.when(
                            data: (list) => '${list.where((i) => !i.isResolved).length} pending tasks',
                            loading: () => 'Loading tasks...',
                            error: (e, st) => 'Error loading tasks',
                          ),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Category filter
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip(null, 'All', Icons.layers),
                  ..._categoryColors.entries.map((e) => _buildFilterChip(e.key, e.key.replaceAll('_', ' ').toUpperCase(), _categoryIcons[e.key] ?? Icons.info)),
                ],
              ),
            ),
          ),

          // Re-center button
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 14));
                }
              },
              backgroundColor: Colors.white,
              child: Icon(Icons.my_location, color: AppColors.navyPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black)),
        onSelected: (val) {
          setState(() => _selectedCategory = val ? category : null);
          _updateMapFeatures();
        },
        backgroundColor: Colors.white,
        selectedColor: AppColors.navyPrimary,
        elevation: 2,
      ),
    );
  }

  void _showIssuePreview(IssueModel issue) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(issue.title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(issue.categoryLabel, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.getStatusColor(issue.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    issue.statusLabel.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.getStatusColor(issue.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.arrow_upward, size: 16, color: AppColors.navyPrimary),
                const SizedBox(width: 4),
                Text('${issue.upvoteCount} upvotes', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(DateFormat('MMM dd').format(issue.createdAt), style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/issue/${issue.id}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('View Official Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
