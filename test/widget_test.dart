import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/domain/models/community_post.dart';

void main() {
  test('CommunityPost toMap includes userId and omits title', () {
    const post = CommunityPost(
      id: '1',
      userId: 'user-abc',
      body: 'Maize looking good this season.',
      author: 'Kofi',
      timestamp: 1700000000000,
    );

    final map = post.toMap();

    expect(map['userId'], 'user-abc');
    expect(map['body'], 'Maize looking good this season.');
    expect(map.containsKey('title'), isFalse);
  });

  test('CommunityPost fromMap reads legacy title as body fallback', () {
    final post = CommunityPost.fromMap({
      'title': 'Legacy title only',
      'author': 'Ama',
      'timestamp': 1000,
    }, 'doc1');

    expect(post.body, 'Legacy title only');
    expect(post.userId, '');
  });
}
