import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'portal_models.dart';

abstract class PortalRepository {
  Future<List<PortalActivity>> fetchActivities();
}

class MockPortalRepository implements PortalRepository {
  const MockPortalRepository();

  @override
  Future<List<PortalActivity>> fetchActivities() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return mockPortalActivities;
  }
}

class SupabasePortalRepository implements PortalRepository {
  const SupabasePortalRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PortalActivity>> fetchActivities() async {
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
      final schoolId = membership['school_id'] as String?;
      final classId = membership['class_id'] as String?;
      final role = membership['role'] as String?;

      if (schoolId != null) {
        schoolIds.add(schoolId);
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
      final statusValue = (row['status'] as String?) ?? 'published';
      final dueAt = DateTime.tryParse((row['due_at'] as String?) ?? '');
      final tasks = (itemsByAssignmentId[assignmentId] ?? const [])
          .map((item) => _mapTask(item, statusValue))
          .toList();

      return PortalActivity(
        id: assignmentId,
        title: (row['title'] as String?) ?? '未命名活动',
        className: classNameById[(row['class_id'] as String?) ?? ''] ?? '未命名班级',
        dateLabel: _buildDateLabel(dueAt),
        status: _mapActivityStatus(statusValue),
        reviewCount: tasks.where((task) => task.reviewStatus == TaskReviewStatus.pendingReview).length,
        inspectCount: 0,
        urgeCount: 0,
        completionRate: _completionRateFor(statusValue),
        tasks: tasks,
      );
    }).toList();
  }

  PortalTask _mapTask(Map<String, dynamic> row, String assignmentStatus) {
    final itemType = (row['item_type'] as String?) ?? 'sentence';

    return PortalTask(
      id: row['id'] as String,
      title:
          (row['title'] as String?) ??
          (row['prompt_text'] as String?) ??
          '未命名任务',
      kind: _mapTaskKind(itemType),
      reviewStatus: _mapTaskReviewStatus(assignmentStatus),
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

  TaskReviewStatus _mapTaskReviewStatus(String assignmentStatus) {
    switch (assignmentStatus) {
      case 'closed':
        return TaskReviewStatus.checked;
      case 'draft':
        return TaskReviewStatus.inProgress;
      case 'published':
      default:
        return TaskReviewStatus.pendingReview;
    }
  }

  ActivityStatus _mapActivityStatus(String assignmentStatus) {
    switch (assignmentStatus) {
      case 'closed':
        return ActivityStatus.completed;
      case 'draft':
        return ActivityStatus.active;
      case 'published':
      default:
        return ActivityStatus.reviewPending;
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

  double _completionRateFor(String assignmentStatus) {
    switch (assignmentStatus) {
      case 'closed':
        return 1;
      case 'draft':
        return 0.35;
      case 'published':
      default:
        return 0.82;
    }
  }

  String _buildDateLabel(DateTime? dueAt) {
    if (dueAt == null) {
      return '待设置截止时间';
    }
    final start = dueAt.subtract(const Duration(days: 6));
    return '${start.month}.${start.day} - ${dueAt.month}.${dueAt.day}';
  }
}

final portalRepositoryProvider = Provider<PortalRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.canUseSupabase) {
    return SupabasePortalRepository(Supabase.instance.client);
  }
  return const MockPortalRepository();
});
