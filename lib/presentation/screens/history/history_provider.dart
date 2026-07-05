import 'package:flutter/material.dart';
import '../../../domain/models/detection_result.dart';
import '../../../domain/usecases/history/get_history_usecase.dart';
import '../../../domain/usecases/history/delete_detection_usecase.dart';
import '../../../domain/usecases/history/restore_detection_usecase.dart';

enum HistoryFilter { all, healthy, diseased }

enum HistorySort { dateNewest, dateOldest, confidenceDesc, confidenceAsc, cropType }

/// Refactored HistoryProvider using Clean Architecture
class HistoryProvider extends ChangeNotifier {
  final GetHistoryUseCase _getHistoryUseCase;
  final DeleteDetectionUseCase _deleteDetectionUseCase;
  final RestoreDetectionUseCase _restoreDetectionUseCase;

  HistoryProvider(this._getHistoryUseCase, this._deleteDetectionUseCase, this._restoreDetectionUseCase) {
    load();
  }

  List<DetectionResult> _all = [];
  List<DetectionResult> filtered = [];
  HistoryFilter filter = HistoryFilter.all;
  HistorySort sort = HistorySort.dateNewest;
  String searchQuery = '';
  bool isLoading = true;

  // Crop type filter
  Set<String> cropTypeFilter = {};

  // Date range filter
  DateTime? dateFrom;
  DateTime? dateTo;

  List<String> get availableCropTypes =>
      (_all.map((r) => r.cropType).toSet().toList()..sort());

  bool get hasActiveFilters =>
      cropTypeFilter.isNotEmpty || dateFrom != null || dateTo != null;

  void setCropTypeFilter(String cropType) {
    if (cropTypeFilter.contains(cropType)) {
      cropTypeFilter = Set.from(cropTypeFilter)..remove(cropType);
    } else {
      cropTypeFilter = Set.from(cropTypeFilter)..add(cropType);
    }
    _applyFilter();
    notifyListeners();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    dateFrom = from;
    dateTo = to;
    _applyFilter();
    notifyListeners();
  }

  void clearFilters() {
    cropTypeFilter = {};
    dateFrom = null;
    dateTo = null;
    _applyFilter();
    notifyListeners();
  }

  // ── Comparison mode (2-scan side-by-side) ────────────────────────────────
  bool comparisonMode = false;
  List<int> selectedIds = [];

  void toggleComparisonMode() {
    comparisonMode = !comparisonMode;
    selectedIds.clear();
    if (comparisonMode && exportMode) {
      exportMode = false;
      _exportSelectedIds.clear();
    }
    notifyListeners();
  }

  void toggleSelection(int id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      if (selectedIds.length < 2) {
        selectedIds.add(id);
      } else {
        selectedIds.removeAt(0);
        selectedIds.add(id);
      }
    }
    notifyListeners();
  }

  List<DetectionResult> get selectedScans =>
      _all.where((r) => selectedIds.contains(r.id)).toList();

  // ── Export selection mode (multi-select for PDF export) ───────────────────
  bool exportMode = false;
  final _exportSelectedIds = <int>{};
  Set<int> get exportSelectedIds => Set.unmodifiable(_exportSelectedIds);

  /// Long-pressing a tile enters export mode with that scan pre-selected.
  void enterExportMode(int initialId) {
    if (comparisonMode) {
      comparisonMode = false;
      selectedIds.clear();
    }
    exportMode = true;
    _exportSelectedIds.add(initialId);
    notifyListeners();
  }

  void exitExportMode() {
    exportMode = false;
    _exportSelectedIds.clear();
    notifyListeners();
  }

  void toggleExportSelection(int id) {
    if (_exportSelectedIds.contains(id)) {
      _exportSelectedIds.remove(id);
      if (_exportSelectedIds.isEmpty) exitExportMode();
    } else {
      _exportSelectedIds.add(id);
    }
    notifyListeners();
  }

  List<DetectionResult> get exportSelectedScans =>
      filtered.where((r) => _exportSelectedIds.contains(r.id)).toList();

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    
    final result = await _getHistoryUseCase();
    if (result.isSuccess) {
      _all = result.data ?? [];
    }
    
    _applyFilter();
    isLoading = false;
    notifyListeners();
  }

  void setFilter(HistoryFilter f) {
    filter = f;
    _applyFilter();
    notifyListeners();
  }

  void setSearch(String q) {
    searchQuery = q;
    _applyFilter();
    notifyListeners();
  }

  void setSort(HistorySort s) {
    sort = s;
    _applyFilter();
    notifyListeners();
  }

  Future<void> exportHistory() async {
    // Export handled in UI via ScanReportPdfExporter per scan.
  }

  Future<void> deleteResult(int id) async {
    final result = await _deleteDetectionUseCase(id);
    if (result.isSuccess) {
      await load();
    }
  }

  Future<void> restoreDetection(DetectionResult detection) async {
    final result = await _restoreDetectionUseCase(detection);
    if (result.isSuccess) {
      await load();
    }
  }

  void _applyFilter() {
    var list = _all;
    switch (filter) {
      case HistoryFilter.healthy:
        list = list.where((r) => r.isHealthy).toList();
        break;
      case HistoryFilter.diseased:
        list = list.where((r) => !r.isHealthy).toList();
        break;
      case HistoryFilter.all:
        break;
    }
    if (cropTypeFilter.isNotEmpty) {
      list = list.where((r) => cropTypeFilter.contains(r.cropType)).toList();
    }
    if (dateFrom != null) {
      final fromMs = dateFrom!.millisecondsSinceEpoch;
      list = list.where((r) => r.timestamp >= fromMs).toList();
    }
    if (dateTo != null) {
      final toMs = dateTo!
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
      list = list.where((r) => r.timestamp < toMs).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where((r) =>
              r.displayName.toLowerCase().contains(q) ||
              r.cropType.toLowerCase().contains(q))
          .toList();
    }
    switch (sort) {
      case HistorySort.dateOldest:
        list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case HistorySort.confidenceDesc:
        list.sort((a, b) => b.confidence.compareTo(a.confidence));
        break;
      case HistorySort.confidenceAsc:
        list.sort((a, b) => a.confidence.compareTo(b.confidence));
        break;
      case HistorySort.cropType:
        list.sort((a, b) => a.cropType.compareTo(b.cropType));
        break;
      case HistorySort.dateNewest:
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
    }
    filtered = list;
  }
}

