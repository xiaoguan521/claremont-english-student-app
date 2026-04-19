import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'portal_models.dart';

abstract class PortalRepository {
  Future<List<PortalActivity>> fetchActivities({String? schoolId});

  Future<void> submitActivity(String activityId);
}

class MockPortalRepository implements PortalRepository {
  const MockPortalRepository();

  @override
  Future<List<PortalActivity>> fetchActivities({String? schoolId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return mockPortalActivities;
  }

  @override
  Future<void> submitActivity(String activityId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}

class SupabasePortalRepository implements PortalRepository {
  const SupabasePortalRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PortalActivity>> fetchActivities({String? schoolId}) async {
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
        .select('id, class_id, title, due_at, status')
        .inFilter('class_id', classIds.toList())
        .neq('status', 'archived')
        .order('created_at', ascending: false);
    final assignmentRows = List<Map<String, dynamic>>.from(assignmentsResponse);

    if (assignmentRows.isEmpty) {
      return const [];
    }

    final assignmentIds = assignmentRows
        .map((row) => row['id'] as String?)
        .whereType<String>()
        .toList();

    final assignmentItemsResponse = await _client
        .from('assignment_items')
        .select('id, assignment_id, title, item_type, prompt_text, sort_order')
        .inFilter('assignment_id', assignmentIds)
        .order('sort_order', ascending: true);
    final itemRows = List<Map<String, dynamic>>.from(assignmentItemsResponse);

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

    final evaluationBySubmissionId = <String, Map<String, dynamic>>{};
    if (submissionIds.isNotEmpty) {
      final evaluationsResponse = await _client
          .from('evaluation_results')
          .select(
            'submission_id, overall_score, strengths, improvement_points, encouragement',
          )
          .inFilter('submission_id', submissionIds);

      for (final row in List<Map<String, dynamic>>.from(evaluationsResponse)) {
        final submissionId = row['submission_id'] as String?;
        if (submissionId != null) {
          evaluationBySubmissionId[submissionId] = row;
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

    return assignmentRows.map((row) {
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

      final tasks = (itemsByAssignmentId[assignmentId] ?? const [])
          .map((item) => _mapTask(item, submissionFlowStatus))
          .toList();
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

  PortalTask _mapTask(
    Map<String, dynamic> row,
    SubmissionFlowStatus submissionFlowStatus,
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

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }
}

final portalRepositoryProvider = Provider<PortalRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.canUseSupabase) {
    return SupabasePortalRepository(Supabase.instance.client);
  }
  return const MockPortalRepository();
});
