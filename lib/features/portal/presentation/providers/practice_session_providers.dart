import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local_cache_repository.dart';
import '../../data/portal_models.dart';
import '../../data/practice_protocol_models.dart';

class PracticeSessionState {
  const PracticeSessionState({
    required this.activityId,
    this.focusedTaskId,
    this.isInitialized = false,
    this.restoredFromCache = false,
    this.taskStates = const <String, PracticeTaskState>{},
  });

  final String activityId;
  final String? focusedTaskId;
  final bool isInitialized;
  final bool restoredFromCache;
  final Map<String, PracticeTaskState> taskStates;

  PracticeSessionState copyWith({
    String? focusedTaskId,
    bool? isInitialized,
    bool? restoredFromCache,
    Map<String, PracticeTaskState>? taskStates,
  }) {
    return PracticeSessionState(
      activityId: activityId,
      focusedTaskId: focusedTaskId ?? this.focusedTaskId,
      isInitialized: isInitialized ?? this.isInitialized,
      restoredFromCache: restoredFromCache ?? this.restoredFromCache,
      taskStates: taskStates ?? this.taskStates,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'activityId': activityId,
      'focusedTaskId': focusedTaskId,
      'isInitialized': isInitialized,
      'restoredFromCache': restoredFromCache,
      'taskStates': taskStates.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
    };
  }

  factory PracticeSessionState.fromMap(Map<String, dynamic> map) {
    final rawTaskStates = map['taskStates'];
    final taskStates = <String, PracticeTaskState>{};
    if (rawTaskStates is Map) {
      for (final entry in rawTaskStates.entries) {
        final key = '${entry.key}';
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          taskStates[key] = PracticeTaskState.fromMap(value);
        } else if (value is Map) {
          taskStates[key] = PracticeTaskState.fromMap(
            value.cast<String, dynamic>(),
          );
        }
      }
    }
    return PracticeSessionState(
      activityId: map['activityId'] as String? ?? '',
      focusedTaskId: map['focusedTaskId'] as String?,
      isInitialized: map['isInitialized'] as bool? ?? false,
      restoredFromCache: map['restoredFromCache'] as bool? ?? false,
      taskStates: taskStates,
    );
  }
}

class PracticeSessionNotifier extends StateNotifier<PracticeSessionState> {
  PracticeSessionNotifier(this.activityId, this._cacheRepository)
    : super(PracticeSessionState(activityId: activityId)) {
    _restore();
  }

  final String activityId;
  final LocalCacheRepository _cacheRepository;
  static const Uuid _uuid = Uuid();

  String get _cacheKey => 'practice_session_$activityId';

  Future<void> _restore() async {
    final cachedMap = await _cacheRepository.readJson(_cacheKey);
    if (cachedMap == null) {
      return;
    }
    final restored = PracticeSessionState.fromMap(cachedMap);
    final mergedTaskStates = <String, PracticeTaskState>{};
    final allTaskIds = <String>{
      ...restored.taskStates.keys,
      ...state.taskStates.keys,
    };
    for (final taskId in allTaskIds) {
      final restoredState = restored.taskStates[taskId];
      final currentState = state.taskStates[taskId];
      if (currentState == null) {
        if (restoredState != null) {
          mergedTaskStates[taskId] = restoredState;
        }
        continue;
      }
      if (_hasMeaningfulProgress(currentState)) {
        mergedTaskStates[taskId] = currentState;
      } else if (restoredState != null) {
        mergedTaskStates[taskId] = restoredState;
      } else {
        mergedTaskStates[taskId] = currentState;
      }
    }

    state = state.copyWith(
      focusedTaskId: state.focusedTaskId ?? restored.focusedTaskId,
      isInitialized: state.isInitialized || restored.isInitialized,
      restoredFromCache: mergedTaskStates.values.any(_hasMeaningfulProgress),
      taskStates: mergedTaskStates,
    );
  }

  Future<void> _persist() {
    return _cacheRepository.writeJson(_cacheKey, state.toMap());
  }

  bool _hasMeaningfulProgress(PracticeTaskState taskState) {
    return taskState.isCompleted ||
        taskState.attemptUuid != null ||
        (taskState.selectedValue ?? '').trim().isNotEmpty ||
        taskState.selectedTokens.isNotEmpty ||
        taskState.syncStatus != PracticeTaskSyncStatus.idle;
  }

  void ensureInitialized(
    List<PortalTask> tasks, {
    String? initialFocusedTaskId,
  }) {
    if (tasks.isEmpty) {
      return;
    }

    final nextTaskStates = <String, PracticeTaskState>{
      for (final task in tasks)
        task.id:
            state.taskStates[task.id] ?? PracticeTaskState.initial(task.id),
    };

    final safeFocusedTaskId =
        tasks.any((task) => task.id == state.focusedTaskId)
        ? state.focusedTaskId
        : initialFocusedTaskId ?? tasks.first.id;

    final hasAllTasks =
        state.taskStates.length == nextTaskStates.length &&
        tasks.every((task) => state.taskStates.containsKey(task.id));
    if (state.isInitialized &&
        hasAllTasks &&
        state.focusedTaskId == safeFocusedTaskId) {
      return;
    }

    state = state.copyWith(
      focusedTaskId: safeFocusedTaskId,
      isInitialized: true,
      taskStates: nextTaskStates,
    );
    _persist();
  }

  void focusTask(String taskId) {
    state = state.copyWith(focusedTaskId: taskId);
    _persist();
  }

  void acknowledgeRestore() {
    if (!state.restoredFromCache) {
      return;
    }
    state = state.copyWith(restoredFromCache: false);
    _persist();
  }

  String startAttempt(String taskId) {
    final attemptUuid = _uuid.v4();
    final taskState =
        state.taskStates[taskId] ?? PracticeTaskState.initial(taskId);
    final nextStates = Map<String, PracticeTaskState>.from(state.taskStates)
      ..[taskId] = taskState.copyWith(
        attemptUuid: attemptUuid,
        syncStatus: PracticeTaskSyncStatus.pending,
      );
    state = state.copyWith(taskStates: nextStates, focusedTaskId: taskId);
    _persist();
    return attemptUuid;
  }

  void updateSyncStatus(String taskId, PracticeTaskSyncStatus syncStatus) {
    final taskState =
        state.taskStates[taskId] ?? PracticeTaskState.initial(taskId);
    final nextStates = Map<String, PracticeTaskState>.from(state.taskStates)
      ..[taskId] = taskState.copyWith(syncStatus: syncStatus);
    state = state.copyWith(taskStates: nextStates);
    _persist();
  }

  void updateWordBankSelection(
    String taskId,
    List<String> selectedTokens, {
    bool isCompleted = false,
  }) {
    final taskState =
        state.taskStates[taskId] ?? PracticeTaskState.initial(taskId);
    final normalizedValue = selectedTokens.join(' ').trim();
    final nextStates = Map<String, PracticeTaskState>.from(state.taskStates)
      ..[taskId] = taskState.copyWith(
        selectedTokens: List<String>.from(selectedTokens),
        selectedValue: normalizedValue.isEmpty ? null : normalizedValue,
        isCompleted: isCompleted,
      );
    state = state.copyWith(taskStates: nextStates);
    _persist();
  }

  void updateSingleChoiceSelection(
    String taskId,
    String? selectedValue, {
    bool isCompleted = false,
  }) {
    final taskState =
        state.taskStates[taskId] ?? PracticeTaskState.initial(taskId);
    final nextStates = Map<String, PracticeTaskState>.from(state.taskStates)
      ..[taskId] = taskState.copyWith(
        selectedValue: selectedValue,
        isCompleted: isCompleted,
      );
    state = state.copyWith(taskStates: nextStates);
    _persist();
  }

  void markTaskCompleted(String taskId) {
    final taskState =
        state.taskStates[taskId] ?? PracticeTaskState.initial(taskId);
    final nextStates = Map<String, PracticeTaskState>.from(state.taskStates)
      ..[taskId] = taskState.copyWith(
        isCompleted: true,
        syncStatus: PracticeTaskSyncStatus.synced,
      );
    state = state.copyWith(taskStates: nextStates);
    _persist();
  }
}

final practiceSessionProvider =
    StateNotifierProvider.family<
      PracticeSessionNotifier,
      PracticeSessionState,
      String
    >(
      (ref, activityId) => PracticeSessionNotifier(
        activityId,
        ref.watch(localCacheRepositoryProvider),
      ),
    );
