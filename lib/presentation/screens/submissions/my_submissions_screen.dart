import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/locale_formatter.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/local/pending_sync_queue.dart';
import '../../../data/remote/firebase_auth_service.dart';
import '../../../data/remote/firestore_service.dart';
import '../../components/cropguard_card.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  final FirestoreService _firestore = sl<FirestoreService>();
  final FirebaseAuthService _auth = sl<FirebaseAuthService>();
  final DatabaseHelper _db = sl<DatabaseHelper>();

  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final userId = _auth.currentUserId;

    List<Map<String, dynamic>> items = [];
    String? fetchError;

    try {
      if (userId.isNotEmpty && userId != 'guest') {
        try {
          final expertReqs = await _firestore.getUserExpertRequests(userId);
          final missingCrops = await _firestore.getUserMissingCrops(userId);
          items.addAll(expertReqs);
          items.addAll(missingCrops);
        } catch (_) {
          fetchError = 'Unable to load submissions. Please check your network connection.';
        }
      }

      // Also include pending offline queue items for expertRequest & cropNotFound
      try {
        final db = await _db.database;
        final pendingRows = await PendingSyncQueue.getPendingItems(db);
        for (final row in pendingRows) {
          final type = row['type'] as String;
          final status = row['status'] as String? ?? 'pending';
          // Skip types that have their own Firestore surface (community posts are
          // shown in the feed; outbreak/feedback have no submissions screen).
          if (type == PendingSyncType.expertRequest.name) {
            items.add({
              'type': 'expert_request',
              'diseaseName': 'Expert Consultation (Queued)',
              'message': 'Queued offline submission',
              'status': status == 'abandoned' ? 'delivery_failed' : 'pending_sync',
              'timestamp': DateTime.now(),
            });
          } else if (type == PendingSyncType.cropNotFound.name) {
            items.add({
              'type': 'missing_crop',
              'suggestedCrop': 'Missing Crop Report (Queued)',
              'observedSymptoms': 'Queued offline submission',
              'status': status == 'abandoned' ? 'delivery_failed' : 'pending_sync',
              'timestamp': DateTime.now(),
            });
          }
        }
      } catch (_) {}

      // Sort descending by timestamp
      items.sort((a, b) {
        final dtA = _parseDate(a['timestamp']);
        final dtB = _parseDate(b['timestamp']);
        return dtB.compareTo(dtA);
      });
    } catch (e) {
      fetchError ??= 'Unable to load submissions: $e';
    } finally {
      if (mounted) {
        setState(() {
          _submissions = items;
          _errorMessage = fetchError;
          _isLoading = false;
        });
      }
    }
  }

  DateTime _parseDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/profile');
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          title: Text(
            'My Submissions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/profile');
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSubmissions,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _submissions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded,
                              size: 48, color: colors.diseaseRed),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to Load Submissions',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.muted, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadSubmissions,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _submissions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.assignment_turned_in_outlined,
                                  size: 48, color: colors.muted),
                              const SizedBox(height: 12),
                              Text(
                                'No Submissions Yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your requests for expert consultations and missing crop reports will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: colors.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSubmissions,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _submissions.length + (_errorMessage != null ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            if (_errorMessage != null && i == 0) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.diseaseRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colors.diseaseRed.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: colors.diseaseRed,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: colors.diseaseRed,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _loadSubmissions,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final itemIndex = _errorMessage != null ? i - 1 : i;
                            final item = _submissions[itemIndex];
                        final isExpert = item['type'] == 'expert_request';
                        final title = isExpert
                            ? 'Expert Consultation: ${item['diseaseName'] ?? 'Disease'}'
                            : 'Missing Crop Report: ${item['suggestedCrop'] ?? 'Crop'}';
                        final body = isExpert
                            ? (item['message'] ?? '')
                            : (item['observedSymptoms'] ?? '');
                        final dt = _parseDate(item['timestamp']);
                        final statusStr = item['status']?.toString() ?? 'review_pending';

                        return CropGuardCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isExpert
                                        ? Icons.contact_support_rounded
                                        : Icons.nature_people_rounded,
                                    size: 18,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  _StatusBadge(status: statusStr),
                                ],
                              ),
                              if (body.toString().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  body.toString(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                LocaleFormatter.formatMonthDayYear(context, dt),
                                style: TextStyle(
                                    color: colors.muted, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'completed':
      case 'resolved':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Received & Resolved';
        break;
      case 'pending_sync':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        label = 'Pending Sync';
        break;
      case 'delivery_failed':
        // Exceeded max retries — this submission will not sync automatically.
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        label = 'Delivery Failed';
        break;
      case 'review_pending':
      default:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = 'Received';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
