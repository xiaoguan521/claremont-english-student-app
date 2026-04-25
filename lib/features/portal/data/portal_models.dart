enum ActivityStatus { active, reviewPending, completed }

enum TaskKind { dubbing, recording, phonics }

enum TaskReviewStatus { checked, pendingReview, inProgress }

enum SubmissionFlowStatus { notStarted, queued, processing, completed, failed }

enum PortalTaskReviewSource { ai, aiRetainedAfterTeacherReview }

enum PortalActivityReviewSource { none, aiOnly, teacherReviewed }

class PortalTaskRegion {
  const PortalTaskRegion({
    required this.id,
    required this.pageNumber,
    required this.pageImagePath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String id;
  final int pageNumber;
  final String pageImagePath;
  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'pageNumber': pageNumber,
      'pageImagePath': pageImagePath,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  factory PortalTaskRegion.fromMap(Map<String, dynamic> map) {
    return PortalTaskRegion(
      id: map['id'] as String? ?? '',
      pageNumber: (map['pageNumber'] as num?)?.toInt() ?? 0,
      pageImagePath: map['pageImagePath'] as String? ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      width: (map['width'] as num?)?.toDouble() ?? 0,
      height: (map['height'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PortalTask {
  const PortalTask({
    required this.id,
    required this.title,
    required this.kind,
    required this.reviewStatus,
    required this.previewAsset,
    this.review,
    this.promptText,
    this.ttsText,
    this.expectedText,
    this.startPage,
    this.endPage,
    this.referenceAudioPath,
    this.teachingVideoPath,
    this.region,
  });

  final String id;
  final String title;
  final TaskKind kind;
  final TaskReviewStatus reviewStatus;
  final String previewAsset;
  final PortalTaskReview? review;
  final String? promptText;
  final String? ttsText;
  final String? expectedText;
  final int? startPage;
  final int? endPage;
  final String? referenceAudioPath;
  final String? teachingVideoPath;
  final PortalTaskRegion? region;

  bool get hasTtsText => (ttsText ?? '').trim().isNotEmpty;
  bool get hasPageRange => startPage != null || endPage != null;
  bool get hasReferenceAudio => (referenceAudioPath ?? '').trim().isNotEmpty;
  bool get hasTeachingVideo => (teachingVideoPath ?? '').trim().isNotEmpty;
  bool get hasReview => review != null;
  bool get hasRegion => region != null;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'kind': kind.name,
      'reviewStatus': reviewStatus.name,
      'previewAsset': previewAsset,
      'review': review?.toMap(),
      'promptText': promptText,
      'ttsText': ttsText,
      'expectedText': expectedText,
      'startPage': startPage,
      'endPage': endPage,
      'referenceAudioPath': referenceAudioPath,
      'teachingVideoPath': teachingVideoPath,
      'region': region?.toMap(),
    };
  }

  factory PortalTask.fromMap(Map<String, dynamic> map) {
    return PortalTask(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      kind: _taskKindFromName(map['kind'] as String?),
      reviewStatus: _taskReviewStatusFromName(map['reviewStatus'] as String?),
      previewAsset: map['previewAsset'] as String? ?? '',
      review: _mapOrNull(map['review']) == null
          ? null
          : PortalTaskReview.fromMap(_mapOrNull(map['review'])!),
      promptText: map['promptText'] as String?,
      ttsText: map['ttsText'] as String?,
      expectedText: map['expectedText'] as String?,
      startPage: (map['startPage'] as num?)?.toInt(),
      endPage: (map['endPage'] as num?)?.toInt(),
      referenceAudioPath: map['referenceAudioPath'] as String?,
      teachingVideoPath: map['teachingVideoPath'] as String?,
      region: _mapOrNull(map['region']) == null
          ? null
          : PortalTaskRegion.fromMap(_mapOrNull(map['region'])!),
    );
  }
}

class PortalTaskReview {
  const PortalTaskReview({
    required this.score,
    required this.summaryFeedback,
    required this.encouragement,
    this.source = PortalTaskReviewSource.ai,
    this.sourceLabel = 'AI 句子点评',
    this.pronunciationScore,
    this.fluencyScore,
    this.completenessScore,
    this.strengths = const [],
    this.improvementPoints = const [],
  });

  final double score;
  final String summaryFeedback;
  final String encouragement;
  final PortalTaskReviewSource source;
  final String sourceLabel;
  final double? pronunciationScore;
  final double? fluencyScore;
  final double? completenessScore;
  final List<String> strengths;
  final List<String> improvementPoints;

  bool get isTeacherReviewedReference =>
      source == PortalTaskReviewSource.aiRetainedAfterTeacherReview;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'score': score,
      'summaryFeedback': summaryFeedback,
      'encouragement': encouragement,
      'source': source.name,
      'sourceLabel': sourceLabel,
      'pronunciationScore': pronunciationScore,
      'fluencyScore': fluencyScore,
      'completenessScore': completenessScore,
      'strengths': strengths,
      'improvementPoints': improvementPoints,
    };
  }

  factory PortalTaskReview.fromMap(Map<String, dynamic> map) {
    return PortalTaskReview(
      score: (map['score'] as num?)?.toDouble() ?? 0,
      summaryFeedback: map['summaryFeedback'] as String? ?? '',
      encouragement: map['encouragement'] as String? ?? '',
      source: _reviewSourceFromName(map['source'] as String?),
      sourceLabel: map['sourceLabel'] as String? ?? 'AI 句子点评',
      pronunciationScore: (map['pronunciationScore'] as num?)?.toDouble(),
      fluencyScore: (map['fluencyScore'] as num?)?.toDouble(),
      completenessScore: (map['completenessScore'] as num?)?.toDouble(),
      strengths: (map['strengths'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      improvementPoints:
          (map['improvementPoints'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
    );
  }
}

class PortalActivity {
  const PortalActivity({
    required this.id,
    required this.title,
    required this.className,
    required this.dateLabel,
    required this.dueDate,
    required this.status,
    required this.reviewCount,
    required this.inspectCount,
    required this.urgeCount,
    required this.completionRate,
    required this.tasks,
    required this.submissionFlowStatus,
    this.submissionId,
    this.submittedAt,
    this.latestScore,
    this.latestFeedback,
    this.encouragement,
    this.strengths = const [],
    this.improvementPoints = const [],
    this.submissionAudioName,
    this.submissionAudioPath,
    this.description,
    this.materialTitle,
    this.materialPdfPath,
    this.materialPageCount,
    this.submissionStatusHint,
    this.reviewSource = PortalActivityReviewSource.none,
  });

  final String id;
  final String title;
  final String className;
  final String dateLabel;
  final DateTime? dueDate;
  final ActivityStatus status;
  final int reviewCount;
  final int inspectCount;
  final int urgeCount;
  final double completionRate;
  final List<PortalTask> tasks;
  final SubmissionFlowStatus submissionFlowStatus;
  final String? submissionId;
  final DateTime? submittedAt;
  final double? latestScore;
  final String? latestFeedback;
  final String? encouragement;
  final List<String> strengths;
  final List<String> improvementPoints;
  final String? submissionAudioName;
  final String? submissionAudioPath;
  final String? description;
  final String? materialTitle;
  final String? materialPdfPath;
  final int? materialPageCount;
  final String? submissionStatusHint;
  final PortalActivityReviewSource reviewSource;

  bool get hasTeacherFeedback =>
      submissionFlowStatus == SubmissionFlowStatus.completed &&
      (latestScore != null ||
          latestFeedback != null ||
          encouragement != null ||
          strengths.isNotEmpty ||
          improvementPoints.isNotEmpty);

  bool get hasAiReview =>
      reviewSource == PortalActivityReviewSource.aiOnly ||
      reviewSource == PortalActivityReviewSource.teacherReviewed;

  bool get hasTeacherReviewedResult =>
      reviewSource == PortalActivityReviewSource.teacherReviewed;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'className': className,
      'dateLabel': dateLabel,
      'dueDate': dueDate?.toIso8601String(),
      'status': status.name,
      'reviewCount': reviewCount,
      'inspectCount': inspectCount,
      'urgeCount': urgeCount,
      'completionRate': completionRate,
      'tasks': tasks.map((task) => task.toMap()).toList(),
      'submissionFlowStatus': submissionFlowStatus.name,
      'submissionId': submissionId,
      'submittedAt': submittedAt?.toIso8601String(),
      'latestScore': latestScore,
      'latestFeedback': latestFeedback,
      'encouragement': encouragement,
      'strengths': strengths,
      'improvementPoints': improvementPoints,
      'submissionAudioName': submissionAudioName,
      'submissionAudioPath': submissionAudioPath,
      'description': description,
      'materialTitle': materialTitle,
      'materialPdfPath': materialPdfPath,
      'materialPageCount': materialPageCount,
      'submissionStatusHint': submissionStatusHint,
      'reviewSource': reviewSource.name,
    };
  }

  factory PortalActivity.fromMap(Map<String, dynamic> map) {
    return PortalActivity(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      className: map['className'] as String? ?? '',
      dateLabel: map['dateLabel'] as String? ?? '',
      dueDate: _dateTimeOrNull(map['dueDate'] as String?),
      status: _activityStatusFromName(map['status'] as String?),
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      inspectCount: (map['inspectCount'] as num?)?.toInt() ?? 0,
      urgeCount: (map['urgeCount'] as num?)?.toInt() ?? 0,
      completionRate: (map['completionRate'] as num?)?.toDouble() ?? 0,
      tasks: (map['tasks'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => PortalTask.fromMap(item.cast<String, dynamic>()))
          .toList(),
      submissionFlowStatus: _submissionFlowStatusFromName(
        map['submissionFlowStatus'] as String?,
      ),
      submissionId: map['submissionId'] as String?,
      submittedAt: _dateTimeOrNull(map['submittedAt'] as String?),
      latestScore: (map['latestScore'] as num?)?.toDouble(),
      latestFeedback: map['latestFeedback'] as String?,
      encouragement: map['encouragement'] as String?,
      strengths: (map['strengths'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      improvementPoints:
          (map['improvementPoints'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      submissionAudioName: map['submissionAudioName'] as String?,
      submissionAudioPath: map['submissionAudioPath'] as String?,
      description: map['description'] as String?,
      materialTitle: map['materialTitle'] as String?,
      materialPdfPath: map['materialPdfPath'] as String?,
      materialPageCount: (map['materialPageCount'] as num?)?.toInt(),
      submissionStatusHint: map['submissionStatusHint'] as String?,
      reviewSource: _activityReviewSourceFromName(
        map['reviewSource'] as String?,
      ),
    );
  }
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return null;
}

DateTime? _dateTimeOrNull(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

TaskKind _taskKindFromName(String? value) {
  return TaskKind.values.firstWhere(
    (item) => item.name == value,
    orElse: () => TaskKind.recording,
  );
}

TaskReviewStatus _taskReviewStatusFromName(String? value) {
  return TaskReviewStatus.values.firstWhere(
    (item) => item.name == value,
    orElse: () => TaskReviewStatus.inProgress,
  );
}

PortalTaskReviewSource _reviewSourceFromName(String? value) {
  return PortalTaskReviewSource.values.firstWhere(
    (item) => item.name == value,
    orElse: () => PortalTaskReviewSource.ai,
  );
}

ActivityStatus _activityStatusFromName(String? value) {
  return ActivityStatus.values.firstWhere(
    (item) => item.name == value,
    orElse: () => ActivityStatus.active,
  );
}

SubmissionFlowStatus _submissionFlowStatusFromName(String? value) {
  return SubmissionFlowStatus.values.firstWhere(
    (item) => item.name == value,
    orElse: () => SubmissionFlowStatus.notStarted,
  );
}

PortalActivityReviewSource _activityReviewSourceFromName(String? value) {
  return PortalActivityReviewSource.values.firstWhere(
    (item) => item.name == value,
    orElse: () => PortalActivityReviewSource.none,
  );
}

final mockPortalActivities = [
  PortalActivity(
    id: 'h-7day',
    title: '7天打卡活动',
    className: '精品英语H班',
    dateLabel: '4.18 - 4.24',
    dueDate: DateTime(2026, 4, 24),
    status: ActivityStatus.active,
    reviewCount: 3,
    inspectCount: 0,
    urgeCount: 5,
    completionRate: 1,
    submissionFlowStatus: SubmissionFlowStatus.completed,
    submittedAt: DateTime(2026, 4, 18, 19, 30),
    latestScore: 95,
    latestFeedback: '你这次的朗读很稳定，句子衔接自然，老师已经听得很清楚了。',
    encouragement: '继续保持这个节奏，下一次把句尾再收紧一点会更棒。',
    strengths: ['开头发音清晰', '整体节奏稳定'],
    improvementPoints: ['句尾收音再干净一点'],
    submissionAudioName: 'module7-reading.m4a',
    submissionAudioPath: 'demo-submission/module7-reading.m4a',
    description: '完成 Module 7 的示范朗读与录音提交。',
    materialTitle: 'Module 7 阅读教材',
    materialPdfPath: 'demo-materials/module-7.pdf',
    materialPageCount: 8,
    tasks: [
      const PortalTask(
        id: 'h-1',
        title: '8 能和不能',
        kind: TaskKind.dubbing,
        reviewStatus: TaskReviewStatus.checked,
        previewAsset: '视频配音',
        promptText: 'Read the sentence about things you can and cannot do.',
        ttsText: 'I can swim, but I cannot dive.',
        expectedText: 'I can swim, but I cannot dive.',
        startPage: 1,
        endPage: 1,
      ),
      const PortalTask(
        id: 'h-2',
        title: 'Module 7-2',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.checked,
        previewAsset: '录音',
        promptText: 'Read the second sentence clearly and confidently.',
        ttsText: 'He can sing well, but he cannot skate.',
        expectedText: 'He can sing well, but he cannot skate.',
        startPage: 2,
        endPage: 2,
      ),
      const PortalTask(
        id: 'h-3',
        title: 'Module 7-3',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.checked,
        previewAsset: '录音',
        promptText: 'Finish the short sentence practice.',
        ttsText: 'We can jump high, but we cannot fly.',
        expectedText: 'We can jump high, but we cannot fly.',
        startPage: 3,
        endPage: 3,
      ),
      const PortalTask(
        id: 'h-4',
        title: 'Module 8-1',
        kind: TaskKind.phonics,
        reviewStatus: TaskReviewStatus.pendingReview,
        previewAsset: '自然拼读',
        promptText:
            'Read the phonics line and pay attention to the vowel sound.',
        ttsText: 'Cake, make, take.',
        expectedText: 'Cake, make, take.',
        startPage: 4,
        endPage: 4,
      ),
    ],
  ),
  PortalActivity(
    id: 'z-7day',
    title: '7天打卡活动',
    className: '精品英语Z班',
    dateLabel: '4.18 - 4.24',
    dueDate: DateTime(2026, 4, 24),
    status: ActivityStatus.active,
    reviewCount: 3,
    inspectCount: 0,
    urgeCount: 5,
    completionRate: 0.86,
    submissionFlowStatus: SubmissionFlowStatus.notStarted,
    description: '完成 Module 5 朗读并提交音频。',
    materialTitle: 'Module 5 阅读教材',
    materialPdfPath: 'demo-materials/module-5.pdf',
    materialPageCount: 10,
    tasks: [
      const PortalTask(
        id: 'z-1',
        title: 'Module 5-1',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.inProgress,
        previewAsset: '录音',
        promptText: 'Read the first sentence aloud.',
        ttsText: 'She can ride a bike quickly.',
        expectedText: 'She can ride a bike quickly.',
        startPage: 1,
        endPage: 1,
      ),
      const PortalTask(
        id: 'z-2',
        title: 'Module 5-2',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.checked,
        previewAsset: '录音',
        promptText: 'Read the next sentence slowly and clearly.',
        ttsText: 'They cannot open the heavy door.',
        expectedText: 'They cannot open the heavy door.',
        startPage: 2,
        endPage: 2,
      ),
      const PortalTask(
        id: 'z-3',
        title: '课堂短剧',
        kind: TaskKind.dubbing,
        reviewStatus: TaskReviewStatus.pendingReview,
        previewAsset: '视频配音',
        promptText: 'Practice the short dialogue.',
        ttsText: 'Can you help me? Yes, I can.',
        expectedText: 'Can you help me? Yes, I can.',
        startPage: 3,
        endPage: 4,
      ),
    ],
  ),
  PortalActivity(
    id: 't-7day',
    title: '7天打卡活动',
    className: '精品英语T班',
    dateLabel: '4.17 - 4.23',
    dueDate: DateTime(2026, 4, 23),
    status: ActivityStatus.reviewPending,
    reviewCount: 6,
    inspectCount: 0,
    urgeCount: 6,
    completionRate: 0.72,
    submissionFlowStatus: SubmissionFlowStatus.queued,
    submittedAt: DateTime(2026, 4, 19, 9, 15),
    submissionAudioName: 'module3-reading.wav',
    submissionAudioPath: 'demo-submission/module3-reading.wav',
    description: '完成 Module 3 课后朗读并等待老师点评。',
    materialTitle: 'Module 3 阅读教材',
    materialPdfPath: 'demo-materials/module-3.pdf',
    materialPageCount: 6,
    tasks: [
      const PortalTask(
        id: 't-1',
        title: 'Module 3-1',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.pendingReview,
        previewAsset: '录音',
        promptText: 'Read the sentence with a smooth rhythm.',
        ttsText: 'I can read, but I cannot write fast.',
        expectedText: 'I can read, but I cannot write fast.',
        startPage: 1,
        endPage: 1,
      ),
      const PortalTask(
        id: 't-2',
        title: 'Module 3-2',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.pendingReview,
        previewAsset: '录音',
        promptText: 'Repeat the next sentence after the model voice.',
        ttsText: 'He can run fast, but he cannot swim.',
        expectedText: 'He can run fast, but he cannot swim.',
        startPage: 2,
        endPage: 2,
      ),
      const PortalTask(
        id: 't-3',
        title: '元音拼读',
        kind: TaskKind.phonics,
        reviewStatus: TaskReviewStatus.checked,
        previewAsset: '自然拼读',
        promptText: 'Read the phonics line clearly.',
        ttsText: 'Bike, like, kite.',
        expectedText: 'Bike, like, kite.',
        startPage: 3,
        endPage: 3,
      ),
    ],
  ),
];
