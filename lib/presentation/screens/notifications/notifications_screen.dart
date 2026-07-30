import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/locale_formatter.dart';
import '../../../data/local/database_helper.dart';
import '../../../domain/models/app_notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final DatabaseHelper _db = sl<DatabaseHelper>();
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final items = await _db.getNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = items;
      _loading = false;
    });
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    await _db.markNotificationRead(notification.id);
    await _load();
  }

  Future<void> _markAllRead() async {
    await _db.markNotificationsAsRead();
    await _load();
  }

  Future<void> _delete(String id) async {
    await _db.deleteNotification(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unread = _notifications.where((n) => !n.isRead).length;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          leading: Navigator.of(context).canPop()
              ? BackButton(onPressed: () => Navigator.of(context).pop())
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/home'),
                ),
        backgroundColor: colors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.notifications, style: Theme.of(context).textTheme.titleLarge),
            if (unread > 0)
              Text(
                context.l10n.unreadCount(unread),
                style: TextStyle(color: colors.primary, fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                context.l10n.markAllRead,
                style: TextStyle(color: colors.primary, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 0, color: colors.divider),
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      return Dismissible(
                        key: ValueKey(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: colors.diseaseRed.withValues(alpha: 0.12),
                          child: Icon(Icons.delete_outline,
                              color: colors.diseaseRed),
                        ),
                        onDismissed: (_) => _delete(n.id),
                        child: InkWell(
                          onTap: () => _markRead(n),
                          child: Container(
                            color: n.isRead
                                ? Colors.transparent
                                : colors.primary.withValues(alpha: 0.05),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: _typeColor(n.type, colors)
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _typeIcon(n.type),
                                    size: 20,
                                    color: _typeColor(n.type, colors),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              n.title,
                                              style: TextStyle(
                                                fontWeight: n.isRead
                                                    ? FontWeight.normal
                                                    : FontWeight.bold,
                                                color: colors.onBackground,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _timeAgo(n.createdAt, context),
                                            style: TextStyle(
                                              color: colors.muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        n.body,
                                        style: TextStyle(
                                          color: colors.onBackgroundSecondary,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (!n.isRead)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(left: 8, top: 4),
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: colors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }

  Color _typeColor(String type, dynamic colors) {
    switch (type) {
      case 'reminder':
        return colors.primary as Color;
      case 'alert':
        return colors.diseaseRed as Color;
      default:
        return colors.healthy as Color;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'reminder':
        return Icons.alarm_rounded;
      case 'alert':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _timeAgo(DateTime createdAt, BuildContext context) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return LocaleFormatter.formatMonthDay(context, createdAt);
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 72, color: colors.border),
          const SizedBox(height: 12),
          Text(context.l10n.noNotificationsYet,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            context.l10n.notificationsEmptyDesc,
            style: TextStyle(color: colors.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
