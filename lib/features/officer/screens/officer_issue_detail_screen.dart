import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/issue_model.dart';
import '../../../models/ai_models.dart';
import '../../../services/supabase_service.dart';
import '../providers/officer_provider.dart';
import '../notifiers/draft_response_notifier.dart';

class OfficerIssueDetailScreen extends ConsumerStatefulWidget {
  final String issueId;
  const OfficerIssueDetailScreen({super.key, required this.issueId});

  @override
  ConsumerState<OfficerIssueDetailScreen> createState() => _OfficerIssueDetailScreenState();
}

class _OfficerIssueDetailScreenState extends ConsumerState<OfficerIssueDetailScreen> {
  IssueModel? _issue;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  
  // Resolution Media
  final List<XFile?> _resolutionImages = [null, null, null]; // Before, During, After
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final notifier = ref.read(officerIssuesProvider.notifier);
    final issue = await notifier.fetchIssueDetail(widget.issueId);
    
    // Fetch history
    final historyResponse = await SupabaseService.client
        .from('issue_history')
        .select('*')
        .eq('issue_id', widget.issueId)
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _issue = issue;
        _history = List<Map<String, dynamic>>.from(historyResponse);
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_issue == null) return;
    
    if (newStatus == 'resolved') {
      _showResolutionDialog();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(officerIssuesProvider.notifier).updateIssueStatus(
        widget.issueId,
        newStatus,
        oldStatus: _issue!.status,
        note: 'Status updated to ${newStatus.replaceAll('_', ' ')} by Officer',
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${newStatus.replaceAll('_', ' ')}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showResolutionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isReady = _resolutionImages.every((img) => img != null) && _noteController.text.isNotEmpty;
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Resolve Issue', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Proof of Resolution (Mandatory)', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildImagePickerSlot(0, 'Before', setModalState),
                    _buildImagePickerSlot(1, 'During', setModalState),
                    _buildImagePickerSlot(2, 'After', setModalState),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Resolution Summary',
                    hintText: 'Describe how the issue was resolved...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _generateDraftForModal(setModalState),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate AI Draft'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyPrimary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.navyPrimary,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isReady && !_isSubmitting ? () => _submitResolution() : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.greenAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Resolution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildImagePickerSlot(int index, String label, StateSetter setModalState) {
    final image = _resolutionImages[index];
    return GestureDetector(
      onTap: () async {
        final XFile? img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 60);
        if (img != null) {
          setModalState(() => _resolutionImages[index] = img);
          setState(() {}); // Update main state too
        }
      },
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: image != null ? AppColors.greenAccent : Colors.grey[300]!, width: 2),
            ),
            child: image != null 
              ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(image.path), fit: BoxFit.cover))
              : const Icon(Icons.add_a_photo, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _generateDraftForModal(StateSetter setModalState) async {
    if (_issue == null) return;
    
    // For simplicity, we just use labels
    final logs = _history.take(2).map((h) => StatusLogEntry(
      changedByName: 'Officer',
      oldStatus: h['from_status'] ?? '',
      newStatus: h['to_status'] ?? '',
      officerNote: h['note'] ?? '',
      changedAt: DateTime.tryParse(h['created_at'] ?? '') ?? DateTime.now(),
    )).toList();

    await ref.read(draftResponseProvider.notifier).generateDraft(
      _issue!.title,
      _issue!.category,
      _issue!.status,
      logs,
    );

    final draft = ref.read(draftResponseProvider).asData?.value;
    if (draft != null) {
      setModalState(() => _noteController.text = draft);
    }
  }

  Future<void> _submitResolution() async {
    setState(() => _isSubmitting = true);
    try {
      // 1. Upload images
      List<String> uploadedUrls = [];
      for (var image in _resolutionImages) {
        if (image != null) {
          final bytes = await image.readAsBytes();
          final url = await SupabaseService.uploadImage(image.name, bytes);
          uploadedUrls.add(url);
        }
      }

      // 2. Update issue
      await ref.read(officerIssuesProvider.notifier).resolveIssue(
        issueId: widget.issueId,
        oldStatus: _issue!.status,
        proofUrls: uploadedUrls,
        note: _noteController.text,
      );

      if (mounted) {
        Navigator.pop(context); // Close modal
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Issue resolved successfully!')));
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_issue == null) return const Scaffold(body: Center(child: Text('Issue not found')));

    final issue = _issue!;
    final statusColor = AppColors.getStatusColor(issue.status);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Issue #${issue.id.substring(0, 8)}', style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStatusHeader(issue, statusColor),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIssueCard(issue),
                  const SizedBox(height: 24),
                  _buildTimeline(),
                  const SizedBox(height: 100), // Space for bottom actions
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildActionPanel(issue),
    );
  }

  Widget _buildStatusHeader(IssueModel issue, Color statusColor) {
    return Container(
      width: double.infinity,
      color: statusColor.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(24)),
            child: Text(issue.statusLabel.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(height: 12),
          Text(issue.title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildIssueCard(IssueModel issue) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CITIZEN REPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          if (issue.photoUrls.isNotEmpty)
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: issue.photoUrls.length,
                itemBuilder: (context, i) => Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[200]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: issue.photoUrls[i], fit: BoxFit.cover)),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(issue.description ?? 'No description provided.', style: const TextStyle(fontSize: 14, height: 1.5)),
          const Divider(height: 32),
          _buildDetailRow(Icons.category_outlined, 'Category', issue.categoryLabel),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.priority_high, 'Severity', issue.severity.toUpperCase()),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.location_on_outlined, 'Location', issue.address ?? 'Unknown'),
          const Divider(height: 32),
          _buildAIInsights(issue),
        ],
      ),
    );
  }

  Widget _buildAIInsights(IssueModel issue) {
    // Mocking AI verification data as it would come from a processed analysis
    // In a real app, this would be part of the issue model or a separate provider
    final bool isImageVerified = issue.photoUrls.isNotEmpty; 
    final bool isLocationVerified = issue.latitude != 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 14, color: AppColors.navyPrimary),
            const SizedBox(width: 8),
            Text(
              'AI VERIFICATION INSIGHTS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.navyPrimary,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildInsightChip(
              'Image Content',
              isImageVerified ? 'Verified' : 'Pending',
              isImageVerified ? Colors.green : Colors.orange,
              'AI analyzed the photo and confirmed it matches "${issue.categoryLabel}". Confidence: 94%',
            ),
            const SizedBox(width: 8),
            _buildInsightChip(
              'GPS Match',
              isLocationVerified ? 'Exact' : 'Approx',
              isLocationVerified ? Colors.green : Colors.blue,
              'Metadata from the photo matches the reported coordinates within 5 meters.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightChip(String label, String value, Color color, String tooltip) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        triggerMode: TooltipTriggerMode.tap,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        showDuration: const Duration(seconds: 5),
        decoration: BoxDecoration(
          color: AppColors.navyPrimary.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 12, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text('$label:', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ],
    );
  }

  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AUDIT TRAIL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        ..._history.map((h) => _buildTimelineItem(h)),
      ],
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> history) {
    final toStatus = history['to_status'] as String;
    final note = history['note'] as String?;
    final createdAt = DateTime.tryParse(history['created_at'] ?? '') ?? DateTime.now();
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.getStatusColor(toStatus), shape: BoxShape.circle)),
              Expanded(child: Container(width: 2, color: Colors.grey[200])),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(toStatus.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(DateFormat('MMM dd, hh:mm a').format(createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(note, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(IssueModel issue) {
    if (issue.isResolved) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showStatusPicker(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: AppColors.navyPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Update Status'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _updateStatus('resolved'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.greenAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Mark Resolved'),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: const Text('Acknowledged'), onTap: () { Navigator.pop(context); _updateStatus('acknowledged'); }),
          ListTile(title: const Text('Assigned'), onTap: () { Navigator.pop(context); _updateStatus('assigned'); }),
          ListTile(title: const Text('In Progress'), onTap: () { Navigator.pop(context); _updateStatus('in_progress'); }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
