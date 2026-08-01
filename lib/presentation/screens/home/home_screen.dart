import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/device_layout.dart';
import '../../../core/utils/locale_formatter.dart';
import '../../../core/utils/planting_reminder_manager.dart';
import '../../../domain/models/detection_result.dart';
import '../../components/cropguard_card.dart';
import '../../components/farm_health_ring.dart';
import '../../components/offline_banner.dart';
import '../../components/section_label.dart';
import '../../components/severity_badge.dart';
import '../../../data/local/database_helper.dart';
import '../../../core/di/service_locator.dart';
import 'home_provider.dart';
import 'widgets/weather_forecast_widget.dart';
import 'widgets/disease_trend_chart.dart';
import 'widgets/planting_calendar_widget.dart';
import 'widgets/disease_risk_forecast_widget.dart';
import 'widgets/risk_card.dart';

/// Equivalent of HomeScreen.kt
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _unreadCount = 0;
  final DatabaseHelper _db = sl<DatabaseHelper>();
  Timer? _badgeTimer;
  @override
  void initState() {
    super.initState();
    _refreshUnread();
    _badgeTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshUnread();
    });
    // Trigger the first data load after the frame is built so the provider
    // is accessible via context and the user has a retry path if it fails.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomeProvider>().load();
    });
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    final count = await _db.getUnreadNotificationCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  void _showAddCropDialog(BuildContext context, HomeProvider provider) {
    String selectedCrop = 'Maize';
    DateTime selectedDate = DateTime.now();
    final crops = [
      'Maize', 'Cassava', 'Tomato', 'Yam', 'Plantain',
      'Rice', 'Soybean', 'Groundnut', 'Cocoa', 'Oil Palm',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(context.l10n.addCrop),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedCrop,
                items: crops
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => selectedCrop = v!),
                decoration: InputDecoration(labelText: context.l10n.cropType),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(context.l10n.plantedOn(LocaleFormatter.formatMonthDayYear(context, selectedDate))),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final crop = PlantingCrop(
                  id: const Uuid().v4(),
                  cropType: selectedCrop,
                  plantedDate: selectedDate,
                );
                provider.addMyCrop(crop);
                Navigator.pop(ctx);
              },
              child: Text(context.l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: provider.refresh,
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              backgroundColor: colors.surface,
              title: Row(
                children: [
                  Icon(Icons.eco, color: colors.primary, size: 28),
                  const SizedBox(width: 8),
                  Text(context.l10n.appTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: colors.primary)),
                ],
              ),
              actions: [
                // Notification bell with unread badge
                Stack(
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      constraints: const BoxConstraints(
                        minWidth: DeviceLayout.minTouchTarget,
                        minHeight: DeviceLayout.minTouchTarget,
                      ),
                      icon: Icon(Icons.notifications_outlined,
                          color: colors.onBackground,
                          size: DeviceLayout.iconSize),
                      onPressed: () async {
                        await context.push('/notifications');
                        unawaited(_refreshUnread());
                      },
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: colors.diseaseRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: colors.surface, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              _unreadCount > 9 ? '9+' : '$_unreadCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: 'Profile',
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: colors.primary,
                    child: const Icon(Icons.person,
                        size: 18, color: Colors.white),
                  ),
                  onPressed: () => context.push('/profile'),
                ),
                const SizedBox(width: 8),
              ],
              floating: true,
            ),

            if (!provider.isLoading && provider.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_outlined,
                          size: 56, color: colors.muted),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.couldNotLoadFarmData,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: colors.onBackgroundSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: provider.retry,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.l10n.tapToRetry),
                      ),
                    ],
                  ),
                ),
              )
            else
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OfflineBanner(status: provider.connectionStatus),

                  // At most one alert, to avoid stacking near-duplicate
                  // banners that consume the whole fold: the actionable weather
                  // disease-risk alert takes priority over the informational
                  // seasonal one.
                  if (provider.hasDiseaseRisk)
                    _AlertBanner(
                        message: provider.diseaseRiskMessage, type: 'risk')
                  else if (provider.isHighRisk &&
                      provider.seasonalAlert.isNotEmpty)
                    _AlertBanner(
                        message: provider.seasonalAlert, type: 'seasonal'),

                  Padding(
                    // Extra bottom inset so the scroll content (incl. the
                    // Recent Scans list / empty state) clears the docked scan
                    // FAB, which overlays the body above the BottomAppBar.
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Farm Health + Stats row
                        CropGuardCard(
                          child: Row(
                            children: [
                              FarmHealthRing(
                                percentage: provider.stats.healthScore,
                                size: 100,
                                showStartPrompt: provider.stats.totalScans == 0,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(context.l10n.farmHealthScore,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    const SizedBox(height: 12),
                                    _StatRow(
                                      label: context.l10n.totalScans,
                                      value: provider.stats.totalScans
                                          .toString(),
                                    ),
                                    _StatRow(
                                      label: context.l10n.healthy,
                                      value: provider.stats.healthyScans
                                          .toString(),
                                      color: colors.healthy,
                                    ),
                                    _StatRow(
                                      label: context.l10n.diseased,
                                      value: provider.stats.diseasedScans
                                          .toString(),
                                      color: colors.diseaseRed,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Empty-state helper: shown only when no scans exist
                        // so the ring's purpose is clear to new users.
                        if (provider.stats.totalScans == 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              context.l10n.noScansYetDesc,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),

                        // Quick action — Scan
                        InkWell(
                          onTap: () => context.push('/scanner'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: DeviceLayout.screenPaddingHorizontal,
                                vertical: 18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colors.primary, colors.primaryLight],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 28),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(context.l10n.scanNow,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      Text(context.l10n.scanNowSubtitle,
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.8),
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios,
                                    color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SectionLabel(text: context.l10n.explore),
                        const SizedBox(height: 8),
                        _QuickActionsRow(
                          actions: [
                            _QuickAction(
                              icon: Icons.people_outline,
                              label: context.l10n.community,
                              onTap: () => context.push('/community'),
                            ),
                            _QuickAction(
                              icon: Icons.map_outlined,
                              label: context.l10n.outbreaks,
                              onTap: () => context.push('/outbreak_map'),
                            ),
                            _QuickAction(
                              icon: Icons.menu_book_outlined,
                              label: context.l10n.library,
                              onTap: () => context.push('/disease_library'),
                            ),
                            _QuickAction(
                              icon: Icons.medical_services_outlined,
                              label: context.l10n.treatments,
                              onTap: () => context.push('/treatment_tracker'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Climate Intelligence Section
                        SectionLabel(text: context.l10n.climateIntelligence),
                        const SizedBox(height: 12),
                        if (provider.isWeatherLoading)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ))
                        else if (provider.weather != null)
                          WeatherForecastWidget(
                            weather: provider.weather!,
                            locationName: provider.locationName,
                          )
                        else if (provider.weatherError != null)
                          Text(context.l10n.weatherUnavailable(provider.weatherError ?? ''),
                            style: TextStyle(color: colors.diseaseRed, fontSize: 12)),

                        const SizedBox(height: 12),
                        const RiskCard(),

                        // Weather-driven disease-risk outlook (preventive).
                        if (provider.weather != null) ...[
                          const SizedBox(height: 12),
                          DiseaseRiskForecastWidget(
                            risks: provider.weeklyRisks,
                          ),
                        ],

                        const SizedBox(height: 16),
                        if (provider.plantingStatus.isNotEmpty)
                          PlantingCalendarWidget(
                            status: provider.plantingStatus,
                            action: provider.plantingAction,
                          ),
                        
                        if (provider.trend.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          SectionLabel(text: context.l10n.scanTrend7Day),
                          const SizedBox(height: 8),
                          CropGuardCard(
                            child: DiseaseTrendChart(trend: provider.trend),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Daily tip
                        if (provider.dailyTip.isNotEmpty)
                          CropGuardCard(
                            backgroundColor: colors.healthyBg,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lightbulb_outline,
                                    color: colors.healthy, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(context.l10n.tipOfTheDay,
                                          style: TextStyle(
                                              color: colors.healthy,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(provider.dailyTip,
                                          style: TextStyle(
                                              color: colors.onBackground,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),

                        // My Crops (planting calendar)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SectionLabel(text: context.l10n.myCrops),
                            TextButton.icon(
                              onPressed: () => _showAddCropDialog(context, provider),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(context.l10n.addCrop),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (provider.myCrops.isEmpty)
                          CropGuardCard(
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    color: colors.muted, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    context.l10n.addCropPrompt,
                                    style: TextStyle(color: colors.muted, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...provider.myCrops.map((crop) => _CropCalendarTile(
                                crop: crop,
                                onRemove: () => provider.removeMyCrop(crop.id),
                              )),

                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SectionLabel(text: context.l10n.recentScans),
                            if (provider.recentScans.isNotEmpty)
                              TextButton(
                                onPressed: () => context.go('/history'),
                                child: Text(context.l10n.seeAll),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (provider.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (provider.recentScans.isEmpty)
                          _EmptyState(
                            onScan: () => context.push('/scanner'),
                          )
                        else
                          Column(
                            children: provider.recentScans
                                .map((r) => _ScanListTile(
                                    result: r,
                                    onTap: () =>
                                        context.push('/result/${r.id}')))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final String message;
  final String type;

  const _AlertBanner({required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isRisk = type == 'risk';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isRisk ? colors.diseaseRed.withValues(alpha: 0.1) : colors.warning.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(
            isRisk ? Icons.notification_important : Icons.warning_amber_rounded, 
            color: isRisk ? colors.diseaseRed : colors.warning, 
            size: 18
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: colors.onBackground, fontSize: 12, fontWeight: isRisk ? FontWeight.bold : FontWeight.normal)),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: colors.onBackgroundSecondary, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: color ?? colors.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ScanListTile extends StatelessWidget {
  final DetectionResult result;
  final VoidCallback onTap;

  const _ScanListTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date =
        LocaleFormatter.formatMonthDayHourMinute(
          context,
          DateTime.fromMillisecondsSinceEpoch(result.timestamp),
        );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: result.isHealthy
                    ? colors.healthyBg
                    : colors.diseaseBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                result.isHealthy ? Icons.check_circle : Icons.warning,
                color: result.isHealthy ? colors.healthy : colors.diseaseRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('${result.cropType} • $date',
                      style: TextStyle(
                          color: colors.muted, fontSize: 11)),
                ],
              ),
            ),
            SeverityBadge(severity: result.severity),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: colors.muted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final List<_QuickAction> actions;

  const _QuickActionsRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: actions
          .map((a) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: a,
                ),
              ))
          .toList(),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.primary, size: 22),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.onBackground)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;

  const _EmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.eco_outlined, size: 64, color: colors.border),
          const SizedBox(height: 12),
          Text(context.l10n.noScansYet,
              style: TextStyle(
                  color: colors.onBackgroundSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(context.l10n.noScansYetDesc,
              style: TextStyle(color: colors.muted, fontSize: 13)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onScan,
            icon: Icon(Icons.camera_alt, color: colors.primary),
            label: Text(context.l10n.startScanning,
                style: TextStyle(color: colors.primary)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CropCalendarTile extends StatelessWidget {
  final PlantingCrop crop;
  final VoidCallback onRemove;

  const _CropCalendarTile({required this.crop, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final daysSincePlanting =
        DateTime.now().difference(crop.plantedDate).inDays;
    final nextMilestone = _nextMilestone(context, daysSincePlanting);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.healthyBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.grass, color: colors.healthy, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop.cropType,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  context.l10n.plantedDayLabel(
                      LocaleFormatter.formatMonthDay(context, crop.plantedDate),
                      daysSincePlanting),
                  style: TextStyle(color: colors.muted, fontSize: 11),
                ),
                if (nextMilestone != null)
                  Text(nextMilestone,
                      style:
                          TextStyle(color: colors.primary, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove crop',
            icon: Icon(Icons.close, size: 18, color: colors.muted),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String? _nextMilestone(BuildContext context, int daysSincePlanting) {
    final l10n = context.l10n;
    if (daysSincePlanting < 7) return l10n.milestoneFertilizer(7 - daysSincePlanting);
    if (daysSincePlanting < 30) return l10n.milestoneHealthCheck(30 - daysSincePlanting);
    if (daysSincePlanting < 60) return l10n.milestoneHarvestWindow(60 - daysSincePlanting);
    return l10n.milestoneHarvestReached;
  }
}
