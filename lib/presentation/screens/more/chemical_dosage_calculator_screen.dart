import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../components/cropguard_card.dart';

class ChemicalDosageCalculatorScreen extends StatefulWidget {
  const ChemicalDosageCalculatorScreen({super.key});

  @override
  State<ChemicalDosageCalculatorScreen> createState() =>
      _ChemicalDosageCalculatorScreenState();
}

class _ChemicalDosageCalculatorScreenState
    extends State<ChemicalDosageCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedCrop = 'Cocoa';
  String _selectedTreatment = 'Fungicide (Copper Hydroxide - Black Pod)';
  double _farmSizeAcres = 1.0;
  double _tankCapacityLiters = 15.0;

  final Map<String, List<String>> _cropTreatments = {
    'Cocoa': [
      'Fungicide (Copper Hydroxide - Black Pod)',
      'Insecticide (Mirid Control)',
      'Fungicide (Ridomil Gold)',
    ],
    'Cassava': [
      'Insecticide (Neem Oil Spray - Whitefly)',
      'Bio-Pesticide (Potassium Soap)',
    ],
    'Tomato': [
      'Fungicide (Mancozeb - Early/Late Blight)',
      'Insecticide (Spinosad - Caterpillars)',
    ],
    'Maize': [
      'Insecticide (Emamectin Benzoate - Fall Armyworm)',
      'Neem Extract Concentrate',
    ],
  };

  // Recommended dilution rates per acre (approximate standard agronomic defaults)
  // [totalVolumeLitersPerAcre, dosageGramsOrMlPerLiter]
  final Map<String, ({double volumePerAcre, double dosagePerLiter})>
      _dosageSpecs = {
    'Fungicide (Copper Hydroxide - Black Pod)': (
      volumePerAcre: 45.0,
      dosagePerLiter: 3.5
    ),
    'Insecticide (Mirid Control)': (volumePerAcre: 30.0, dosagePerLiter: 2.0),
    'Fungicide (Ridomil Gold)': (volumePerAcre: 45.0, dosagePerLiter: 2.5),
    'Insecticide (Neem Oil Spray - Whitefly)': (
      volumePerAcre: 30.0,
      dosagePerLiter: 5.0
    ),
    'Bio-Pesticide (Potassium Soap)': (
      volumePerAcre: 30.0,
      dosagePerLiter: 4.0
    ),
    'Fungicide (Mancozeb - Early/Late Blight)': (
      volumePerAcre: 40.0,
      dosagePerLiter: 3.0
    ),
    'Insecticide (Spinosad - Caterpillars)': (
      volumePerAcre: 35.0,
      dosagePerLiter: 1.5
    ),
    'Insecticide (Emamectin Benzoate - Fall Armyworm)': (
      volumePerAcre: 35.0,
      dosagePerLiter: 1.0
    ),
    'Neem Extract Concentrate': (volumePerAcre: 30.0, dosagePerLiter: 5.0),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final spec = _dosageSpecs[_selectedTreatment] ??
        (volumePerAcre: 40.0, dosagePerLiter: 2.5);
    final totalWaterNeeded = spec.volumePerAcre * _farmSizeAcres;
    final totalChemicalNeeded = totalWaterNeeded * spec.dosagePerLiter;
    final numberOfTanks = (totalWaterNeeded / _tankCapacityLiters).ceil();
    final chemicalPerTank =
        totalChemicalNeeded / (numberOfTanks > 0 ? numberOfTanks : 1);

    final isLiquid = _selectedTreatment.contains('Oil') ||
        _selectedTreatment.contains('Insecticide') ||
        _selectedTreatment.contains('Extract') ||
        _selectedTreatment.contains('Soap');
    final unit = isLiquid ? 'mL' : 'g';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Spray & Dosage Calculator'),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              CropGuardCard(
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                borderColor: colors.primary,
                child: Row(
                  children: [
                    Icon(Icons.calculate_outlined,
                        size: 36, color: colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Knapsack Spray Calculator',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Calculate exact water-to-chemical mixing ratios to avoid crop damage or under-dosing.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onBackgroundSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Inputs Section
              Text(
                'Farm & Chemical Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // Crop Selector Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCrop,
                decoration: const InputDecoration(
                  labelText: 'Target Crop',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.eco_outlined),
                ),
                items: _cropTreatments.keys.map((crop) {
                  return DropdownMenuItem(
                    value: crop,
                    child: Text(crop),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCrop = val;
                      _selectedTreatment = _cropTreatments[val]!.first;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              // Treatment Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedTreatment,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Selected Treatment Chemical',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.science_outlined),
                ),
                items: (_cropTreatments[_selectedCrop] ?? []).map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(
                      t,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedTreatment = val);
                  }
                },
              ),

              const SizedBox(height: 16),

              // Farm Size Slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Farm Field Size (Acres)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_farmSizeAcres.toStringAsFixed(1)} Acre(s)',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _farmSizeAcres,
                    min: 0.5,
                    max: 10.0,
                    divisions: 19,
                    label: '${_farmSizeAcres.toStringAsFixed(1)} Acres',
                    activeColor: colors.primary,
                    onChanged: (val) => setState(() => _farmSizeAcres = val),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Tank Capacity Dropdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Knapsack Tank Capacity',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SegmentedButton<double>(
                    segments: const [
                      ButtonSegment(value: 12.0, label: Text('12L')),
                      ButtonSegment(value: 15.0, label: Text('15L')),
                      ButtonSegment(value: 20.0, label: Text('20L')),
                    ],
                    selected: {_tankCapacityLiters},
                    onSelectionChanged: (set) {
                      setState(() => _tankCapacityLiters = set.first);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Output Results Summary
              Text(
                'Mixing & Application Instructions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              CropGuardCard(
                child: Column(
                  children: [
                    _DosageRow(
                      icon: Icons.water_drop_outlined,
                      label: 'Total Water Required',
                      value: '${totalWaterNeeded.toStringAsFixed(1)} Liters',
                      colors: colors,
                    ),
                    const Divider(height: 16),
                    _DosageRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Total Chemical Required',
                      value: '${totalChemicalNeeded.toStringAsFixed(0)} $unit',
                      colors: colors,
                      highlight: true,
                    ),
                    const Divider(height: 16),
                    _DosageRow(
                      icon: Icons.backpack_outlined,
                      label: 'Knapsack Tanks Needed',
                      value:
                          '$numberOfTanks Tank(s) (${_tankCapacityLiters.toInt()}L each)',
                      colors: colors,
                    ),
                    const Divider(height: 16),
                    _DosageRow(
                      icon: Icons.science,
                      label: 'Dosage Per Tank',
                      value:
                          '${chemicalPerTank.toStringAsFixed(1)} $unit per tank',
                      colors: colors,
                      highlight: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Safety & Early Morning Spray Tips
              CropGuardCard(
                backgroundColor: colors.surface,
                borderColor: colors.border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: colors.warning),
                        const SizedBox(width: 8),
                        Text(
                          'Safety & Spraying Guidelines',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Always wear PPE (gloves, goggles, nose mask).\n'
                      '• Spray during early morning (6:00 - 9:00 AM) or late afternoon.\n'
                      '• Avoid spraying when wind exceeds 15 km/h or if rain is expected within 4 hours.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onBackgroundSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: colors.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.l10n.treatmentAdvisoryDisclaimer,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.muted,
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DosageRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final CropColors colors;
  final bool highlight;

  const _DosageRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: highlight ? colors.primary : colors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: highlight ? colors.primary : colors.onBackground,
          ),
        ),
      ],
    );
  }
}
