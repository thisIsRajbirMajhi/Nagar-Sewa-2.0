import 'package:intl/intl.dart';
import '../models/ai_models.dart';

class LocalDraftService {
  static String generateDraft({
    required String issueTitle,
    required String category,
    required String currentStatus,
    required List<StatusLogEntry> lastTwoLogs,
  }) {
    final categoryLabel = _getCategoryLabel(category);
    final statusLabel = _getStatusLabel(currentStatus);
    final now = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

    String timelineText = '';
    if (lastTwoLogs.isNotEmpty) {
      final entries = lastTwoLogs
          .map((log) {
            final date = DateFormat('dd MMM yyyy').format(log.changedAt);
            final note = log.officerNote.isNotEmpty
                ? log.officerNote
                : 'Status changed to ${log.newStatus}';
            return '- $date: $note';
          })
          .join('\n');
      timelineText = '\n\nRecent Updates:\n$entries';
    }

    final templates = {
      'pothole':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Our team has assessed the reported $categoryLabel and scheduled repair work. The affected area will be filled and resurfaced using standard road repair materials.

Current Status: $statusLabel$timelineText

Expected completion will be communicated shortly. We appreciate your patience and civic responsibility.

Regards,
Municipal Works Department
Generated: $now''',

      'garbage_overflow':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

A sanitation crew has been dispatched to clear the overflowing garbage. The area will be cleaned and sanitized, and additional waste bins will be placed if needed.

Current Status: $statusLabel$timelineText

We are committed to maintaining cleanliness in your area.

Regards,
Sanitation Department
Generated: $now''',

      'broken_streetlight':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Our electrical maintenance team has been notified. The faulty streetlight will be inspected and repaired or replaced as required.

Current Status: $statusLabel$timelineText

Safety is our priority. We will resolve this promptly.

Regards,
Electrical Maintenance Department
Generated: $now''',

      'sewage_leak':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

This has been classified as a priority matter. A sewage maintenance team has been dispatched to assess and repair the leak.

Current Status: $statusLabel$timelineText

We understand the inconvenience and are working to resolve this urgently.

Regards,
Water & Sewage Department
Generated: $now''',

      'waterlogging':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Our drainage team has been notified. The blocked drains will be cleared and waterlogging will be addressed.

Current Status: $statusLabel$timelineText

We are working to restore normal drainage in your area.

Regards,
Drainage Department
Generated: $now''',

      'open_manhole':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

This is a safety-critical issue. A team has been dispatched immediately to secure the area and replace the missing manhole cover.

Current Status: $statusLabel$timelineText

Your report helps prevent accidents. Thank you.

Regards,
Municipal Works Department
Generated: $now''',

      'encroachment':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

The encroachment complaint has been forwarded to the relevant department for inspection and appropriate action.

Current Status: $statusLabel$timelineText

We will keep you updated on the progress.

Regards,
Town Planning Department
Generated: $now''',
    };

    return templates[category] ??
        '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Your complaint has been received and is being processed by the relevant department.

Current Status: $statusLabel$timelineText

We will keep you updated on the progress.

Regards,
NagarSewa Team
Generated: $now''';
  }

  static String _getCategoryLabel(String category) {
    const labels = {
      'pothole': 'pothole/road damage',
      'garbage_overflow': 'garbage overflow',
      'broken_streetlight': 'broken streetlight',
      'sewage_leak': 'sewage leak',
      'open_manhole': 'open manhole',
      'waterlogging': 'waterlogging',
      'encroachment': 'encroachment',
      'damaged_road': 'road damage',
      'sanitation': 'sanitation issue',
      'electricity': 'electrical issue',
      'water': 'water supply issue',
      'road': 'road issue',
      'other': 'reported issue',
    };
    return labels[category] ?? 'reported issue';
  }

  static String _getStatusLabel(String status) {
    const labels = {
      'submitted': 'Submitted and awaiting review',
      'ai_verified': 'AI Verified and queued for processing',
      'assigned': 'Assigned to department',
      'acknowledged': 'Acknowledged by department',
      'in_progress': 'Work in progress',
      'resolved': 'Marked as resolved',
      'citizen_confirmed': 'Confirmed by citizen',
      'closed': 'Issue closed',
      'rejected': 'Rejected after review',
    };
    return labels[status] ?? status;
  }
}
