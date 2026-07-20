import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/services/systems_repository.dart';
import 'package:mindful/models/life_system.dart';

final systemsProvider =
    StateNotifierProvider<SystemsNotifier, AsyncValue<List<LifeSystem>>>(
        (ref) => SystemsNotifier());

final selectedFocusSystemProvider = FutureProvider<int?>((ref) async {
  final systemsState = ref.watch(systemsProvider);
  final systems = systemsState.valueOrNull ??
      await SystemsRepository.instance.loadSystems();
  final available = systems
      .where(
        (system) =>
            system.status == LifeSystemStatus.active ||
            system.status == LifeSystemStatus.maintenance,
      )
      .toList();
  if (available.isEmpty) return null;

  final repository = SystemsRepository.instance;
  final stored = await repository.loadSelectedFocusSystemId();
  if (stored != null && available.any((system) => system.id == stored)) {
    return stored;
  }

  final fallback = available.first.id;
  await repository.selectFocusSystem(fallback);
  return fallback;
});

final focusSystemNameProvider = FutureProvider.family<String?, int>(
  (ref, focusSessionId) =>
      SystemsRepository.instance.loadFocusSystemName(focusSessionId),
);

class SystemsNotifier extends StateNotifier<AsyncValue<List<LifeSystem>>> {
  SystemsNotifier() : super(const AsyncLoading()) {
    _subscription = _repository.changes.listen((_) => refresh());
    refresh();
  }

  final SystemsRepository _repository = SystemsRepository.instance;
  late final StreamSubscription<void> _subscription;

  Future<void> refresh() async {
    try {
      final systems = await _repository.loadSystems();
      if (mounted) state = AsyncData(systems);
    } catch (error, stackTrace) {
      debugPrint('SystemsRepository.loadSystems failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) state = AsyncError(error, stackTrace);
    }
  }

  Future<int> save(LifeSystemDraft draft, {int? id}) async {
    final systemId = await _repository.saveSystem(draft, id: id);
    await refresh();
    return systemId;
  }

  Future<void> setVictoryProgress(
    int systemId,
    SystemVictory victory,
    int count,
  ) =>
      _repository.setVictoryProgress(systemId, victory, count);

  Future<void> completeMinimumVersion(int systemId) =>
      _repository.completeMinimumVersion(systemId);

  Future<void> toggleRule(int systemId, SystemRule rule) =>
      _repository.toggleRule(systemId, rule);

  Future<void> changeFrictionStatus(
    int systemId,
    SystemFriction friction,
    SystemFrictionStatus status,
  ) =>
      _repository.changeFrictionStatus(systemId, friction, status);

  Future<void> changeStatus(int systemId, LifeSystemStatus status) =>
      _repository.changeStatus(systemId, status);

  Future<void> recordComeback({
    required int systemId,
    required String difficulty,
    required String action,
  }) =>
      _repository.recordComeback(
        systemId: systemId,
        difficulty: difficulty,
        action: action,
      );

  Future<void> recordReview({
    required int systemId,
    required String reflection,
    required String nextCommitment,
    required bool isExpress,
  }) =>
      _repository.recordReview(
        systemId: systemId,
        reflection: reflection,
        nextCommitment: nextCommitment,
        isExpress: isExpress,
      );

  Future<void> delete(int systemId) => _repository.deleteSystem(systemId);

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
