class ComplaintModel {
  final String id;
  final String userId;
  final String issueId;
  final String content;
  final String status;
  final DateTime createdAt;

  ComplaintModel({
    required this.id,
    required this.userId,
    required this.issueId,
    required this.content,
    required this.status,
    required this.createdAt,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'],
      userId: json['user_id'],
      issueId: json['issue_id'],
      content: json['content'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'issue_id': issueId,
      'content': content,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
