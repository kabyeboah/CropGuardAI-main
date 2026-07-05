import 'package:in_app_review/in_app_review.dart';

class InAppReviewHelper {
  static final InAppReview _inAppReview = InAppReview.instance;

  static Future<void> requestReview() async {
    if (await _inAppReview.isAvailable()) {
      await _inAppReview.requestReview();
    }
  }

  static Future<void> openStoreListing() async {
    await _inAppReview.openStoreListing(
      // Replace with actual app ID when available
      // appStoreId: '...',
      // microsoftStoreId: '...',
    );
  }
}
