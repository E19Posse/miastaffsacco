class AppNotification {
  final int    id;
  final String type;
  final String title;
  final String message;
  final bool   isRead;
  final String? link;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.link,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id:        j['id'] as int,
    type:      j['type'] as String? ?? 'general',
    title:     j['title'] as String? ?? '',
    message:   j['message'] as String? ?? '',
    isRead:    j['is_read'] as bool? ?? false,
    link:      j['link'] as String?,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}
