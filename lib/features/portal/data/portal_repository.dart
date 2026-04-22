import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'portal_models.dart';

abstract class PortalRepository {
  Future<List<PortalActivity>> fetchActivities({String? schoolId});

  Future<PortalActivity?> fetchActivityById(
    String activityId, {
    String? schoolId,
  });

  Future<void> submitActivity(String activityId);

  Future<AiReviewDispatchResult> uploadAudioSubmission({
    required String activityId,
    required Uint8List fileBytes,
    required String fileName,
    required int sizeBytes,
    String? mimeType,
  });
}

enum AiReviewDispatchStatus { queued, processing, completed, failed }

class AiReviewDispatchResult {
  const AiReviewDispatchResult({required this.status, this.message});

  final AiReviewDispatchStatus status;
  final String? message;
}

class MockPortalRepository implements PortalRepository {
  const MockPortalRepository();

  @override
  Future<List<PortalActivity>> fetchActivities({String? schoolId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return mockPortalActivities;
  }

  @override
  Future<PortalActivity?> fetchActivityById(
    String activityId, {
    String? schoolId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    for (final activity in mockPortalActivities) {
      if (activity.id == activityId) {
        return activity;
      }
    }
    return null;
  }

  @override
  Future<void> submitActivity(String activityId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<AiReviewDispatchResult> uploadAudioSubmission({
    required String activityId,
    required Uint8List fileBytes,
    required String fileName,
    required int sizeBytes,
    String? mimeType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return const AiReviewDispatchResult(
      status: AiReviewDispatchStatus.completed,
      message: 'Mock 模式下已完成演示点评。',
    );
  }
}

class SupabasePortalRepository implements PortalRepository {
  const SupabasePortalRepository(this._client);

  final SupabaseClient _client;

  Future<void> _triggerImmediateReview(String submissionId) async {
    try {
      await _client.functions.invoke(
        'ai-review-submission',
        body: {'action': 'review_submission', 'submissionId': submissionId},
      );
    } catch (_) {
      // Fallback remains the server-side queue worker.
    }
  }

  @override
  Future<List<PortalActivity>> fetchActivities({String? schoolId}) {
    return _fetchActivitiesInternal(schoolId: schoolId);
  }

  @override
  Future<PortalActivity?> fetchActivityById(
    String activityId, {
    String? schoolId,
  }) async {
    final activities = await _fetchActivitiesInternal(
      schoolId: schoolId,
      onlyActivityId: activityId,
    );
    if (activities.isEmpty) {
      return null;
    }
    return activities.first;
  }

  Future<List<PortalActivity>> _fetchActivitiesInternal({
    String? schoolId,
    String? onlyActivityId,
  }) async {
    final targetSchoolId = schoolId;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }

    final membershipsResponse = await _client
        .from('memberships')
        .select('school_id, class_id, role')
        .eq('user_id', userId)
        .eq('status', 'active');

    final memberships = List<Map<String, dynamic>>.from(membershipsResponse);
    if (memberships.isEmpty) {
      return const [];
    }

    final schoolIds = <String>{};
    final classIds = <String>{};
    var canManageWholeSchool = false;

    for (final membership in memberships) {
      final membershipSchoolId = membership['school_id'] as String?;
      final classId = membership['class_id'] as String?;
      final role = membership['role'] as String?;

      if (targetSchoolId != null && membershipSchoolId != targetSchoolId) {
        continue;
      }

      if (membershipSchoolId != null) {
        schoolIds.add(membershipSchoolId);
      }
      if (classId != null) {
        classIds.add(classId);
      }
      if (role == 'school_admin' && classId == null) {
        canManageWholeSchool = true;
      }
    }

    if (canManageWholeSchool && schoolIds.isNotEmpty) {
      final classesResponse = await _client
          .from('classes')
          .select('id')
          .inFilter('school_id', schoolIds.toList())
          .eq('status', 'active');

      for (final row in List<Map<String, dynamic>>.from(classesResponse)) {
        final id = row['id'] as String?;
        if (id != null) {
          classIds.add(id);
        }
      }
    }

    if (classIds.isEmpty) {
      return const [];
    }

    final classesResponse = await _client
        .from('classes')
        .select('id, name')
        .inFilter('id', classIds.toList());
    final classRows = List<Map<String, dynamic>>.from(classesResponse);
    final classNameById = <String, String>{
      for (final row in classRows)
        row['id'] as String: (row['name'] as String?) ?? '未命名班级',
    };

    final assignmentsResponse = await _client
        .from('assignments')
        .select('id, class_id, material_id, title, description, due_at, status')
        .inFilter('class_id', classIds.toList())
        .neq('status', 'archived')
        .order('created_at', ascending: false);
    final assignmentRows = List<Map<String, dynamic>>.from(assignmentsResponse);

    final targetAssignmentRows = onlyActivityId == null
        ? assignmentRows
        : assignmentRows.where((row) => row['id'] == onlyActivityId).toList();

    if (targetAssignmentRows.isEmpty) {
      return const [];
    }

    final assignmentIds = targetAssignmentRows
        .map((row) => row['id'] as String?)
        .whereType<String>()
        .toList();
    final materialIds = targetAssignmentRows
        .map((row) => row['material_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final assignmentItemsResponse = await _client
        .from('assignment_items')
        .select(
          'id, assignment_id, title, item_type, prompt_text, tts_text, expected_text, start_page, end_page, reference_audio_path, sort_order',
        )
        .inFilter('assignment_id', assignmentIds)
        .order('sort_order', ascending: true);
    final itemRows = List<Map<String, dynamic>>.from(assignmentItemsResponse);

    final materialById = <String, Map<String, dynamic>>{};
    if (materialIds.isNotEmpty) {
      final materialsResponse = await _client
          .from('materials')
          .select('id, title, pdf_path, page_count')
          .inFilter('id', materialIds);

      for (final row in List<Map<String, dynamic>>.from(materialsResponse)) {
        final id = row['id'] as String?;
        if (id != null) {
          materialById[id] = row;
        }
      }
    }

    final submissionsResponse = await _client
        .from('submissions')
        .select(
          'id, assignment_id, status, submitted_at, latest_score, latest_feedback',
        )
        .eq('student_id', userId)
        .inFilter('assignment_id', assignmentIds);
    final submissionRows = List<Map<String, dynamic>>.from(submissionsResponse);

    final submissionByAssignmentId = <String, Map<String, dynamic>>{
      for (final row in submissionRows)
        if (row['assignment_id'] is String) row['assignment_id'] as String: row,
    };

    final submissionIds = submissionRows
        .map((row) => row['id'] as String?)
        .whereType<String>()
        .toList();

    final evaluationJobBySubmissionId = <String, Map<String, dynamic>>{};
    if (submissionIds.isNotEmpty) {
      final evaluationJobsResponse = await _client
          .from('evaluation_jobs')
          .select('submission_id, status, last_error, updated_at')
          .inFilter('submission_id', submissionIds)
          .order('updated_at', ascending: false);

      for (final row in List<Map<String, dynamic>>.from(
        evaluationJobsResponse,
      )) {
        final submissionId = row['submission_id'] as String?;
        if (submissionId != null &&
            !evaluationJobBySubmissionId.containsKey(submissionId)) {
          evaluationJobBySubmissionId[submissionId] = row;
        }
      }
    }

    final evaluationBySubmissionId = <String, Map<String, dynamic>>{};
    if (submissionIds.isNotEmpty) {
      final evaluationsResponse = await _client
          .from('evaluation_results')
          .select(
            'submission_id, provider, overall_score, strengths, improvement_points, encouragement, raw_result',
          )
          .inFilter('submission_id', submissionIds);

      for (final row in List<Map<String, dynamic>>.from(evaluationsResponse)) {
        final submissionId = row['submission_id'] as String?;
        if (submissionId != null) {
          evaluationBySubmissionId[submissionId] = row;
        }
      }
    }

    final audioAssetBySubmissionId = <String, Map<String, dynamic>>{};
    if (submissionIds.isNotEmpty) {
      final submissionAssetsResponse = await _client
          .from('submission_assets')
          .select('submission_id, storage_path, created_at')
          .eq('asset_type', 'audio')
          .inFilter('submission_id', submissionIds)
          .order('created_at', ascending: false);

      for (final row in List<Map<String, dynamic>>.from(
        submissionAssetsResponse,
      )) {
        final submissionId = row['submission_id'] as String?;
        if (submissionId != null &&
            !audioAssetBySubmissionId.containsKey(submissionId)) {
          audioAssetBySubmissionId[submissionId] = row;
        }
      }
    }

    final itemsByAssignmentId = <String, List<Map<String, dynamic>>>{};
    for (final item in itemRows) {
      final assignmentId = item['assignment_id'] as String?;
      if (assignmentId == null) {
        continue;
      }
      itemsByAssignmentId.putIfAbsent(assignmentId, () => []).add(item);
    }

    return targetAssignmentRows.map((row) {
      final assignmentId = row['id'] as String;
      final assignmentStatus = (row['status'] as String?) ?? 'published';
      final dueAt = DateTime.tryParse((row['due_at'] as String?) ?? '');
      final submissionRow = submissionByAssignmentId[assignmentId];
      final submissionId = submissionRow?['id'] as String?;
      final submissionFlowStatus = _mapSubmissionFlowStatus(
        submissionRow?['status'] as String?,
      );
      final evaluationRow = submissionId == null
          ? null
          : evaluationBySubmissionId[submissionId];
      final reviewSource = _mapReviewSource(
        evaluationRow?['provider'] as String?,
      );
      final evaluationJobRow = submissionId == null
          ? null
          : evaluationJobBySubmissionId[submissionId];
      final audioAssetRow = submissionId == null
          ? null
          : audioAssetBySubmissionId[submissionId];
      final latestFeedback =
          submissionFlowStatus == SubmissionFlowStatus.completed
          ? (submissionRow?['latest_feedback'] as String?)
          : null;
      final latestScore = submissionFlowStatus == SubmissionFlowStatus.completed
          ? _asDouble(
              submissionRow?['latest_score'] ?? evaluationRow?['overall_score'],
            )
          : null;
      final encouragement =
          submissionFlowStatus == SubmissionFlowStatus.completed
          ? (evaluationRow?['encouragement'] as String?)
          : null;
      final strengths = submissionFlowStatus == SubmissionFlowStatus.completed
          ? _asStringList(evaluationRow?['strengths'])
          : const <String>[];
      final improvementPoints =
          submissionFlowStatus == SubmissionFlowStatus.completed
          ? _asStringList(evaluationRow?['improvement_points'])
          : const <String>[];

      final taskReviewByItemId = _extractTaskReviews(evaluationRow);
      final tasks = (itemsByAssignmentId[assignmentId] ?? const [])
          .map(
            (item) => _mapTask(
              item,
              submissionFlowStatus,
              taskReviewByItemId[item['id'] as String? ?? ''],
            ),
          )
          .toList();
      final materialRow = materialById[row['material_id'] as String? ?? ''];
      final reviewCount =
          latestFeedback != null ||
              latestScore != null ||
              encouragement != null ||
              strengths.isNotEmpty ||
              improvementPoints.isNotEmpty
          ? 1
          : 0;

      return PortalActivity(
        id: assignmentId,
        title: (row['title'] as String?) ?? '未命名活动',
        className: classNameById[(row['class_id'] as String?) ?? ''] ?? '未命名班级',
        dateLabel: _buildDateLabel(dueAt),
        status: _mapActivityStatus(submissionFlowStatus, assignmentStatus),
        reviewCount: reviewCount,
        inspectCount: 0,
        urgeCount: 0,
        completionRate: _completionRateFor(submissionFlowStatus),
        tasks: tasks,
        submissionFlowStatus: submissionFlowStatus,
        submissionId: submissionId,
        submittedAt: DateTime.tryParse(
          (submissionRow?['submitted_at'] as String?) ?? '',
        ),
        latestScore: latestScore,
        latestFeedback: latestFeedback,
        encouragement: encouragement,
        strengths: strengths,
        improvementPoints: improvementPoints,
        submissionAudioName: _fileNameFromPath(
          audioAssetRow?['storage_path'] as String?,
        ),
        submissionAudioPath: audioAssetRow?['storage_path'] as String?,
        description: row['description'] as String?,
        materialTitle: materialRow?['title'] as String?,
        materialPdfPath: materialRow?['pdf_path'] as String?,
        materialPageCount: _asInt(materialRow?['page_count']),
        submissionStatusHint: _submissionStatusHint(
          submissionFlowStatus,
          evaluationJobRow?['last_error'] as String?,
        ),
        reviewSource: reviewSource,
      );
    }).toList();
  }

  @override
  Future<void> submitActivity(String activityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('当前还没有登录账号。');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await _client.from('submissions').upsert({
      'assignment_id': activityId,
      'student_id': userId,
      'status': 'queued',
      'submitted_at': now,
      'latest_score': null,
      'latest_feedback': null,
      'updated_at': now,
    }, onConflict: 'assignment_id,student_id');
  }

  @override
  Future<AiReviewDispatchResult> uploadAudioSubmission({
    required String activityId,
    required Uint8List fileBytes,
    required String fileName,
    required int sizeBytes,
    String? mimeType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('当前还没有登录账号。');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final submissionResponse = await _client
        .from('submissions')
        .upsert({
          'assignment_id': activityId,
          'student_id': userId,
          'status': 'uploaded',
          'submitted_at': now,
          'latest_score': null,
          'latest_feedback': null,
          'updated_at': now,
        }, onConflict: 'assignment_id,student_id')
        .select('id')
        .single();

    final submissionId = submissionResponse['id'] as String?;
    if (submissionId == null) {
      throw StateError('提交记录创建失败。');
    }

    final safeName = _sanitizeFileName(fileName);
    final storagePath =
        '$submissionId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final resolvedMimeType = mimeType ?? _inferMimeType(fileName);

    await _client.storage
        .from('submission-audio')
        .uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(contentType: resolvedMimeType, upsert: true),
        );

    await _client.from('submission_assets').insert({
      'submission_id': submissionId,
      'asset_type': 'audio',
      'storage_bucket': 'submission-audio',
      'storage_path': storagePath,
      'mime_type': resolvedMimeType,
      'size_bytes': sizeBytes,
    });

    await _client
        .from('submissions')
        .update({'status': 'queued', 'submitted_at': now, 'updated_at': now})
        .eq('id', submissionId);

    unawaited(_triggerImmediateReview(submissionId));

    return const AiReviewDispatchResult(
      status: AiReviewDispatchStatus.queued,
      message: '录音已经提交，AI 初评已开始处理。',
    );
  }

  PortalTask _mapTask(
    Map<String, dynamic> row,
    SubmissionFlowStatus submissionFlowStatus,
    PortalTaskReview? review,
  ) {
    final itemType = (row['item_type'] as String?) ?? 'sentence';

    return PortalTask(
      id: row['id'] as String,
      title:
          (row['title'] as String?) ??
          (row['prompt_text'] as String?) ??
          '未命名任务',
      kind: _mapTaskKind(itemType),
      reviewStatus: _mapTaskReviewStatus(submissionFlowStatus),
      previewAsset: _previewAsset(itemType),
      review: review,
      promptText: row['prompt_text'] as String?,
      ttsText: row['tts_text'] as String?,
      expectedText: row['expected_text'] as String?,
      startPage: _asInt(row['start_page']),
      endPage: _asInt(row['end_page']),
      referenceAudioPath: row['reference_audio_path'] as String?,
    );
  }

  TaskKind _mapTaskKind(String itemType) {
    switch (itemType) {
      case 'word':
        return TaskKind.phonics;
      case 'paragraph':
        return TaskKind.dubbing;
      case 'sentence':
      default:
        return TaskKind.recording;
    }
  }

  TaskReviewStatus _mapTaskReviewStatus(SubmissionFlowStatus submissionStatus) {
    switch (submissionStatus) {
      case SubmissionFlowStatus.completed:
        return TaskReviewStatus.checked;
      case SubmissionFlowStatus.queued:
      case SubmissionFlowStatus.processing:
        return TaskReviewStatus.pendingReview;
      case SubmissionFlowStatus.notStarted:
      case SubmissionFlowStatus.failed:
        return TaskReviewStatus.inProgress;
    }
  }

  ActivityStatus _mapActivityStatus(
    SubmissionFlowStatus submissionStatus,
    String assignmentStatus,
  ) {
    if (assignmentStatus == 'closed') {
      return ActivityStatus.completed;
    }

    switch (submissionStatus) {
      case SubmissionFlowStatus.completed:
        return ActivityStatus.completed;
      case SubmissionFlowStatus.queued:
      case SubmissionFlowStatus.processing:
        return ActivityStatus.reviewPending;
      case SubmissionFlowStatus.notStarted:
      case SubmissionFlowStatus.failed:
        return ActivityStatus.active;
    }
  }

  String _previewAsset(String itemType) {
    switch (itemType) {
      case 'word':
        return '自然拼读';
      case 'paragraph':
        return '视频配音';
      case 'sentence':
      default:
        return '录音';
    }
  }

  double _completionRateFor(SubmissionFlowStatus submissionStatus) {
    switch (submissionStatus) {
      case SubmissionFlowStatus.completed:
        return 1;
      case SubmissionFlowStatus.queued:
      case SubmissionFlowStatus.processing:
        return 1;
      case SubmissionFlowStatus.failed:
        return 0.65;
      case SubmissionFlowStatus.notStarted:
        return 0.32;
    }
  }

  String _buildDateLabel(DateTime? dueAt) {
    if (dueAt == null) {
      return '待设置截止时间';
    }
    final start = dueAt.subtract(const Duration(days: 6));
    return '${start.month}.${start.day} - ${dueAt.month}.${dueAt.day}';
  }

  SubmissionFlowStatus _mapSubmissionFlowStatus(String? status) {
    switch (status) {
      case 'uploaded':
      case 'queued':
        return SubmissionFlowStatus.queued;
      case 'processing':
        return SubmissionFlowStatus.processing;
      case 'completed':
        return SubmissionFlowStatus.completed;
      case 'failed':
        return SubmissionFlowStatus.failed;
      case 'draft':
      default:
        return SubmissionFlowStatus.notStarted;
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  String? _submissionStatusHint(
    SubmissionFlowStatus submissionStatus,
    String? jobError,
  ) {
    switch (submissionStatus) {
      case SubmissionFlowStatus.failed:
        return _friendlyStudentError(jobError);
      case SubmissionFlowStatus.processing:
        return '系统正在整理 transcript 和初评结果，老师也可以稍后补充人工点评。';
      case SubmissionFlowStatus.queued:
        return '老师已经收到这次练习，系统会先尝试生成初评，再由老师查看。';
      case SubmissionFlowStatus.completed:
      case SubmissionFlowStatus.notStarted:
        return null;
    }
  }

  String _friendlyStudentError(String? jobError) {
    final error = (jobError ?? '').toLowerCase();
    if (error.contains('invalid audio format') ||
        error.contains('audio transcription failed') ||
        error.contains('detail":"not found"') ||
        error.contains('detail\\\":\\\"not found\\\"')) {
      return 'AI 初评暂时不可用，这次录音已经提交给老师，并不是你读得不清楚。你可以稍后再试，或者直接等待老师手动查看。';
    }
    if (error.contains('transcription')) {
      return '系统这次没能完成自动转写，这次录音已经提交给老师。你可以稍后重试，或者直接等待老师手动查看。';
    }
    if (error.contains('503') ||
        error.contains('temporarily unavailable') ||
        error.contains('timeout')) {
      return '系统点评刚才有点忙，建议稍后重新提交，或者直接等待老师手动查看。';
    }
    if (error.contains('download')) {
      return '系统暂时没有取到这次音频附件，建议重新提交一次，老师也仍然可以手动查看。';
    }
    return '系统初评这次没有成功，但老师仍然可以手动查看。你可以重新录一段音频再提交。';
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  Map<String, PortalTaskReview> _extractTaskReviews(
    Map<String, dynamic>? evaluationRow,
  ) {
    if (evaluationRow == null) {
      return const {};
    }

    final provider = evaluationRow['provider'] as String?;
    final rawResult = _asMap(evaluationRow['raw_result']);
    final reviewSource = provider == 'teacher-review'
        ? PortalTaskReviewSource.aiRetainedAfterTeacherReview
        : PortalTaskReviewSource.ai;
    final sourceLabel = provider == 'teacher-review'
        ? 'AI 句子点评（老师已复核）'
        : 'AI 句子点评';
    final source = provider == 'teacher-review'
        ? _asMap(rawResult?['previousAiReview'])
        : rawResult;
    final taskReviews = source?['taskReviews'];
    if (taskReviews is! List) {
      return const {};
    }

    final result = <String, PortalTaskReview>{};
    for (final item in taskReviews) {
      final row = _asMap(item);
      final itemId = row?['itemId'] as String?;
      final score = _asDouble(row?['overallScore'] ?? row?['score']);
      final summaryFeedback = (row?['summaryFeedback'] as String?)?.trim();
      if (itemId == null || score == null || summaryFeedback == null) {
        continue;
      }

      result[itemId] = PortalTaskReview(
        score: score,
        summaryFeedback: summaryFeedback,
        encouragement: (row?['encouragement'] as String?)?.trim() ?? '',
        source: reviewSource,
        sourceLabel: sourceLabel,
        pronunciationScore: _asDouble(row?['pronunciationScore']),
        fluencyScore: _asDouble(row?['fluencyScore']),
        completenessScore: _asDouble(row?['completenessScore']),
        strengths: _asStringList(row?['strengths']),
        improvementPoints: _asStringList(row?['improvementPoints']),
      );
    }

    return result;
  }

  PortalActivityReviewSource _mapReviewSource(String? provider) {
    if (provider == null || provider.trim().isEmpty) {
      return PortalActivityReviewSource.none;
    }
    if (provider == 'teacher-review') {
      return PortalActivityReviewSource.teacherReviewed;
    }
    return PortalActivityReviewSource.aiOnly;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  String? _fileNameFromPath(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    final segments = path.split('/');
    return segments.isEmpty ? null : segments.last;
  }

  String _sanitizeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return sanitized.isEmpty ? 'audio.m4a' : sanitized;
  }

  String _inferMimeType(String fileName) {
    final normalized = fileName.toLowerCase();
    if (normalized.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (normalized.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (normalized.endsWith('.aac')) {
      return 'audio/aac';
    }
    if (normalized.endsWith('.mp4') || normalized.endsWith('.m4a')) {
      return 'audio/mp4';
    }
    return 'audio/mpeg';
  }
}

final portalRepositoryProvider = Provider<PortalRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.canUseSupabase) {
    return SupabasePortalRepository(Supabase.instance.client);
  }
  return const MockPortalRepository();
});
