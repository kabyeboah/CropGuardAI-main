import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/usecases/history/get_history_usecase.dart';
import 'package:cropguard_flutter/domain/usecases/history/delete_detection_usecase.dart';
import 'package:cropguard_flutter/domain/usecases/history/restore_detection_usecase.dart';
import 'package:cropguard_flutter/domain/repositories/i_detection_repository.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/presentation/screens/history/history_provider.dart';

class _MockDetectionRepo extends Mock implements IDetectionRepository {}
class _MockAuthRepo extends Mock implements IAuthRepository {}

DetectionResult _result({
  int id = 1,
  bool isHealthy = false,
  String cropType = 'Tomato',
  double confidence = 0.9,
  int timestamp = 1_000,
}) =>
    DetectionResult(
      id: id,
      imagePath: '/img/$id.jpg',
      diseaseLabel: 'Tomato___Early_blight',
      displayName: 'Tomato Early Blight',
      confidence: confidence,
      isHealthy: isHealthy,
      cropType: cropType,
      cause: 'Alternaria',
      treatments: const ['Fungicide'],
      timestamp: timestamp,
    );

void main() {
  late _MockDetectionRepo repo;
  late _MockAuthRepo authRepo;
  late GetHistoryUseCase getHistory;
  late DeleteDetectionUseCase deleteDetection;
  late RestoreDetectionUseCase restoreDetection;

  setUp(() {
    repo = _MockDetectionRepo();
    authRepo = _MockAuthRepo();
    getHistory = GetHistoryUseCase(repo);
    deleteDetection = DeleteDetectionUseCase(repo);
    restoreDetection = RestoreDetectionUseCase(repo);
    registerFallbackValue(_result());

    when(() => authRepo.currentUser).thenReturn(null);
  });

  HistoryProvider build(List<DetectionResult> items) {
    when(() => repo.getHistory(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          isHealthy: any(named: 'isHealthy'),
          cropTypes: any(named: 'cropTypes'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          searchQuery: any(named: 'searchQuery'),
          orderBy: any(named: 'orderBy'),
        )).thenAnswer((invocation) async {
      final isHealthy = invocation.namedArguments[#isHealthy] as bool?;
      final cropTypes = invocation.namedArguments[#cropTypes] as List<String>?;
      final searchQuery = invocation.namedArguments[#searchQuery] as String?;
      final orderBy = invocation.namedArguments[#orderBy] as String?;

      var list = List<DetectionResult>.from(items);
      if (isHealthy != null) {
        list = list.where((r) => r.isHealthy == isHealthy).toList();
      }
      if (cropTypes != null && cropTypes.isNotEmpty) {
        list = list.where((r) => cropTypes.contains(r.cropType)).toList();
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        list = list
            .where((r) =>
                r.displayName.toLowerCase().contains(q) ||
                r.cropType.toLowerCase().contains(q))
            .toList();
      }

      if (orderBy != null) {
        if (orderBy.contains('timestamp ASC')) {
          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        } else if (orderBy.contains('timestamp DESC')) {
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        } else if (orderBy.contains('confidence ASC')) {
          list.sort((a, b) => a.confidence.compareTo(b.confidence));
        } else if (orderBy.contains('confidence DESC')) {
          list.sort((a, b) => b.confidence.compareTo(a.confidence));
        } else if (orderBy.contains('cropType ASC')) {
          list.sort((a, b) => a.cropType.compareTo(b.cropType));
        }
      }
      return Result.success(list);
    });

    when(() => repo.getDistinctCropTypes(userId: any(named: 'userId')))
        .thenAnswer((_) async => Result.success(items.map((e) => e.cropType).toSet().toList()));

    when(() => repo.deleteDetection(any()))
        .thenAnswer((_) async => Result.success(null));
    when(() => repo.saveDetection(any()))
        .thenAnswer((_) async => Result.success(99));

    return HistoryProvider(getHistory, deleteDetection, restoreDetection, authRepo);
  }

  group('HistoryProvider — filtering', () {
    test('filter all shows all items', () async {
      final provider = build([_result(id: 1), _result(id: 2, isHealthy: true)]);
      await Future<void>.delayed(Duration.zero); // let load() complete
      expect(provider.filtered.length, 2);
    });

    test('filter diseased hides healthy items', () async {
      final provider = build([
        _result(id: 1, isHealthy: false),
        _result(id: 2, isHealthy: true),
      ]);
      await Future<void>.delayed(Duration.zero);
      await provider.setFilter(HistoryFilter.diseased);
      expect(provider.filtered.every((r) => !r.isHealthy), isTrue);
    });

    test('filter healthy hides diseased items', () async {
      final provider = build([
        _result(id: 1, isHealthy: false),
        _result(id: 2, isHealthy: true),
      ]);
      await Future<void>.delayed(Duration.zero);
      await provider.setFilter(HistoryFilter.healthy);
      expect(provider.filtered.every((r) => r.isHealthy), isTrue);
    });

    test('search query filters by displayName', () async {
      final items = [
        _result(id: 1),
        const DetectionResult(
          id: 2,
          imagePath: '/img/2.jpg',
          diseaseLabel: 'Apple___healthy',
          displayName: 'Healthy Apple',
          confidence: 0.99,
          isHealthy: true,
          cropType: 'Apple',
          cause: '',
          treatments: [],
          timestamp: 2_000,
        ),
      ];
      final provider = build(items);
      await Future<void>.delayed(Duration.zero);
      await provider.setSearch('apple');
      expect(provider.filtered.length, 1);
      expect(provider.filtered.first.cropType, 'Apple');
    });

    test('cropType filter excludes non-matching crops', () async {
      final provider = build([
        _result(id: 1, cropType: 'Tomato'),
        _result(id: 2, cropType: 'Rice'),
      ]);
      await Future<void>.delayed(Duration.zero);
      await provider.setCropTypeFilter('Tomato');
      expect(provider.filtered.every((r) => r.cropType == 'Tomato'), isTrue);
    });

    test('clearFilters restores full list', () async {
      final provider = build([
        _result(id: 1, cropType: 'Tomato'),
        _result(id: 2, cropType: 'Rice'),
      ]);
      await Future<void>.delayed(Duration.zero);
      await provider.setCropTypeFilter('Tomato');
      await provider.clearFilters();
      expect(provider.filtered.length, 2);
    });
  });

  group('HistoryProvider — sort', () {
    test('dateNewest puts latest timestamp first', () async {
      final provider = build([
        _result(id: 1, timestamp: 100),
        _result(id: 2, timestamp: 200),
      ]);
      await Future<void>.delayed(Duration.zero);
      await provider.setSort(HistorySort.dateNewest);
      expect(provider.filtered.first.id, 2);
    });

    test('confidenceDesc puts highest confidence first', () async {
      final provider = build([
        _result(id: 1, confidence: 0.6),
        _result(id: 2, confidence: 0.9),
      ]);
      await Future<void>.delayed(Duration.zero);
      await provider.setSort(HistorySort.confidenceDesc);
      expect(provider.filtered.first.id, 2);
    });
  });

  group('HistoryProvider — comparison mode', () {
    test('toggleComparisonMode flips the flag', () async {
      final provider = build([]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.comparisonMode, isFalse);
      provider.toggleComparisonMode();
      expect(provider.comparisonMode, isTrue);
    });

    test('toggleSelection adds ids up to 2 then slides the window', () async {
      final provider = build([]);
      await Future<void>.delayed(Duration.zero);
      provider.toggleComparisonMode();
      provider.toggleSelection(1);
      provider.toggleSelection(2);
      provider.toggleSelection(3);
      expect(provider.selectedIds, [2, 3]);
    });
  });

  group('HistoryProvider — export mode', () {
    test('enterExportMode sets flag and pre-selects id', () async {
      final provider = build([]);
      await Future<void>.delayed(Duration.zero);
      provider.enterExportMode(42);
      expect(provider.exportMode, isTrue);
      expect(provider.exportSelectedIds, contains(42));
    });

    test('exitExportMode clears state', () async {
      final provider = build([]);
      await Future<void>.delayed(Duration.zero);
      provider.enterExportMode(42);
      provider.exitExportMode();
      expect(provider.exportMode, isFalse);
      expect(provider.exportSelectedIds, isEmpty);
    });
  });
}
