import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/device_layout.dart';
import '../../../core/utils/planting_reminder_manager.dart';

/// Crops offered in onboarding — mirrors the "Add Crop" list on Home so the
/// seeded selection stays consistent with later crop management.
const _kOnboardingCrops = [
  'Maize',
  'Cassava',
  'Tomato',
  'Yam',
  'Plantain',
  'Rice',
  'Soybean',
  'Groundnut',
  'Cocoa',
  'Oil Palm',
];

/// 4-page horizontal pager with language picker on page 1 and animated hero widgets
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentPage = 0;
  late final AnimationController _heroAnim;
  // Crops the user grows, captured on the crop-selection page and seeded into
  // "My Crops" so the dashboard isn't empty on first run.
  final Set<String> _selectedCrops = {};
  // Region selected on the region picker page — stored in SharedPreferences
  // so HomeProvider can use it as the GPS fallback.
  String? _selectedRegion;

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  static const _pageCount = 6;

  Future<void> _complete() async {
    await [
      Permission.camera,
      Permission.location,
      Permission.notification,
    ].request();
    final prefs = sl<SharedPreferences>();
    // Seed selected crops (default planted-today; the user can refine exact
    // planting dates later in My Crops). Merge with any already saved so a
    // returning user's list isn't clobbered.
    if (_selectedCrops.isNotEmpty) {
      final existing = await PlantingReminderManager.loadCrops(prefs);
      final existingTypes = existing.map((c) => c.cropType).toSet();
      final now = DateTime.now();
      const uuid = Uuid();
      final added = _selectedCrops
          .where((c) => !existingTypes.contains(c))
          .map((c) => PlantingCrop(
                id: uuid.v4(),
                cropType: c,
                plantedDate: now,
              ));
      await PlantingReminderManager.saveCrops(prefs, [...existing, ...added]);
    }
    await prefs.setBool('onboarding_complete', true);
    // Save the user's selected region for use as the weather/outbreak fallback.
    if (_selectedRegion != null) {
      await prefs.setString('user_region', _selectedRegion!);
    }
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    _heroAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Pages ──────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  _heroAnim
                    ..reset()
                    ..repeat(reverse: true);
                },
                children: [
                  _WelcomePage(anim: _heroAnim),
                  _ScanPage(anim: _heroAnim),
                  _ActPage(anim: _heroAnim),
                  _CropsPage(
                    selected: _selectedCrops,
                    onToggle: (crop) => setState(() {
                      _selectedCrops.contains(crop)
                          ? _selectedCrops.remove(crop)
                          : _selectedCrops.add(crop);
                    }),
                  ),
                  _RegionPage(
                    selected: _selectedRegion,
                    onChanged: (r) => setState(() => _selectedRegion = r),
                  ),
                  _PermissionsPage(anim: _heroAnim),
                ],
              ),
            ),

            // ── Dots + buttons ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DeviceLayout.screenPaddingHorizontal,
                0,
                DeviceLayout.screenPaddingHorizontal,
                DeviceLayout.screenPaddingVertical + 8,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pageCount, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? colors.primary : colors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: DeviceLayout.primaryButtonHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DeviceLayout.buttonCornerRadius,
                          ),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (_currentPage < _pageCount - 1) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOutCubic,
                          );
                        } else {
                          _complete();
                        }
                      },
                      child: Text(
                        _currentPage < _pageCount - 1
                            ? 'Continue'
                            : context.l10n.onboardingEnableStart,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_currentPage == 0)
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                          '${context.l10n.hasAccountPrompt} ${context.l10n.signIn}',
                          style:
                              TextStyle(color: colors.primary, fontSize: 13)),
                    ),
                  if (_currentPage > 0 && _currentPage < _pageCount - 1)
                    TextButton(
                      onPressed: _complete,
                      child: Text(context.l10n.skip,
                          style: TextStyle(color: colors.muted, fontSize: 13)),
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

// ──────────────────────────────────────────────────────────────────────────────
// Page 0: Welcome — animated leaf pulse
// ──────────────────────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final AnimationController anim;
  const _WelcomePage({required this.anim});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DeviceLayout.screenPaddingHorizontal,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: anim,
            builder: (_, __) {
              final scale = 0.9 + 0.1 * anim.value;
              final glow = anim.value;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.primary.withValues(alpha: 0.15 + 0.15 * glow),
                        colors.primary.withValues(alpha: 0.03),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.25 * glow),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(Icons.eco_rounded,
                        size: 90, color: colors.primary),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 36),
          Text(
            context.l10n.onboardingWelcomeTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.onboardingWelcomeBody,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onBackgroundSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Page 1: Scan — simulated camera scan animation
// ──────────────────────────────────────────────────────────────────────────────

class _ScanPage extends StatelessWidget {
  final AnimationController anim;
  const _ScanPage({required this.anim});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DeviceLayout.screenPaddingHorizontal,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: AnimatedBuilder(
              animation: anim,
              builder: (_, __) {
                final scanY = anim.value;
                return Stack(
                  children: [
                    // Camera viewfinder corners
                    CustomPaint(
                      size: const Size(180, 180),
                      painter: _ViewfinderPainter(colors.primary),
                    ),
                    // Leaf icon in center
                    Center(
                      child: Icon(Icons.local_florist_rounded,
                          size: 70,
                          color: colors.primary.withValues(alpha: 0.8)),
                    ),
                    // Scanning line
                    Positioned(
                      top: 10 + 160 * scanY,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              colors.primary,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 36),
          Text(
            context.l10n.onboardingScanTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.onboardingScanBody,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onBackgroundSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final Color color;
  _ViewfinderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 8.0;

    void drawCorner(double cx, double cy, bool right, bool down) {
      final dx = right ? 1.0 : -1.0;
      final dy = down ? 1.0 : -1.0;
      final path = Path()
        ..moveTo(cx + dx * len, cy)
        ..lineTo(cx + dx * r, cy)
        ..arcToPoint(Offset(cx, cy + dy * r),
            radius: const Radius.circular(r), clockwise: right != down)
        ..lineTo(cx, cy + dy * len);
      canvas.drawPath(path, paint);
    }

    drawCorner(0, 0, true, true);
    drawCorner(size.width, 0, false, true);
    drawCorner(0, size.height, true, false);
    drawCorner(size.width, size.height, false, false);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) => old.color != color;
}

// ──────────────────────────────────────────────────────────────────────────────
// Page 2: Act Fast — rotating treatment plan cards
// ──────────────────────────────────────────────────────────────────────────────

class _ActPage extends StatelessWidget {
  final AnimationController anim;
  const _ActPage({required this.anim});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final steps = [
      ('🔬', context.l10n.onboardingStepDetected),
      ('📋', context.l10n.onboardingStepTreatment),
      ('✅', context.l10n.onboardingStepRecovery),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DeviceLayout.screenPaddingHorizontal,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 170,
            child: AnimatedBuilder(
              animation: anim,
              builder: (_, __) {
                return Stack(
                  alignment: Alignment.center,
                  children: steps.asMap().entries.map((e) {
                    final i = e.key;
                    final s = e.value;
                    final offset = (i - anim.value * 2.0).clamp(-1.0, 1.0);
                    final t = (1.0 - offset.abs()).clamp(0.0, 1.0);
                    return Transform(
                      transform: Matrix4.identity()
                        ..translateByDouble(offset * 80.0, -i * 8.0, 0.0, 1.0)
                        ..scaleByDouble(
                            0.75 + 0.25 * t, 0.75 + 0.25 * t, 1.0, 1.0),
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: (0.4 + 0.6 * t).clamp(0.0, 1.0),
                        child: Container(
                          width: 180,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.border),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(s.$1, style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 10),
                              Text(s.$2,
                                  style: TextStyle(
                                    color: colors.onBackground,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 36),
          Text(
            context.l10n.onboardingActTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.onboardingActBody,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onBackgroundSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Page 3: Crops — what the farmer grows (seeds My Crops / dashboard)
// ──────────────────────────────────────────────────────────────────────────────

class _CropsPage extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _CropsPage({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DeviceLayout.screenPaddingHorizontal,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.agriculture_rounded,
                size: 64, color: colors.primary),
          ),
          const SizedBox(height: 28),
          Text(
            'What do you grow?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Pick your crops so we can personalise disease risk and your dashboard. You can change these any time.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onBackgroundSecondary,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _kOnboardingCrops.map((crop) {
              final isSelected = selected.contains(crop);
              return FilterChip(
                label: Text(crop),
                selected: isSelected,
                showCheckmark: true,
                selectedColor: colors.primary.withValues(alpha: 0.18),
                checkmarkColor: colors.primary,
                onSelected: (_) => onToggle(crop),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Page 4: Permissions — shield animation
// ──────────────────────────────────────────────────────────────────────────────

class _PermissionsPage extends StatelessWidget {
  final AnimationController anim;
  const _PermissionsPage({required this.anim});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DeviceLayout.screenPaddingHorizontal,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: anim,
            builder: (_, __) {
              final pulse = math.sin(anim.value * math.pi);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 160 + 20 * pulse,
                    height: 160 + 20 * pulse,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          colors.primary.withValues(alpha: 0.05 + 0.05 * pulse),
                    ),
                  ),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: 0.12),
                    ),
                    child: Icon(Icons.shield_rounded,
                        size: 64, color: colors.primary),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          // Permission items
          _PermItem(
            icon: Icons.camera_alt_rounded,
            label: context.l10n.permissionCamera,
            desc: context.l10n.permissionCameraDesc,
          ),
          const SizedBox(height: 10),
          _PermItem(
            icon: Icons.location_on_rounded,
            label: context.l10n.permissionLocation,
            desc: context.l10n.permissionLocationDesc,
          ),
          const SizedBox(height: 10),
          _PermItem(
            icon: Icons.notifications_active_rounded,
            label: context.l10n.permissionNotifications,
            desc: context.l10n.permissionNotificationsDesc,
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.permissionsTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.permissionsBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onBackgroundSecondary,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PermItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  const _PermItem(
      {required this.icon, required this.label, required this.desc});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      color: colors.onBackground,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    )),
                Text(desc,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 11,
                    )),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: colors.healthy, size: 18),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Page 4: Region — where is the farm?
// ──────────────────────────────────────────────────────────────────────────────

/// All 16 Ghana administrative regions (2019 reorganisation), alphabetically.
const _kGhanaRegions = [
  'Ahafo',
  'Ashanti',
  'Bono',
  'Bono East',
  'Central',
  'Eastern',
  'Greater Accra',
  'North East',
  'Northern',
  'Oti',
  'Savannah',
  'Upper East',
  'Upper West',
  'Volta',
  'Western',
  'Western North',
];

class _RegionPage extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;
  const _RegionPage({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DeviceLayout.screenPaddingHorizontal,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.location_on_rounded,
                size: 64, color: colors.primary),
          ),
          const SizedBox(height: 28),
          Text(
            context.l10n.onboardingRegionTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.onboardingRegionBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onBackgroundSecondary,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          DropdownButtonFormField<String>(
            initialValue: selected,
            hint: Text(context.l10n.selectRegion,
                style: TextStyle(color: colors.muted)),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.map_outlined, color: colors.primary),
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
            ),
            isExpanded: true,
            items: _kGhanaRegions
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
          if (selected != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: colors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    selected!,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
