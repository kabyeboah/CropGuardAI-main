import 'package:flutter/material.dart';
import '../../../domain/models/detection_result.dart';
import '../../../domain/usecases/history/get_history_usecase.dart';
import '../../../domain/usecases/history/delete_detection_usecase.dart';
import '../../../domain/usecases/history/restore_detection_usecase.dart';
import '../../../domain/repositories/i_auth_repository.dart';

enum HistoryFilter { all, healthy, diseased }

enum HistorySort {
  dateNewest,
  dateOldest,
  confidenceDesc,
  confidenceAsc,
  cropType
}

/// Refactored HistoryProvider using Clean Architecture and pagination
class HistoryProvider extends ChangeNotifier {
  final GetHistoryUseCase _getHistoryUseCase;
  final DeleteDetectionUseCase _deleteDetectionUseCase;
  final RestoreDetectionUseCase _restoreDetectionUseCase;
  final IAuthRepository _authRepository;

  HistoryProvider(
    this._getHistoryUseCase,
    this._deleteDetectionUseCase,
    this._restoreDetectionUseCase,
    this._authRepository,
  ) {
    load(reset: true);
  }

  List<DetectionResult> filtered = [];
  HistoryFilter filter = HistoryFilter.all;
  HistorySort sort = HistorySort.dateNewest;
  String searchQuery = '';
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  final int _pageSize = 20;

  // Crop type filter
  Set<String> cropTypeFilter = {};

  // Date range filter
  DateTime? dateFrom;
  DateTime? dateTo;

  List<String> _distinctCropTypes = [];
  List<String> get availableCropTypes => _distinctCropTypes;

  bool get hasActiveFilters =>
      cropTypeFilter.isNotEmpty || dateFrom != null || dateTo != null;

  String get _userId => _authRepository.currentUser?.id ?? 'guest';

  Future<void> setCropTypeFilter(String cropType) async {
    if (cropTypeFilter.contains(cropType)) {
      cropTypeFilter = Set.from(cropTypeFilter)..remove(cropType);
    } else {
      cropTypeFilter = Set.from(cropTypeFilter)..add(cropType);
    }
    await load(reset: true);
  }

  Future<void> setDateRange(DateTime? from, DateTime? to) async {
    dateFrom = from;
    dateTo = to;
    await load(reset: true);
  }

  Future<void> clearFilters() async {
    cropTypeFilter = {};
    dateFrom = null;
    dateTo = null;
    await load(reset: true);
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
      filtered.where((r) => selectedIds.contains(r.id)).toList();

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

  Future<void> load({bool reset = true}) async {
    if (reset) {
      isLoading = true;
      hasMore = true;
      filtered.clear();
      notifyListeners();
    } else {
      if (!hasMore || isLoadingMore) return;
      isLoadingMore = true;
      notifyListeners();
    }

    final isHealthy =
        filter == HistoryFilter.all ? null : (filter == HistoryFilter.healthy);
    final String orderBy;
    switch (sort) {
      case HistorySort.dateOldest:
        orderBy = 'timestamp ASC';
        break;
      case HistorySort.confidenceDesc:
        orderBy = 'confidence DESC';
        break;
      case HistorySort.confidenceAsc:
        orderBy = 'confidence ASC';
        break;
      case HistorySort.cropType:
        orderBy = 'cropType ASC';
        break;
      case HistorySort.dateNewest:
        orderBy = 'timestamp DESC';
        break;
    }

    final result = await _getHistoryUseCase(
      userId: _userId,
      limit: _pageSize,
      offset: filtered.length,
      isHealthy: isHealthy,
      cropTypes: cropTypeFilter.isNotEmpty ? cropTypeFilter.toList() : null,
      dateFrom: dateFrom?.millisecondsSinceEpoch,
      dateTo: dateTo?.add(const Duration(days: 1)).millisecondsSinceEpoch,
      searchQuery: searchQuery,
      orderBy: orderBy,
    );

    if (result.isSuccess) {
      final newItems = result.data ?? [];
      filtered.addAll(newItems);
      hasMore = newItems.length == _pageSize;
    }

    // Load distinct crop types
    final cropsResult =
        await _getHistoryUseCase.getDistinctCropTypes(userId: _userId);
    if (cropsResult.isSuccess) {
      _distinctCropTypes = cropsResult.data ?? [];
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> setFilter(HistoryFilter f) async {
    filter = f;
    await load(reset: true);
  }

  Future<void> setSearch(String q) async {
    searchQuery = q;
    await load(reset: true);
  }

  Future<void> setSort(HistorySort s) async {
    sort = s;
    await load(reset: true);
  }

  Future<void> exportHistory() async {
    // Export handled in UI via ScanReportPdfExporter per scan.
  }

  Future<void> deleteResult(int id) async {
    final result = await _deleteDetectionUseCase(id);
    if (result.isSuccess) {
      await load(reset: true);
    }
  }

  Future<void> restoreDetection(DetectionResult detection) async {
    final result = await _restoreDetectionUseCase(detection);
    if (result.isSuccess) {
      await load(reset: true);
    }
  }
}
