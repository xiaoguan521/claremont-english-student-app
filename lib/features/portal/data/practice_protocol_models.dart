import 'portal_models.dart';

enum PracticeTaskType {
  audioRepeat,
  wordBank,
  hotspotSelect,
  listenAndChoose,
  unsupported,
}

enum PracticeTaskSyncStatus { idle, pending, syncing, synced, failed }

class PracticeTaskProtocol {
  const PracticeTaskProtocol({
    required this.id,
    required this.type,
    required this.version,
    required this.prompt,
    this.assets = const <String, Object?>{},
    this.content = const <String, Object?>{},
    this.rules = const <String, Object?>{},
    this.feedback = const <String, Object?>{},
    this.analytics = const <String, Object?>{},
  });

  final String id;
  final PracticeTaskType type;
  final int version;
  final String prompt;
  final Map<String, Object?> assets;
  final Map<String, Object?> content;
  final Map<String, Object?> rules;
  final Map<String, Object?> feedback;
  final Map<String, Object?> analytics;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'version': version,
      'prompt': prompt,
      'assets': assets,
      'content': content,
      'rules': rules,
      'feedback': feedback,
      'analytics': analytics,
    };
  }

  factory PracticeTaskProtocol.fromMap(Map<String, Object?> map) {
    return PracticeTaskProtocol(
      id: map['id'] as String? ?? '',
      type: _practiceTaskTypeFromName(map['type'] as String?),
      version: map['version'] as int? ?? 1,
      prompt: map['prompt'] as String? ?? '',
      assets: Map<String, Object?>.from(
        map['assets'] as Map<Object?, Object?>? ?? const <Object?, Object?>{},
      ),
      content: Map<String, Object?>.from(
        map['content'] as Map<Object?, Object?>? ?? const <Object?, Object?>{},
      ),
      rules: Map<String, Object?>.from(
        map['rules'] as Map<Object?, Object?>? ?? const <Object?, Object?>{},
      ),
      feedback: Map<String, Object?>.from(
        map['feedback'] as Map<Object?, Object?>? ?? const <Object?, Object?>{},
      ),
      analytics: Map<String, Object?>.from(
        map['analytics'] as Map<Object?, Object?>? ??
            const <Object?, Object?>{},
      ),
    );
  }
}

class PracticeTaskState {
  const PracticeTaskState({
    required this.taskId,
    this.attemptUuid,
    this.selectedValue,
    this.selectedTokens = const <String>[],
    this.syncStatus = PracticeTaskSyncStatus.idle,
    this.isCompleted = false,
  });

  const PracticeTaskState.initial(String taskId) : this(taskId: taskId);

  final String taskId;
  final String? attemptUuid;
  final String? selectedValue;
  final List<String> selectedTokens;
  final PracticeTaskSyncStatus syncStatus;
  final bool isCompleted;

  PracticeTaskState copyWith({
    String? attemptUuid,
    String? selectedValue,
    List<String>? selectedTokens,
    PracticeTaskSyncStatus? syncStatus,
    bool? isCompleted,
  }) {
    return PracticeTaskState(
      taskId: taskId,
      attemptUuid: attemptUuid ?? this.attemptUuid,
      selectedValue: selectedValue ?? this.selectedValue,
      selectedTokens: selectedTokens ?? this.selectedTokens,
      syncStatus: syncStatus ?? this.syncStatus,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'taskId': taskId,
      'attemptUuid': attemptUuid,
      'selectedValue': selectedValue,
      'selectedTokens': selectedTokens,
      'syncStatus': syncStatus.name,
      'isCompleted': isCompleted,
    };
  }

  factory PracticeTaskState.fromMap(Map<String, dynamic> map) {
    return PracticeTaskState(
      taskId: map['taskId'] as String? ?? '',
      attemptUuid: map['attemptUuid'] as String?,
      selectedValue: map['selectedValue'] as String?,
      selectedTokens:
          (map['selectedTokens'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      syncStatus: PracticeTaskSyncStatus.values.firstWhere(
        (status) => status.name == map['syncStatus'],
        orElse: () => PracticeTaskSyncStatus.idle,
      ),
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }
}

extension PortalTaskPracticeProtocol on PortalTask {
  PracticeTaskProtocol toPracticeProtocol() {
    final sampleText =
        _firstNonEmpty([ttsText, expectedText, promptText]) ?? title;
    final prompt = _firstNonEmpty([promptText, ttsText, expectedText]) ?? title;

    if (hasRegion) {
      return PracticeTaskProtocol(
        id: id,
        type: PracticeTaskType.hotspotSelect,
        version: 1,
        prompt: prompt,
        assets: <String, Object?>{'pageImagePath': region?.pageImagePath},
        content: <String, Object?>{
          'displayText': sampleText,
          'pageNumber': region?.pageNumber,
          'regionId': region?.id,
        },
        rules: const <String, Object?>{'selectionMode': 'single'},
        feedback: <String, Object?>{'successHint': '点中正确热区就能继续下一步。'},
        analytics: <String, Object?>{'sourceKind': kind.name},
      );
    }

    if (kind == TaskKind.phonics) {
      final optionTokens = _tokenizeChoiceOptions(sampleText);
      final correctOption = optionTokens.isEmpty
          ? sampleText
          : optionTokens.first;
      return PracticeTaskProtocol(
        id: id,
        type: PracticeTaskType.listenAndChoose,
        version: 1,
        prompt: prompt,
        content: <String, Object?>{
          'question': sampleText,
          'options': optionTokens.take(4).toList(),
          'correctOption': correctOption,
        },
        rules: const <String, Object?>{'choiceMode': 'single'},
        feedback: const <String, Object?>{'successHint': '选出听到的正确读音或词组。'},
        analytics: <String, Object?>{'sourceKind': kind.name},
      );
    }

    final expectedTokens = _tokenize(sampleText);
    if (kind == TaskKind.dubbing && expectedTokens.length >= 3) {
      return PracticeTaskProtocol(
        id: id,
        type: PracticeTaskType.wordBank,
        version: 1,
        prompt: prompt,
        content: <String, Object?>{
          'question': sampleText,
          'tokens': _reorderWordBankTokens(expectedTokens),
          'expectedTokens': expectedTokens,
        },
        rules: <String, Object?>{
          'selectionMode': 'tap',
          'maxSelectable': expectedTokens.length,
        },
        feedback: const <String, Object?>{'successHint': '把单词按正确顺序拼成完整句子。'},
        analytics: <String, Object?>{'sourceKind': kind.name},
      );
    }

    return PracticeTaskProtocol(
      id: id,
      type: PracticeTaskType.audioRepeat,
      version: 1,
      prompt: prompt,
      assets: <String, Object?>{
        'referenceAudioPath': referenceAudioPath,
        'teachingVideoPath': teachingVideoPath,
      },
      content: <String, Object?>{'text': sampleText},
      rules: const <String, Object?>{'allowRetry': true},
      feedback: const <String, Object?>{'successHint': '听一听示范，再开口录音。'},
      analytics: <String, Object?>{'sourceKind': kind.name},
    );
  }
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

PracticeTaskType _practiceTaskTypeFromName(String? value) {
  return PracticeTaskType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => PracticeTaskType.unsupported,
  );
}

List<String> _tokenize(String input) {
  return input
      .split(RegExp(r'\s+'))
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList();
}

List<String> _tokenizeChoiceOptions(String input) {
  final segmented = input
      .split(RegExp(r'[,\u3001;/]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .map((item) => item.replaceAll(RegExp(r'[.!?]+$'), ''))
      .toList();
  if (segmented.length >= 2) {
    return segmented;
  }
  return _tokenize(input)
      .map((item) => item.replaceAll(RegExp(r'[.!?,]+$'), ''))
      .where((item) => item.isNotEmpty)
      .toList();
}

List<String> _reorderWordBankTokens(List<String> tokens) {
  if (tokens.length <= 2) {
    return List<String>.from(tokens);
  }

  final reordered = <String>[];
  for (var index = 1; index < tokens.length; index += 2) {
    reordered.add(tokens[index]);
  }
  for (var index = 0; index < tokens.length; index += 2) {
    reordered.add(tokens[index]);
  }
  return reordered;
}
