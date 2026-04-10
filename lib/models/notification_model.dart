class NotificationModel {
  final String id;
  final String userId;
  final String? issueId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? groupKey;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;
  final String priority;

  const NotificationModel({
    required this.id,
    required this.userId,
    this.issueId,
    required this.title,
    required this.message,
    this.type = 'info',
    this.isRead = false,
    required this.createdAt,
    this.groupKey,
    this.actionUrl,
    this.metadata,
    this.priority = 'normal',
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      issueId: json['issue_id'] as String?,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String? ?? 'info',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      groupKey: json['group_key'] as String?,
      actionUrl: json['action_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      priority: json['priority'] as String? ?? 'normal',
    );
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? issueId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    String? groupKey,
    String? actionUrl,
    Map<String, dynamic>? metadata,
    String? priority,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      issueId: issueId ?? this.issueId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      groupKey: groupKey ?? this.groupKey,
      actionUrl: actionUrl ?? this.actionUrl,
      metadata: metadata ?? this.metadata,
      priority: priority ?? this.priority,
    );
  }
}
