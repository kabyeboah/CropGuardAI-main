import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../domain/models/community_post.dart';
import '../../components/cropguard_card.dart';
import '../../components/cropguard_text_field.dart';
import '../../components/offline_banner.dart';
import 'community_provider.dart';

import '../../components/voice_dictation_button.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _composerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _composerController.addListener(_onComposerChanged);
  }

  void _onComposerChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _composerController.removeListener(_onComposerChanged);
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final colors = context.colors;
    final textLength = _composerController.text.length;
    final isExceeding = textLength > InputSanitizer.communityPostMax;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          title: Text(context.l10n.community,
              style: Theme.of(context).textTheme.titleLarge),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfflineBanner(status: provider.connectionStatus),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CropGuardCard(
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: CropGuardTextField(
                              controller: _composerController,
                              label: context.l10n.shareUpdate,
                              placeholder: context.l10n.composerHint,
                            ),
                          ),
                          VoiceDictationButton(controller: _composerController),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$textLength / ${InputSanitizer.communityPostMax}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isExceeding ? colors.error : colors.muted,
                            ),
                          ),
                        ),
                      ),
                      if (provider.selectedImageUri != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: File(provider.selectedImageUri!)
                                        .existsSync()
                                    ? Image.file(
                                        File(provider.selectedImageUri!),
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : const SizedBox(
                                        height: 160,
                                        child: Center(
                                            child: Icon(Icons.broken_image)),
                                      ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: provider.clearSelectedImage,
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.close,
                                          color: Colors.white, size: 20),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (provider.isUploadingImage)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                context.l10n.uploadingImage,
                                style: TextStyle(
                                    color: colors.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: provider.isPosting ||
                                    provider.isUploadingImage
                                ? null
                                : () async {
                                    final picker = ImagePicker();
                                    final file = await picker.pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 1024,
                                      maxHeight: 1024,
                                      imageQuality: 85,
                                    );
                                    await provider.onImageSelected(file?.path);
                                  },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: colors.primary),
                              foregroundColor: colors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add_photo_alternate_outlined,
                                size: 18),
                            label: Text(context.l10n.outbreakAddPhoto,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: provider.isPosting || isExceeding
                                  ? null
                                  : () => provider.postUpdate(
                                        _composerController.text,
                                        onPosted: () {
                                          _composerController.clear();
                                        },
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: provider.isPosting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                context.l10n.post,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (provider.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: provider.clearError,
                                  child: Text(
                                    provider.errorMessage!,
                                    style: TextStyle(
                                        color: colors.error, fontSize: 12),
                                  ),
                                ),
                              ),
                              if (provider.uploadFailed)
                                TextButton(
                                  onPressed: provider.isPosting
                                      ? null
                                      : () => provider.retryPost(
                                            onPosted: () =>
                                                _composerController.clear(),
                                          ),
                                  child: Text(context.l10n.retry,
                                      style: const TextStyle(fontSize: 12)),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: provider.posts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forum_outlined,
                                  size: 48, color: colors.muted),
                              const SizedBox(height: 12),
                              Text(
                                'No posts yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Be the first to share an update with other farmers.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: colors.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.posts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _PostCard(post: provider.posts[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _relativeTimestamp(int ms) {
  final then = DateTime.fromMillisecondsSinceEpoch(ms);
  final diff = DateTime.now().difference(then);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${then.day}/${then.month}/${then.year}';
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;

  const _PostCard({required this.post});

  void _showPostOptions(BuildContext context) {
    final provider = context.read<CommunityProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: Text(context.l10n.reportPost),
                subtitle: Text(context.l10n.communityReportPostReason),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog(context, provider);
                },
              ),
              if (post.userId.isNotEmpty && !post.userId.startsWith('seed_'))
                ListTile(
                  leading: const Icon(Icons.block_outlined, color: Colors.red),
                  title: Text('${context.l10n.block} @${post.author}'),
                  subtitle: Text(context.l10n.communityBlockUserReason),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBlockConfirmation(context, provider);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, CommunityProvider provider) {
    String selectedCategory = 'Spam & Advertising';
    final customReasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: Colors.orange, size: 22),
                const SizedBox(width: 8),
                Text(context.l10n.reportPost),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why are you reporting this post?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ...[
                    'Spam & Advertising',
                    'False Agricultural Advice',
                    'Harassment / Abusive Language',
                    'Inappropriate Content',
                    'Other',
                  ].map((category) => RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(category,
                            style: const TextStyle(fontSize: 13)),
                        value: category,
                        // ignore: deprecated_member_use
                        groupValue: selectedCategory,
                        // ignore: deprecated_member_use
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedCategory = val);
                          }
                        },
                      )),
                  if (selectedCategory == 'Other')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: customReasonController,
                        maxLength: InputSanitizer.reportReasonMax,
                        decoration: const InputDecoration(
                          hintText: 'Describe the issue...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final detail = selectedCategory == 'Other'
                      ? customReasonController.text.trim()
                      : selectedCategory;
                  Navigator.pop(ctx);
                  provider.reportPost(
                    post.id,
                    category: selectedCategory,
                    reason: detail,
                  );
                },
                child: Text(context.l10n.report),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBlockConfirmation(
      BuildContext context, CommunityProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block @${post.author}?'),
        content: Text(
          'You will no longer see posts, comments, or submissions from @${post.author}. You can manage blocked users in your account settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              provider.blockUser(post.userId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Blocked @${post.author}')),
              );
            },
            child: Text(context.l10n.block),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onLongPress: () => _showPostOptions(context),
      child: CropGuardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${post.author} • ${post.tag} • ${_relativeTimestamp(post.timestamp)}',
                    style: TextStyle(color: colors.muted, fontSize: 11),
                  ),
                ),
                if (post.syncStatus != null) ...[
                  const SizedBox(width: 8),
                  _SyncStatusBadge(status: post.syncStatus!),
                ],
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: colors.muted,
                  tooltip: 'Options',
                  onPressed: () => _showPostOptions(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(post.body, style: Theme.of(context).textTheme.bodyMedium),
            if (post.imageUri != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (post.imageUri!.startsWith('http://') ||
                          post.imageUri!.startsWith('https://'))
                      ? CachedNetworkImage(
                          imageUrl: post.imageUri!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                        )
                      : File(post.imageUri!).existsSync()
                          ? Image.file(
                              File(post.imageUri!),
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(
                              height: 160,
                              child: Center(child: Icon(Icons.broken_image)),
                            ),
                ),
              ),
            if (post.expertResponse != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.healthyBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.expertResponse,
                        style: TextStyle(
                            color: colors.healthy,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(post.expertResponse!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncStatusBadge extends StatelessWidget {
  final String status;

  const _SyncStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String label;

    switch (status) {
      case 'pending':
        bgColor = Colors.amber.shade50;
        textColor = Colors.amber.shade800;
        icon = Icons.access_time;
        label = context.l10n.syncPending;
        break;
      case 'syncing':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade800;
        icon = Icons.sync;
        label = context.l10n.syncSyncing;
        break;
      case 'failed':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        icon = Icons.error_outline;
        label = context.l10n.syncFailed;
        break;
      case 'abandoned':
        // Exceeded max retries — permanent delivery failure.
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        icon = Icons.cancel_outlined;
        label = context.l10n.syncDeliveryFailed;
        break;
      case 'synced':
      default:
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle_outline;
        label = context.l10n.syncSynced;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'syncing')
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: textColor,
              ),
            )
          else
            Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
