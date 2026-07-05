import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../components/cropguard_card.dart';
import '../../components/cropguard_text_field.dart';
import '../../components/offline_banner.dart';
import '../../components/primary_button.dart';
import '../../components/section_label.dart';
import 'profile_provider.dart';

/// Resolves the avatar image, preferring the offline-first local file and
/// falling back to the cloud-synced URL. Returns null when neither exists so
/// callers can show the default person icon.
ImageProvider? _avatarImage(ProfileProvider p) {
  final local = p.localPhotoPath;
  if (local != null) return FileImage(File(local));
  final url = p.avatarUrl;
  if (url != null && url.isNotEmpty) return CachedNetworkImageProvider(url);
  return null;
}

/// Equivalent of ProfileScreen.kt
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: colors.primary,
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.primaryDark_, colors.primary],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: colors.primaryLight,
                        backgroundImage: _avatarImage(provider),
                        child: _avatarImage(provider) == null
                            ? const Icon(Icons.person,
                                size: 40, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        provider.userName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      Text(
                        provider.userEmail,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      if (provider.isPro)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: Text(context.l10n.proFarmer,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                OfflineBanner(status: provider.connectionStatus),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatCell(
                              label: context.l10n.totalScans,
                              value: provider.stats.totalScans.toString()),
                          _StatCell(
                              label: context.l10n.healthScore,
                              value:
                                  '${(provider.stats.healthScore * 100).toInt()}%'),
                          _StatCell(
                              label: context.l10n.diseases,
                              value: provider.stats.diseasesCaught
                                  .toString()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Account options
                      CropGuardCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel(
                                text: context.l10n.accountSection,
                                padding:
                                    const EdgeInsets.only(bottom: 8)),
                            _ProfileRow(
                              icon: Icons.edit_outlined,
                              label: context.l10n.editProfile,
                              onTap: () => _showEditProfileSheet(context),
                            ),
                            _ProfileRow(
                              icon: Icons.settings_outlined,
                              label: context.l10n.settings,
                              onTap: () => context.push('/settings'),
                            ),
                            _ProfileRow(
                              icon: Icons.privacy_tip_outlined,
                              label: context.l10n.privacyPolicy,
                              onTap: () => context.push('/privacy_policy'),
                            ),
                            _ProfileRow(
                              icon: Icons.book_outlined,
                              label: context.l10n.diseaseLibrary,
                              onTap: () =>
                                  context.push('/disease_library'),
                            ),
                            _ProfileRow(
                              icon: Icons.people_outline,
                              label: context.l10n.community,
                              onTap: () => context.push('/community'),
                            ),
                            _ProfileRow(
                              icon: Icons.map_outlined,
                              label: context.l10n.outbreakMap,
                              onTap: () => context.push('/outbreak_map'),
                            ),
                            _ProfileRow(
                              icon: Icons.medical_services_outlined,
                              label: context.l10n.treatmentTracker,
                              onTap: () => context.push('/treatment_tracker'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Preferences
                      CropGuardCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel(
                                text: context.l10n.preferencesSection,
                                padding:
                                    const EdgeInsets.only(bottom: 8)),
                            _PrefToggle(
                              icon: Icons.notifications_outlined,
                              label: context.l10n.diseaseAlerts,
                              value: provider.alertsEnabled,
                              onChanged: provider.setAlertsEnabled,
                            ),
                            _PrefToggle(
                              icon: Icons.high_quality_outlined,
                              label: context.l10n.highQualityScans,
                              value: provider.highQualityScans,
                              onChanged: provider.setHighQualityScans,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sign out
                      InkWell(
                        onTap: () => provider.signOut(
                            () => context.go('/login')),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: colors.error.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(10),
                            color: colors.diseaseBg,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.logout,
                                  color: colors.error, size: 20),
                              const SizedBox(width: 12),
                              Text(context.l10n.signOut,
                                  style: TextStyle(
                                      color: colors.error,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    final provider = context.read<ProfileProvider>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        var editName = provider.userName;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Consumer<ProfileProvider>(
                builder: (context, profile, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.l10n.editProfile,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 20),
                      _AvatarPicker(
                        // Local-first: the picked image is saved and shown
                        // immediately, then synced to the cloud in the
                        // background. No network is required to set it.
                        image: _avatarImage(profile),
                        isBusy: profile.isSavingPhoto,
                        isSyncing: profile.isSyncingPhoto,
                        uploadError: profile.uploadPhotoError,
                        canRemove: profile.localPhotoPath != null ||
                            (profile.avatarUrl?.isNotEmpty ?? false),
                        onPickImage: () async {
                          final file = await ImagePicker()
                              .pickImage(source: ImageSource.gallery);
                          if (file == null) return;
                          await profile.setProfilePhoto(file.path);
                        },
                        onRemove: () => profile.removeProfilePhoto(),
                      ),
                      const SizedBox(height: 16),
                      CropGuardTextField(
                        value: editName,
                        onChanged: (v) => setSheetState(() => editName = v),
                        label: context.l10n.displayName,
                        placeholder: context.l10n.yourName,
                      ),
                      if (profile.profileError != null) ...[
                        const SizedBox(height: 8),
                        Text(profile.profileError!,
                            style: TextStyle(
                                color: context.colors.error, fontSize: 12)),
                      ],
                      const SizedBox(height: 16),
                      PrimaryButton(
                        text: context.l10n.save,
                        isLoading: profile.isSavingProfile,
                        onPressed: profile.isSavingProfile
                            ? null
                            : () async {
                                profile.clearProfileError();
                                final ok = await profile.saveProfile(
                                  displayName: editName,
                                );
                                if (ok && context.mounted) {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  Navigator.pop(context);
                                  messenger.showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            context.l10n.profileUpdated)),
                                  );
                                }
                              },
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: colors.greenXL,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(color: colors.muted, fontSize: 11)),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileRow(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: colors.muted),
          ],
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final ImageProvider? image;

  /// True while the picked file is being copied into local storage.
  final bool isBusy;

  /// True while the local photo is being uploaded to the cloud in the
  /// background. Shown as a subtle hint — it never blocks interaction.
  final bool isSyncing;
  final String? uploadError;
  final bool canRemove;
  final VoidCallback onPickImage;
  final VoidCallback onRemove;

  const _AvatarPicker({
    required this.image,
    required this.isBusy,
    required this.isSyncing,
    required this.canRemove,
    required this.onPickImage,
    required this.onRemove,
    this.uploadError,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: isBusy ? null : onPickImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: colors.surfaceVariant,
                  backgroundImage: isBusy ? null : image,
                  child: isBusy
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : image == null
                          ? Icon(Icons.person, size: 44, color: colors.muted)
                          : null,
                ),
                if (!isBusy)
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: colors.surface, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 14, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        if (isSyncing) ...[
          const SizedBox(height: 6),
          Text(context.l10n.syncingPhoto,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted, fontSize: 12)),
        ],
        if (canRemove && !isBusy) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline, size: 18, color: colors.error),
            label: Text(context.l10n.removePhoto,
                style: TextStyle(color: colors.error, fontSize: 13)),
          ),
        ],
        if (uploadError != null) ...[
          const SizedBox(height: 6),
          Text(uploadError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.error, fontSize: 12)),
        ],
      ],
    );
  }
}

class _PrefToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefToggle(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
