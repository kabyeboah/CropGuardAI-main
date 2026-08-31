/// Community feed post (body-only; images stored as HTTPS URLs).
class CommunityPost {
  final String id;
  final String userId;
  final String body;
  final String author;
  final String tag;
  final String? imageUri;
  final String? expertResponse;
  final int timestamp;

  /// UI-only sync state: 'pending', 'syncing', 'synced', 'failed'.
  final String? syncStatus;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.body,
    required this.author,
    this.tag = 'General',
    this.imageUri,
    this.expertResponse,
    required this.timestamp,
    this.syncStatus,
  });

  factory CommunityPost.fromMap(Map<String, dynamic> map, String id,
      {String? syncStatus}) {
    return CommunityPost(
      id: id,
      userId: map['userId'] as String? ?? '',
      body: map['body'] as String? ?? map['title'] as String? ?? '',
      author: map['author'] as String? ?? 'Anonymous',
      tag: map['tag'] as String? ?? 'General',
      imageUri: map['imageUri'] as String?,
      expertResponse: map['expertResponse'] as String?,
      timestamp: (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      syncStatus: syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'body': body,
      'author': author,
      'tag': tag,
      if (imageUri != null) 'imageUri': imageUri,
      if (expertResponse != null) 'expertResponse': expertResponse,
      'timestamp': timestamp,
    };
  }

  CommunityPost copyWith({
    String? id,
    String? userId,
    String? body,
    String? author,
    String? tag,
    String? imageUri,
    String? expertResponse,
    int? timestamp,
    String? syncStatus,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      body: body ?? this.body,
      author: author ?? this.author,
      tag: tag ?? this.tag,
      imageUri: imageUri ?? this.imageUri,
      expertResponse: expertResponse ?? this.expertResponse,
      timestamp: timestamp ?? this.timestamp,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
