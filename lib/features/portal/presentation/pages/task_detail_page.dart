import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../school/presentation/providers/school_context_provider.dart';
import '../../data/portal_models.dart';
import '../../data/portal_repository.dart';
import '../providers/portal_providers.dart';
import '../widgets/tablet_shell.dart';
import 'reading_page.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({required this.activityId, super.key});

  final String activityId;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _recorder = AudioRecorder();
  final Map<String, String> _storedAudioCache = {};
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];

  bool _isSubmitting = false;
  bool _isRecording = false;
  String? _recordingPath;
  String? _loadingAudioKey;
  String? _playingAudioKey;
  String? _speakingTaskId;
  _PendingAudioFile? _selectedAudio;

  @override
  void initState() {
    super.initState();
    _bindAudioPlayer();
    _configureAudioPlayer();
    _configureTts();
  }

  Future<void> _configureAudioPlayer() async {
    await _audioPlayer.setVolume(1.0);
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void _bindAudioPlayer() {
    _playerSubscriptions.add(
      _audioPlayer.onPlayerComplete.listen((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _playingAudioKey = null;
          _loadingAudioKey = null;
        });
      }),
    );
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _speakingTaskId = null;
      });
    });
    _tts.setCancelHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _speakingTaskId = null;
      });
    });
    _tts.setErrorHandler((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _speakingTaskId = null;
      });
    });
  }

  @override
  void dispose() {
    for (final subscription in _playerSubscriptions) {
      subscription.cancel();
    }
    _audioPlayer.dispose();
    _tts.stop();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    if (_isRecording) {
      _showMessage('请先结束当前录音，再选择已有音频。');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'mp4', 'wav', 'aac'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    if (file.bytes == null) {
      _showMessage('这次没有拿到音频内容，请重新选择。');
      return;
    }

    setState(() {
      _selectedAudio = _PendingAudioFile(
        name: file.name,
        bytes: file.bytes!,
        sizeBytes: file.size,
        mimeType: _guessMimeType(file.extension),
        localPath: file.path,
      );
    });
  }

  Future<void> _clearSelectedAudio() async {
    final selectedAudio = _selectedAudio;
    if (selectedAudio == null) {
      return;
    }

    final audioKey = _pendingAudioKey(selectedAudio);
    if (_playingAudioKey == audioKey || _loadingAudioKey == audioKey) {
      await _audioPlayer.stop();
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _selectedAudio = null;
      if (_playingAudioKey == audioKey) {
        _playingAudioKey = null;
      }
      if (_loadingAudioKey == audioKey) {
        _loadingAudioKey = null;
      }
    });
    _showMessage('这段准备提交的音频已经移除。');
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }

    final hasPermission = await _ensureMicrophonePermission();
    if (!hasPermission) {
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/student-reading-${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
        path: path,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
        _recordingPath = path;
      });
      _showMessage('已经开始录音了，读完后点“结束录音并保存”。');
    } catch (_) {
      _showMessage('录音启动失败，请稍后重试。');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final stoppedPath = await _recorder.stop();
      final resolvedPath = stoppedPath ?? _recordingPath;

      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingPath = null;
        });
      }

      if (resolvedPath == null) {
        _showMessage('这次录音没有保存成功，请再试一次。');
        return;
      }

      final file = File(resolvedPath);
      if (!await file.exists()) {
        _showMessage('没有找到刚才录下来的音频文件。');
        return;
      }

      final bytes = await file.readAsBytes();
      final sizeBytes = await file.length();
      final fileName = resolvedPath.split(Platform.pathSeparator).last;

      if (!mounted) {
        return;
      }
      setState(() {
        _selectedAudio = _PendingAudioFile(
          name: fileName,
          bytes: bytes,
          sizeBytes: sizeBytes,
          mimeType: 'audio/wav',
          localPath: resolvedPath,
        );
      });
      _showMessage('录音已经保存好了，可以直接提交给老师。');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        _recordingPath = null;
      });
      _showMessage('结束录音时出了点问题，请重新试一次。');
    }
  }

  Future<void> _speakSample(PortalTask task) async {
    final text = _sampleTextFor(task);
    if (text == null) {
      _showMessage('这项任务还没有配置示范朗读内容。');
      return;
    }

    final schoolContext = ref.read(schoolContextProvider).valueOrNull;
    final schoolId = schoolContext?.schoolId;
    if (schoolId != null && schoolId.trim().isNotEmpty) {
      try {
        await _toggleAudioPlayback(
          audioKey: _generatedSampleAudioKey(task.id, schoolId, text),
          resolvePath: () => _resolveGeneratedSampleAudioPath(
            schoolId: schoolId,
            taskId: task.id,
            text: text,
          ),
          rethrowOnError: true,
        );
        return;
      } catch (_) {
        _showMessage('远程语音暂时没有生成成功，先用本地示范语音继续学习。');
      }
    }

    await _speakSampleLocally(task, text);
  }

  Future<void> _speakSampleLocally(PortalTask task, String text) async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _playingAudioKey = null;
        _loadingAudioKey = null;
      });
    }

    if (_speakingTaskId == task.id) {
      await _tts.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _speakingTaskId = null;
      });
      return;
    }

    await _tts.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _speakingTaskId = task.id;
    });

    final result = await _tts.speak(text);
    if (!mounted) {
      return;
    }
    if (result != 1) {
      setState(() {
        _speakingTaskId = null;
      });
      _showMessage('示范朗读没有播放成功，请检查媒体音量或系统语音服务。');
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    final currentStatus = await Permission.microphone.status;
    if (currentStatus.isGranted) {
      return true;
    }

    if (mounted) {
      final continueRequest = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('需要麦克风权限'),
            content: const Text('录音提交作业时需要使用麦克风。点“继续”后，系统会弹出权限请求。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('暂不'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('继续'),
              ),
            ],
          );
        },
      );

      if (continueRequest != true) {
        return false;
      }
    }

    final requestedStatus = await Permission.microphone.request();
    if (requestedStatus.isGranted) {
      final pluginPermission = await _recorder.hasPermission(request: false);
      if (!pluginPermission) {
        _showMessage('系统已授权，但录音器还没准备好，请重新点一次录音。');
      }
      return pluginPermission;
    }

    if (requestedStatus.isPermanentlyDenied || requestedStatus.isRestricted) {
      if (!mounted) {
        return false;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('麦克风权限未开启'),
            content: const Text('当前无法录音。请到系统设置里开启麦克风权限后，再回来提交作业。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('知道了'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await openAppSettings();
                },
                child: const Text('去设置'),
              ),
            ],
          );
        },
      );
      return false;
    }

    _showMessage('没有麦克风权限，暂时不能录音。');
    return false;
  }

  Future<String> _resolveGeneratedSampleAudioPath({
    required String schoolId,
    required String taskId,
    required String text,
  }) async {
    final cacheKey = _generatedSampleAudioKey(taskId, schoolId, text);
    final cachedPath = _storedAudioCache[cacheKey];
    if (cachedPath != null && await File(cachedPath).exists()) {
      return cachedPath;
    }

    final response = await Supabase.instance.client.functions.invoke(
      'generate-speech-sample',
      body: {'schoolId': schoolId, 'text': text},
    );

    if (response.status != 200) {
      final data = response.data;
      final message = data is Map<String, dynamic>
          ? (data['error'] as String?) ?? '语音生成失败'
          : '语音生成失败';
      throw Exception(message);
    }

    final data = response.data;
    if (data is! Map) {
      throw Exception('语音服务返回格式不正确');
    }

    final audioBase64 = data['audioBase64'] as String?;
    final mimeType = data['mimeType'] as String? ?? 'audio/mpeg';
    if (audioBase64 == null || audioBase64.isEmpty) {
      throw Exception('语音服务没有返回音频内容');
    }

    final bytes = base64Decode(audioBase64);
    final tempDir = await getTemporaryDirectory();
    final extension = _extensionForMimeType(mimeType);
    final targetPath =
        '${tempDir.path}/speech-sample-${DateTime.now().millisecondsSinceEpoch}.$extension';
    await File(targetPath).writeAsBytes(bytes, flush: true);
    _storedAudioCache[cacheKey] = targetPath;
    return targetPath;
  }

  Future<void> _toggleReferenceAudioPlayback(PortalTask task) async {
    final storagePath = task.referenceAudioPath;
    if (storagePath == null || storagePath.trim().isEmpty) {
      _showMessage('这项任务还没有参考音频。');
      return;
    }

    await _tts.stop();
    if (mounted && _speakingTaskId != null) {
      setState(() {
        _speakingTaskId = null;
      });
    }

    await _toggleAudioPlayback(
      audioKey: _referenceAudioKey(storagePath),
      resolvePath: () =>
          _resolveStorageAudioPath(storagePath, defaultBucket: 'materials'),
    );
  }

  Future<void> _openReadingPage(
    PortalActivity activity, {
    PortalTask? task,
  }) async {
    if ((activity.materialPdfPath ?? '').trim().isEmpty) {
      _showMessage('老师还没有上传教材 PDF。');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReadingPage(activity: activity, task: task),
      ),
    );
  }

  Future<void> _togglePendingAudioPlayback() async {
    final selectedAudio = _selectedAudio;
    if (selectedAudio == null) {
      _showMessage('先录一段音频或选择已有音频，再试听。');
      return;
    }

    await _toggleAudioPlayback(
      audioKey: _pendingAudioKey(selectedAudio),
      resolvePath: () => _resolvePendingAudioPath(selectedAudio),
    );
  }

  Future<void> _toggleStoredAudioPlayback(PortalActivity activity) async {
    final storagePath = activity.submissionAudioPath;
    if (storagePath == null || storagePath.trim().isEmpty) {
      _showMessage('当前还没有可回放的已提交音频。');
      return;
    }

    await _toggleAudioPlayback(
      audioKey: _storedAudioKey(storagePath),
      resolvePath: () => _resolveStorageAudioPath(
        storagePath,
        defaultBucket: 'submission-audio',
      ),
    );
  }

  Future<void> _toggleAudioPlayback({
    required String audioKey,
    required Future<String> Function() resolvePath,
    bool rethrowOnError = false,
  }) async {
    if (_playingAudioKey == audioKey) {
      await _audioPlayer.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _playingAudioKey = null;
        _loadingAudioKey = null;
      });
      return;
    }

    try {
      await _audioPlayer.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingAudioKey = audioKey;
        _playingAudioKey = null;
      });

      final path = await resolvePath();
      await _audioPlayer.play(DeviceFileSource(path));
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingAudioKey = null;
        _playingAudioKey = audioKey;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingAudioKey = null;
        if (_playingAudioKey == audioKey) {
          _playingAudioKey = null;
        }
      });
      if (rethrowOnError) {
        rethrow;
      }
      _showMessage('示范音频没有播放成功，请检查媒体音量后再试。');
    }
  }

  Future<String> _resolvePendingAudioPath(_PendingAudioFile audio) async {
    final localPath = audio.localPath;
    if (localPath != null && await File(localPath).exists()) {
      return localPath;
    }

    final tempDir = await getTemporaryDirectory();
    final extension = _fileExtension(audio.name);
    final path =
        '${tempDir.path}/pending-audio-${DateTime.now().millisecondsSinceEpoch}${extension == null ? '' : '.$extension'}';
    await File(path).writeAsBytes(audio.bytes, flush: true);
    return path;
  }

  Future<String> _resolveStorageAudioPath(
    String storageReference, {
    required String defaultBucket,
  }) async {
    final resolvedReference = _resolveStorageReference(
      storageReference,
      defaultBucket: defaultBucket,
    );
    final cacheKey = '${resolvedReference.bucketId}:${resolvedReference.path}';
    final cachedPath = _storedAudioCache[cacheKey];
    if (cachedPath != null && await File(cachedPath).exists()) {
      return cachedPath;
    }

    final bytes = await Supabase.instance.client.storage
        .from(resolvedReference.bucketId)
        .download(resolvedReference.path);
    final tempDir = await getTemporaryDirectory();
    final fileName = resolvedReference.path.split('/').last;
    final targetPath =
        '${tempDir.path}/${resolvedReference.bucketId.replaceAll(RegExp(r"[^a-zA-Z0-9_-]"), "_")}-$fileName';
    await File(targetPath).writeAsBytes(bytes, flush: true);
    _storedAudioCache[cacheKey] = targetPath;
    return targetPath;
  }

  Future<void> _handlePrimaryAction(PortalActivity activity) async {
    if (_isRecording) {
      _showMessage('请先结束录音并保存，再提交给老师。');
      return;
    }

    if (activity.submissionFlowStatus == SubmissionFlowStatus.queued ||
        activity.submissionFlowStatus == SubmissionFlowStatus.processing) {
      _showMessage('老师已经收到你的练习，正在处理中。');
      return;
    }

    if (activity.submissionFlowStatus == SubmissionFlowStatus.completed) {
      _showMessage('老师点评就在下方，往下滑就能查看完整反馈。');
      return;
    }

    final selectedAudio = _selectedAudio;
    if (selectedAudio == null) {
      _showMessage('先录一段音频或选择已有音频，再提交给老师。');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final reviewResult = await ref
          .read(portalRepositoryProvider)
          .uploadAudioSubmission(
            activityId: widget.activityId,
            fileBytes: selectedAudio.bytes,
            fileName: selectedAudio.name,
            sizeBytes: selectedAudio.sizeBytes,
            mimeType: selectedAudio.mimeType,
          );
      ref.invalidate(portalActivitiesProvider);
      ref.invalidate(portalSummaryProvider);
      ref.invalidate(portalActivityByIdProvider(widget.activityId));
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedAudio = null;
      });
      _showMessage(reviewResult.message ?? '已经提交给老师了，AI 初评和老师点评会在稍后同步回来。');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('提交失败，请稍后再试。');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(
      portalActivityByIdProvider(widget.activityId),
    );
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();

    if (activityAsync.isLoading) {
      return TabletShell(
        activeSection: TabletSection.teaching,
        brandName: schoolContext.displayName,
        brandSubtitle: '学校学习入口',
        title: '任务详情',
        subtitle: '正在加载今天的学习任务',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (activityAsync.hasError) {
      return TabletShell(
        activeSection: TabletSection.teaching,
        brandName: schoolContext.displayName,
        brandSubtitle: '学校学习入口',
        title: '任务详情',
        subtitle: '加载失败',
        child: Center(
          child: Text(
            '任务加载失败，请稍后重试。',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    final activity = activityAsync.valueOrNull;
    if (activity == null) {
      return TabletShell(
        activeSection: TabletSection.teaching,
        brandName: schoolContext.displayName,
        brandSubtitle: '学校学习入口',
        title: '任务详情',
        subtitle: '内容不存在',
        child: Center(
          child: Text(
            '没有找到这份作业。',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    final completedTasks = activity.tasks
        .where((task) => task.reviewStatus == TaskReviewStatus.checked)
        .length;
    final selectedAudioKey = _selectedAudio == null
        ? null
        : _pendingAudioKey(_selectedAudio!);
    final storedAudioKey = (activity.submissionAudioPath ?? '').trim().isEmpty
        ? null
        : _storedAudioKey(activity.submissionAudioPath!);

    return TabletShell(
      activeSection: TabletSection.teaching,
      brandName: schoolContext.displayName,
      brandSubtitle: '学校学习入口',
      title: activity.title,
      subtitle: '${activity.className} · ${activity.dateLabel}',
      actions: [
        _HeaderAction(
          icon: Icons.arrow_back_rounded,
          label: '返回作业',
          onTap: () => context.go('/activities'),
        ),
      ],
      child: ListView.separated(
        itemCount:
            activity.tasks.length +
            (activity.submissionFlowStatus == SubmissionFlowStatus.completed
                ? 2
                : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _OverviewCard(
              activity: activity,
              completedTasks: completedTasks,
              onOpenMaterial: () => _openReadingPage(activity),
            );
          }

          if (activity.submissionFlowStatus == SubmissionFlowStatus.completed &&
              index == activity.tasks.length + 1) {
            return _FeedbackPanel(
              activity: activity,
              isStoredAudioPlaying: storedAudioKey == _playingAudioKey,
              isStoredAudioLoading: storedAudioKey == _loadingAudioKey,
              onPlayStoredAudio: storedAudioKey == null
                  ? null
                  : () => _toggleStoredAudioPlayback(activity),
            );
          }

          final task = activity.tasks[index - 1];
          final referenceAudioKey = task.hasReferenceAudio
              ? _referenceAudioKey(task.referenceAudioPath!)
              : null;
          return _TaskCard(
            index: index - 1,
            task: task,
            submissionFlowStatus: activity.submissionFlowStatus,
            submissionStatusHint: activity.submissionStatusHint,
            selectedAudioLabel: _selectedAudio?.name,
            existingAudioLabel: activity.submissionAudioName,
            isSubmitting: _isSubmitting,
            isRecording: _isRecording,
            isSpeaking: _speakingTaskId == task.id,
            isSamplePlaying: task.hasReferenceAudio
                ? referenceAudioKey == _playingAudioKey
                : _speakingTaskId == task.id,
            isSampleLoading: task.hasReferenceAudio
                ? referenceAudioKey == _loadingAudioKey
                : false,
            isSelectedAudioPlaying: selectedAudioKey == _playingAudioKey,
            isSelectedAudioLoading: selectedAudioKey == _loadingAudioKey,
            isStoredAudioPlaying: storedAudioKey == _playingAudioKey,
            isStoredAudioLoading: storedAudioKey == _loadingAudioKey,
            onAction: () => _handleTaskAction(activity, task),
            onOpenReading: activity.materialPdfPath == null
                ? null
                : () => _openReadingPage(activity, task: task),
            onSpeakSample: task.hasReferenceAudio
                ? () => _toggleReferenceAudioPlayback(task)
                : _sampleTextFor(task) == null
                ? null
                : () => _speakSample(task),
            onPickAudio: _isRecording ? null : _pickAudioFile,
            onRecordAudio: _toggleRecording,
            onClearSelectedAudio: _selectedAudio == null
                ? null
                : _clearSelectedAudio,
            onPlaySelectedAudio: _selectedAudio == null
                ? null
                : _togglePendingAudioPlayback,
            onPlayStoredAudio: storedAudioKey == null
                ? null
                : () => _toggleStoredAudioPlayback(activity),
            onPrimaryAction: () => _handlePrimaryAction(activity),
          );
        },
      ),
    );
  }

  void _handleTaskAction(PortalActivity activity, PortalTask task) {
    switch (task.reviewStatus) {
      case TaskReviewStatus.checked:
        _showMessage('老师点评已经生成了，往上滑一点就能看到。');
        return;
      case TaskReviewStatus.pendingReview:
        _showMessage('这项练习已经提交，老师正在查看。');
        return;
      case TaskReviewStatus.inProgress:
        _handlePrimaryAction(activity);
        return;
    }
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.activity,
    required this.completedTasks,
    required this.onOpenMaterial,
  });

  final PortalActivity activity;
  final int completedTasks;
  final VoidCallback onOpenMaterial;

  @override
  Widget build(BuildContext context) {
    final submittedLabel = activity.submittedAt == null
        ? '还没有提交'
        : '提交于 ${_formatDateTime(activity.submittedAt!)}';
    final scoreLabel = activity.latestScore == null
        ? '等待老师评分'
        : '老师评分 ${activity.latestScore!.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 720;
          final cover = Container(
            width: isPhone ? double.infinity : 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3ECF8E), Color(0xFFFFB347)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              size: 56,
              color: Colors.white,
            ),
          );
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.className,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '今天先按顺序完成下面 ${activity.tasks.length} 个学习任务。',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w900,
                ),
              ),
              if ((activity.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  activity.description!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4DF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '完成方法',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF9A5A14),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. 先打开教材看看今天读什么\n2. 听示范后录音或选择音频\n3. 提交后等待系统和老师反馈',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7C5A2F),
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _OverviewChip(
                    icon: Icons.check_circle_rounded,
                    label: '已完成 $completedTasks 项',
                  ),
                  _OverviewChip(
                    icon: Icons.schedule_rounded,
                    label: submittedLabel,
                  ),
                  _OverviewChip(
                    icon: Icons.mark_chat_read_rounded,
                    label: scoreLabel,
                  ),
                  if ((activity.materialTitle ?? '').trim().isNotEmpty)
                    _OverviewChip(
                      icon: Icons.picture_as_pdf_rounded,
                      label: activity.materialTitle!,
                    ),
                ],
              ),
            ],
          );
          final actions = Column(
            crossAxisAlignment: isPhone
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.end,
            children: [
              FilledButton.tonalIcon(
                onPressed: onOpenMaterial,
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('打开教材'),
              ),
            ],
          );

          if (isPhone) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover,
                const SizedBox(height: 18),
                summary,
                const SizedBox(height: 18),
                actions,
              ],
            );
          }

          return Row(
            children: [
              cover,
              const SizedBox(width: 20),
              Expanded(child: summary),
              const SizedBox(width: 20),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _SubmissionPanel extends StatelessWidget {
  const _SubmissionPanel({
    required this.activity,
    required this.isSubmitting,
    required this.isRecording,
    required this.selectedAudio,
    required this.isSelectedAudioPlaying,
    required this.isSelectedAudioLoading,
    required this.isStoredAudioPlaying,
    required this.isStoredAudioLoading,
    required this.onPickAudio,
    required this.onRecordAudio,
    this.onPlaySelectedAudio,
    this.onPlayStoredAudio,
    required this.onPrimaryAction,
  });

  final PortalActivity activity;
  final bool isSubmitting;
  final bool isRecording;
  final _PendingAudioFile? selectedAudio;
  final bool isSelectedAudioPlaying;
  final bool isSelectedAudioLoading;
  final bool isStoredAudioPlaying;
  final bool isStoredAudioLoading;
  final VoidCallback onPickAudio;
  final VoidCallback onRecordAudio;
  final VoidCallback? onPlaySelectedAudio;
  final VoidCallback? onPlayStoredAudio;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    switch (activity.submissionFlowStatus) {
      case SubmissionFlowStatus.notStarted:
        return _MessagePanel(
          title: isRecording ? '正在录音中' : '完成朗读后记得提交',
          subtitle: isRecording
              ? '读完后点击“结束录音并保存”，然后再把音频提交给老师。'
              : '可以先打开教材、听示范，再用原生录音完成本次练习。',
          badgeLabel: isRecording ? '录音进行中' : '还没有提交',
          badgeColor: isRecording
              ? const Color(0xFFDC2626)
              : const Color(0xFF2563EB),
          selectedAudioLabel: selectedAudio?.name,
          existingAudioLabel: activity.submissionAudioName,
          onPlaySelectedAudio: onPlaySelectedAudio,
          onPlayStoredAudio: onPlayStoredAudio,
          isSelectedAudioPlaying: isSelectedAudioPlaying,
          isSelectedAudioLoading: isSelectedAudioLoading,
          isStoredAudioPlaying: isStoredAudioPlaying,
          isStoredAudioLoading: isStoredAudioLoading,
          onPickAudio: isRecording ? null : onPickAudio,
          onRecordAudio: onRecordAudio,
          helperNote: '第一次录音会请求麦克风权限；如果没有弹出，请检查系统权限设置。',
          recordActionLabel: isRecording ? '结束录音并保存' : '开始录音',
          actionLabel: isSubmitting ? '提交中' : '提交本次练习',
          actionIcon: isSubmitting
              ? null
              : const Icon(Icons.cloud_upload_rounded),
          onAction: isSubmitting || isRecording ? null : onPrimaryAction,
        );
      case SubmissionFlowStatus.queued:
        return _MessagePanel(
          title: '老师已经收到这次练习',
          subtitle:
              activity.submissionStatusHint ??
              (activity.submittedAt == null
                  ? '现在进入等待点评状态，老师会尽快给你反馈。'
                  : '你已在 ${_formatDateTime(activity.submittedAt!)} 提交，老师会尽快给你反馈。'),
          badgeLabel: '等待老师点评',
          badgeColor: const Color(0xFFF97316),
          existingAudioLabel: activity.submissionAudioName,
          onPlayStoredAudio: onPlayStoredAudio,
          isStoredAudioPlaying: isStoredAudioPlaying,
          isStoredAudioLoading: isStoredAudioLoading,
        );
      case SubmissionFlowStatus.processing:
        return _MessagePanel(
          title: '系统正在整理评分结果',
          subtitle:
              activity.submissionStatusHint ?? '这份练习已经进入处理流程，稍后就能看到分数和鼓励语。',
          badgeLabel: '评分处理中',
          badgeColor: const Color(0xFFFF8F4D),
          existingAudioLabel: activity.submissionAudioName,
          onPlayStoredAudio: onPlayStoredAudio,
          isStoredAudioPlaying: isStoredAudioPlaying,
          isStoredAudioLoading: isStoredAudioLoading,
        );
      case SubmissionFlowStatus.failed:
        return _MessagePanel(
          title: isRecording ? '正在重新录音' : '这次提交没有成功',
          subtitle: isRecording
              ? '读完后点击“结束录音并保存”，再重新提交给老师。'
              : (activity.submissionStatusHint ?? '你可以重新录一段音频，或者换一个文件再提交。'),
          badgeLabel: isRecording ? '录音进行中' : '需要重新提交',
          badgeColor: isRecording
              ? const Color(0xFFDC2626)
              : const Color(0xFFDC2626),
          selectedAudioLabel: selectedAudio?.name,
          existingAudioLabel: activity.submissionAudioName,
          onPlaySelectedAudio: onPlaySelectedAudio,
          onPlayStoredAudio: onPlayStoredAudio,
          isSelectedAudioPlaying: isSelectedAudioPlaying,
          isSelectedAudioLoading: isSelectedAudioLoading,
          isStoredAudioPlaying: isStoredAudioPlaying,
          isStoredAudioLoading: isStoredAudioLoading,
          onPickAudio: isRecording ? null : onPickAudio,
          onRecordAudio: onRecordAudio,
          helperNote: '如果录音没有权限或音频没有保存成功，可以重新授权后再试一次。',
          recordActionLabel: isRecording ? '结束录音并保存' : '重新录音',
          actionLabel: isSubmitting ? '重新提交中' : '重新提交',
          actionIcon: isSubmitting ? null : const Icon(Icons.refresh_rounded),
          onAction: isSubmitting || isRecording ? null : onPrimaryAction,
        );
      case SubmissionFlowStatus.completed:
        return _FeedbackPanel(
          activity: activity,
          isStoredAudioPlaying: isStoredAudioPlaying,
          isStoredAudioLoading: isStoredAudioLoading,
          onPlayStoredAudio: onPlayStoredAudio,
        );
    }
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
    this.onPlaySelectedAudio,
    this.onPlayStoredAudio,
    this.onClearSelectedAudio,
    this.isSelectedAudioPlaying = false,
    this.isSelectedAudioLoading = false,
    this.isStoredAudioPlaying = false,
    this.isStoredAudioLoading = false,
    this.selectedAudioLabel,
    this.existingAudioLabel,
    this.onPickAudio,
    this.onRecordAudio,
    this.helperNote,
    this.recordActionLabel,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;
  final VoidCallback? onPlaySelectedAudio;
  final VoidCallback? onPlayStoredAudio;
  final VoidCallback? onClearSelectedAudio;
  final bool isSelectedAudioPlaying;
  final bool isSelectedAudioLoading;
  final bool isStoredAudioPlaying;
  final bool isStoredAudioLoading;
  final String? selectedAudioLabel;
  final String? existingAudioLabel;
  final VoidCallback? onPickAudio;
  final VoidCallback? onRecordAudio;
  final String? helperNote;
  final String? recordActionLabel;
  final String? actionLabel;
  final Widget? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 720;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  badgeLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (selectedAudioLabel != null) ...[
                const SizedBox(height: 14),
                _AudioInfoCard(
                  title: '准备提交的音频',
                  fileName: selectedAudioLabel!,
                  onAction: onPlaySelectedAudio,
                  onDelete: onClearSelectedAudio,
                  isPlaying: isSelectedAudioPlaying,
                  isLoading: isSelectedAudioLoading,
                ),
              ],
              if (existingAudioLabel != null) ...[
                const SizedBox(height: 14),
                _AudioInfoCard(
                  title: '已上传的音频',
                  fileName: existingAudioLabel!,
                  onAction: onPlayStoredAudio,
                  isPlaying: isStoredAudioPlaying,
                  isLoading: isStoredAudioLoading,
                ),
              ],
              if ((helperNote ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    helperNote!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7C5A2F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          );
          final actions = Column(
            crossAxisAlignment: isPhone
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.end,
            children: [
              if (onRecordAudio != null)
                FilledButton.tonalIcon(
                  onPressed: onRecordAudio,
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(recordActionLabel ?? '开始录音'),
                ),
              if (onPickAudio != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onPickAudio,
                  icon: const Icon(Icons.library_music_rounded),
                  label: Text(selectedAudioLabel == null ? '选择音频' : '重新选择'),
                ),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: actionIcon ?? const SizedBox.shrink(),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          );

          if (isPhone) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 18), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 18),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _AudioInfoCard extends StatelessWidget {
  const _AudioInfoCard({
    required this.title,
    required this.fileName,
    this.onAction,
    this.onDelete,
    this.isPlaying = false,
    this.isLoading = false,
  });

  final String title;
  final String fileName;
  final VoidCallback? onAction;
  final VoidCallback? onDelete;
  final bool isPlaying;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 480;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );
          final action = onAction == null
              ? null
              : OutlinedButton.icon(
                  onPressed: onAction,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isPlaying
                              ? Icons.stop_circle_rounded
                              : Icons.play_circle_outline_rounded,
                        ),
                  label: Text(isLoading ? '加载中' : (isPlaying ? '停止' : '播放')),
                );
          final deleteAction = onDelete == null
              ? null
              : OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('删除'),
                );

          if (isPhone) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.audio_file_rounded, color: Color(0xFF2FA77D)),
                const SizedBox(height: 10),
                details,
                if (action != null || deleteAction != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (action != null) action,
                      if (deleteAction != null) deleteAction,
                    ],
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              const Icon(Icons.audio_file_rounded, color: Color(0xFF2FA77D)),
              const SizedBox(width: 10),
              Expanded(child: details),
              if (deleteAction != null) ...[
                const SizedBox(width: 14),
                deleteAction,
              ],
              if (action != null) ...[const SizedBox(width: 14), action],
            ],
          );
        },
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.activity,
    this.onPlayStoredAudio,
    this.isStoredAudioPlaying = false,
    this.isStoredAudioLoading = false,
  });

  final PortalActivity activity;
  final VoidCallback? onPlayStoredAudio;
  final bool isStoredAudioPlaying;
  final bool isStoredAudioLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '老师点评已完成',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF16A34A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (activity.latestScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '老师评分 ${activity.latestScore!.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF2FA77D),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            activity.latestFeedback ?? '老师已经完成点评，你这次的练习表现不错。',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          if (activity.encouragement != null) ...[
            const SizedBox(height: 12),
            Text(
              activity.encouragement!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if ((activity.submissionAudioName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            _AudioInfoCard(
              title: '本次提交的音频',
              fileName: activity.submissionAudioName!,
              onAction: onPlayStoredAudio,
              isPlaying: isStoredAudioPlaying,
              isLoading: isStoredAudioLoading,
            ),
          ],
          if (activity.strengths.isNotEmpty ||
              activity.improvementPoints.isNotEmpty) ...[
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final isPhone = constraints.maxWidth < 720;
                if (isPhone) {
                  return Column(
                    children: [
                      _FeedbackListCard(
                        title: '这次做得好的地方',
                        items: activity.strengths.isEmpty
                            ? const ['老师觉得你的整体状态不错。']
                            : activity.strengths,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 16),
                      _FeedbackListCard(
                        title: '下次可以继续加强',
                        items: activity.improvementPoints.isEmpty
                            ? const ['继续保持稳定的语速和句尾停顿。']
                            : activity.improvementPoints,
                        color: const Color(0xFFF97316),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FeedbackListCard(
                        title: '这次做得好的地方',
                        items: activity.strengths.isEmpty
                            ? const ['老师觉得你的整体状态不错。']
                            : activity.strengths,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FeedbackListCard(
                        title: '下次可以继续加强',
                        items: activity.improvementPoints.isEmpty
                            ? const ['继续保持稳定的语速和句尾停顿。']
                            : activity.improvementPoints,
                        color: const Color(0xFFF97316),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackListCard extends StatelessWidget {
  const _FeedbackListCard({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2FA77D)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.index,
    required this.task,
    required this.submissionFlowStatus,
    required this.submissionStatusHint,
    required this.selectedAudioLabel,
    required this.existingAudioLabel,
    required this.isSubmitting,
    required this.isRecording,
    required this.isSpeaking,
    required this.isSamplePlaying,
    required this.isSampleLoading,
    required this.isSelectedAudioPlaying,
    required this.isSelectedAudioLoading,
    required this.isStoredAudioPlaying,
    required this.isStoredAudioLoading,
    required this.onAction,
    this.onOpenReading,
    this.onSpeakSample,
    this.onPickAudio,
    this.onRecordAudio,
    this.onPlaySelectedAudio,
    this.onPlayStoredAudio,
    this.onClearSelectedAudio,
    required this.onPrimaryAction,
  });

  final int index;
  final PortalTask task;
  final SubmissionFlowStatus submissionFlowStatus;
  final String? submissionStatusHint;
  final String? selectedAudioLabel;
  final String? existingAudioLabel;
  final bool isSubmitting;
  final bool isRecording;
  final bool isSpeaking;
  final bool isSamplePlaying;
  final bool isSampleLoading;
  final bool isSelectedAudioPlaying;
  final bool isSelectedAudioLoading;
  final bool isStoredAudioPlaying;
  final bool isStoredAudioLoading;
  final VoidCallback onAction;
  final VoidCallback? onOpenReading;
  final VoidCallback? onSpeakSample;
  final VoidCallback? onPickAudio;
  final VoidCallback? onRecordAudio;
  final VoidCallback? onPlaySelectedAudio;
  final VoidCallback? onPlayStoredAudio;
  final VoidCallback? onClearSelectedAudio;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(task.reviewStatus);
    final statusColor = _statusColor(task.reviewStatus);
    final actionLabel = _actionLabel(task.reviewStatus);
    final sampleText = _sampleTextFor(task);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 720;
          final preview = Container(
            width: isPhone ? double.infinity : 92,
            height: 74,
            decoration: BoxDecoration(
              gradient: _previewGradient(task.kind),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(_previewIcon(task.kind), color: Colors.white, size: 36),
          );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '学习方式：${task.previewAsset}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((task.promptText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  task.promptText!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (sampleText != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    sampleText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (task.hasPageRange)
                    _TaskInfoChip(
                      icon: Icons.menu_book_rounded,
                      label: _pageRangeLabel(task),
                    ),
                  if (sampleText != null)
                    _TaskInfoChip(
                      icon: isSamplePlaying
                          ? Icons.pause_circle_filled_rounded
                          : task.hasReferenceAudio
                          ? Icons.audiotrack_rounded
                          : Icons.volume_up_rounded,
                      label: task.hasReferenceAudio
                          ? (isSamplePlaying ? '示范音频播放中' : '可播放示范音频')
                          : (isSpeaking ? '示范朗读播放中' : '可播放示范朗读'),
                    ),
                ],
              ),
              if (task.reviewStatus != TaskReviewStatus.checked) ...[
                const SizedBox(height: 16),
                _InlineSubmissionSection(
                  submissionFlowStatus: submissionFlowStatus,
                  submissionStatusHint: submissionStatusHint,
                  selectedAudioLabel: selectedAudioLabel,
                  existingAudioLabel: existingAudioLabel,
                  isSubmitting: isSubmitting,
                  isRecording: isRecording,
                  isSelectedAudioPlaying: isSelectedAudioPlaying,
                  isSelectedAudioLoading: isSelectedAudioLoading,
                  isStoredAudioPlaying: isStoredAudioPlaying,
                  isStoredAudioLoading: isStoredAudioLoading,
                  onPickAudio: onPickAudio,
                  onRecordAudio: onRecordAudio,
                  onPlaySelectedAudio: onPlaySelectedAudio,
                  onPlayStoredAudio: onPlayStoredAudio,
                  onPrimaryAction: onPrimaryAction,
                ),
              ],
            ],
          );

          final header = isPhone
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$index',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color(0xFFFF8F4D),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: preview),
                      ],
                    ),
                    const SizedBox(height: 16),
                    details,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$index',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFFF8F4D),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    preview,
                    const SizedBox(width: 18),
                    Expanded(child: details),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (onOpenReading != null)
                    OutlinedButton.icon(
                      onPressed: onOpenReading,
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('打开教材'),
                    ),
                  if (onSpeakSample != null)
                    OutlinedButton.icon(
                      onPressed: onSpeakSample,
                      icon: Icon(
                        isSamplePlaying
                            ? Icons.stop_circle_rounded
                            : task.hasReferenceAudio
                            ? Icons.play_circle_outline_rounded
                            : Icons.record_voice_over_rounded,
                      ),
                      label: Text(
                        isSampleLoading
                            ? '加载中'
                            : isSamplePlaying
                            ? '停止示范'
                            : task.hasReferenceAudio
                            ? '听音频'
                            : '听示范',
                      ),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: onAction,
                    icon: Icon(_actionIcon(task.reviewStatus)),
                    label: Text(actionLabel),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _statusLabel(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return '这项任务已经有点评';
      case TaskReviewStatus.pendingReview:
        return '已经提交，老师正在查看';
      case TaskReviewStatus.inProgress:
        return '完成后记得提交给老师';
    }
  }

  Color _statusColor(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return const Color(0xFF16A34A);
      case TaskReviewStatus.pendingReview:
        return const Color(0xFFF97316);
      case TaskReviewStatus.inProgress:
        return const Color(0xFF2563EB);
    }
  }

  String _actionLabel(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return '查看点评';
      case TaskReviewStatus.pendingReview:
        return '等待点评';
      case TaskReviewStatus.inProgress:
        return '提交练习';
    }
  }

  IconData _actionIcon(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return Icons.rate_review_outlined;
      case TaskReviewStatus.pendingReview:
        return Icons.schedule_rounded;
      case TaskReviewStatus.inProgress:
        return Icons.cloud_upload_rounded;
    }
  }

  LinearGradient _previewGradient(TaskKind kind) {
    switch (kind) {
      case TaskKind.dubbing:
        return const LinearGradient(
          colors: [Color(0xFFFF7F50), Color(0xFFFFB347)],
        );
      case TaskKind.recording:
        return const LinearGradient(
          colors: [Color(0xFFFF7A7A), Color(0xFFFFB25B)],
        );
      case TaskKind.phonics:
        return const LinearGradient(
          colors: [Color(0xFF3ECF8E), Color(0xFF6FD2D2)],
        );
    }
  }

  IconData _previewIcon(TaskKind kind) {
    switch (kind) {
      case TaskKind.dubbing:
        return Icons.mic_external_on_rounded;
      case TaskKind.recording:
        return Icons.graphic_eq_rounded;
      case TaskKind.phonics:
        return Icons.spellcheck_rounded;
    }
  }
}

class _InlineSubmissionSection extends StatelessWidget {
  const _InlineSubmissionSection({
    required this.submissionFlowStatus,
    required this.submissionStatusHint,
    required this.selectedAudioLabel,
    required this.existingAudioLabel,
    required this.isSubmitting,
    required this.isRecording,
    required this.isSelectedAudioPlaying,
    required this.isSelectedAudioLoading,
    required this.isStoredAudioPlaying,
    required this.isStoredAudioLoading,
    this.onPickAudio,
    this.onRecordAudio,
    this.onPlaySelectedAudio,
    this.onPlayStoredAudio,
    required this.onPrimaryAction,
  });

  final SubmissionFlowStatus submissionFlowStatus;
  final String? submissionStatusHint;
  final String? selectedAudioLabel;
  final String? existingAudioLabel;
  final bool isSubmitting;
  final bool isRecording;
  final bool isSelectedAudioPlaying;
  final bool isSelectedAudioLoading;
  final bool isStoredAudioPlaying;
  final bool isStoredAudioLoading;
  final VoidCallback? onPickAudio;
  final VoidCallback? onRecordAudio;
  final VoidCallback? onPlaySelectedAudio;
  final VoidCallback? onPlayStoredAudio;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (submissionFlowStatus) {
      SubmissionFlowStatus.notStarted => isRecording ? '录音进行中' : '还没有提交',
      SubmissionFlowStatus.queued => '等待老师点评',
      SubmissionFlowStatus.processing => '评分处理中',
      SubmissionFlowStatus.failed => isRecording ? '录音进行中' : '需要重新提交',
      SubmissionFlowStatus.completed => '老师点评已完成',
    };
    final statusColor = switch (submissionFlowStatus) {
      SubmissionFlowStatus.notStarted => const Color(0xFF2563EB),
      SubmissionFlowStatus.queued => const Color(0xFFF97316),
      SubmissionFlowStatus.processing => const Color(0xFFFF8F4D),
      SubmissionFlowStatus.failed => const Color(0xFFDC2626),
      SubmissionFlowStatus.completed => const Color(0xFF16A34A),
    };
    final subtitle = switch (submissionFlowStatus) {
      SubmissionFlowStatus.notStarted =>
        isRecording ? '读完后点击“结束录音并保存”，再提交给老师。' : '先听示范，再录音或选择音频，然后提交给老师。',
      SubmissionFlowStatus.queued => submissionStatusHint ?? '已经提交成功，等待老师查看。',
      SubmissionFlowStatus.processing =>
        submissionStatusHint ?? '系统正在生成 AI 初评，请稍后刷新查看。',
      SubmissionFlowStatus.failed =>
        submissionStatusHint ?? '这次没有完成自动处理，你可以重新提交一次。',
      SubmissionFlowStatus.completed => '这份练习已经完成，往下可以查看老师反馈。',
    };
    final canSubmit =
        submissionFlowStatus == SubmissionFlowStatus.notStarted ||
        submissionFlowStatus == SubmissionFlowStatus.failed;
    final actionLabel = switch (submissionFlowStatus) {
      SubmissionFlowStatus.notStarted => isSubmitting ? '提交中' : '提交练习',
      SubmissionFlowStatus.failed => isSubmitting ? '重新提交中' : '重新提交',
      SubmissionFlowStatus.queued => '等待点评',
      SubmissionFlowStatus.processing => '处理中',
      SubmissionFlowStatus.completed => '已完成',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (selectedAudioLabel != null) ...[
            const SizedBox(height: 12),
            _AudioInfoCard(
              title: '准备提交的音频',
              fileName: selectedAudioLabel!,
              onAction: onPlaySelectedAudio,
              onDelete: onClearSelectedAudio,
              isPlaying: isSelectedAudioPlaying,
              isLoading: isSelectedAudioLoading,
            ),
          ],
          if (existingAudioLabel != null &&
              submissionFlowStatus != SubmissionFlowStatus.notStarted) ...[
            const SizedBox(height: 12),
            _AudioInfoCard(
              title: '已上传的音频',
              fileName: existingAudioLabel!,
              onAction: onPlayStoredAudio,
              isPlaying: isStoredAudioPlaying,
              isLoading: isStoredAudioLoading,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (onRecordAudio != null)
                FilledButton.tonalIcon(
                  onPressed: onRecordAudio,
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(isRecording ? '结束录音并保存' : '开始录音'),
                ),
              if (onPickAudio != null)
                OutlinedButton.icon(
                  onPressed: isRecording ? null : onPickAudio,
                  icon: const Icon(Icons.library_music_rounded),
                  label: Text(selectedAudioLabel == null ? '选择音频' : '重新选择'),
                ),
              FilledButton.icon(
                onPressed: canSubmit && !isSubmitting && !isRecording
                    ? onPrimaryAction
                    : null,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        submissionFlowStatus == SubmissionFlowStatus.failed
                            ? Icons.refresh_rounded
                            : Icons.cloud_upload_rounded,
                      ),
                label: Text(actionLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskInfoChip extends StatelessWidget {
  const _TaskInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2FA77D)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _canSubmit(SubmissionFlowStatus status) {
  switch (status) {
    case SubmissionFlowStatus.notStarted:
    case SubmissionFlowStatus.failed:
      return true;
    case SubmissionFlowStatus.queued:
    case SubmissionFlowStatus.processing:
    case SubmissionFlowStatus.completed:
      return false;
  }
}

String _primaryActionLabel(SubmissionFlowStatus status) {
  switch (status) {
    case SubmissionFlowStatus.notStarted:
      return '提交本次练习';
    case SubmissionFlowStatus.failed:
      return '重新提交';
    case SubmissionFlowStatus.queued:
      return '等待老师点评';
    case SubmissionFlowStatus.processing:
      return '评分处理中';
    case SubmissionFlowStatus.completed:
      return '查看点评';
  }
}

IconData _primaryActionIcon(SubmissionFlowStatus status) {
  switch (status) {
    case SubmissionFlowStatus.notStarted:
      return Icons.cloud_upload_rounded;
    case SubmissionFlowStatus.failed:
      return Icons.refresh_rounded;
    case SubmissionFlowStatus.queued:
      return Icons.schedule_rounded;
    case SubmissionFlowStatus.processing:
      return Icons.auto_awesome_rounded;
    case SubmissionFlowStatus.completed:
      return Icons.rate_review_outlined;
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}.${local.day} ${local.hour}:$minute';
}

String _guessMimeType(String? extension) {
  switch ((extension ?? '').toLowerCase()) {
    case 'wav':
      return 'audio/wav';
    case 'aac':
      return 'audio/aac';
    case 'm4a':
    case 'mp4':
      return 'audio/mp4';
    case 'mp3':
    default:
      return 'audio/mpeg';
  }
}

String? _sampleTextFor(PortalTask task) {
  final candidates = [task.ttsText, task.expectedText, task.promptText];
  for (final candidate in candidates) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

_StorageAudioReference _resolveStorageReference(
  String rawReference, {
  required String defaultBucket,
}) {
  final trimmed = rawReference.trim();
  if (trimmed.contains(':')) {
    final index = trimmed.indexOf(':');
    final bucketId = trimmed.substring(0, index).trim();
    final path = trimmed.substring(index + 1).trim();
    if (bucketId.isNotEmpty && path.isNotEmpty) {
      return _StorageAudioReference(bucketId: bucketId, path: path);
    }
  }

  return _StorageAudioReference(bucketId: defaultBucket, path: trimmed);
}

String _pageRangeLabel(PortalTask task) {
  final start = task.startPage;
  final end = task.endPage;
  if (start != null && end != null && start != end) {
    return '第 $start - $end 页';
  }
  final target = start ?? end;
  return target == null ? '教材页码' : '第 $target 页';
}

class _PendingAudioFile {
  const _PendingAudioFile({
    required this.name,
    required this.bytes,
    required this.sizeBytes,
    required this.mimeType,
    this.localPath,
  });

  final String name;
  final Uint8List bytes;
  final int sizeBytes;
  final String mimeType;
  final String? localPath;
}

String _pendingAudioKey(_PendingAudioFile audio) {
  return 'pending:${audio.name}:${audio.sizeBytes}';
}

String _storedAudioKey(String storagePath) {
  return 'stored:$storagePath';
}

String _referenceAudioKey(String storagePath) {
  return 'reference:$storagePath';
}

String _generatedSampleAudioKey(String taskId, String schoolId, String text) {
  return 'speech:$schoolId:$taskId:${text.hashCode}';
}

String? _fileExtension(String fileName) {
  final index = fileName.lastIndexOf('.');
  if (index == -1 || index == fileName.length - 1) {
    return null;
  }
  return fileName.substring(index + 1).toLowerCase();
}

String _extensionForMimeType(String mimeType) {
  final normalized = mimeType.toLowerCase();
  if (normalized.contains('wav')) {
    return 'wav';
  }
  if (normalized.contains('aac')) {
    return 'aac';
  }
  if (normalized.contains('mp4') || normalized.contains('m4a')) {
    return 'm4a';
  }
  if (normalized.contains('mpeg') || normalized.contains('mp3')) {
    return 'mp3';
  }
  return 'mp3';
}

class _StorageAudioReference {
  const _StorageAudioReference({required this.bucketId, required this.path});

  final String bucketId;
  final String path;
}
