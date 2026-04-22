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
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
  final GlobalKey _focusedTaskAnchorKey = GlobalKey();
  final GlobalKey _textbookAnchorKey = GlobalKey();
  final Map<String, String> _storedAudioCache = {};
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];

  Timer? _statusRefreshTimer;
  Timer? _autoAdvanceHintTimer;
  SubmissionFlowStatus? _statusRefreshMode;
  bool _isSubmitting = false;
  bool _isRecording = false;
  String? _recordingPath;
  String? _loadingAudioKey;
  String? _playingAudioKey;
  String? _speakingTaskId;
  String? _focusedTaskId;
  String? _autoAdvanceHint;
  PortalActivity? _staleActivity;
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
    _statusRefreshTimer?.cancel();
    _autoAdvanceHintTimer?.cancel();
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
    final speechKey = _sampleSpeechKey(task.id);
    if (schoolId != null && schoolId.trim().isNotEmpty) {
      try {
        await _toggleAudioPlayback(
          audioKey: _generatedSampleAudioKey(speechKey, schoolId, text),
          resolvePath: () => _resolveGeneratedSampleAudioPath(
            schoolId: schoolId,
            taskId: speechKey,
            text: text,
          ),
          rethrowOnError: true,
        );
        return;
      } catch (_) {
        _showMessage('远程语音暂时没有生成成功，先用本地示范语音继续学习。');
      }
    }

    await _speakTextLocally(speechKey, text);
  }

  Future<void> _playEncouragement(PortalTask task) async {
    final text = task.review?.encouragement.trim();
    if (text == null || text.isEmpty) {
      _showMessage('这句还没有鼓励语。');
      return;
    }

    final schoolContext = ref.read(schoolContextProvider).valueOrNull;
    final schoolId = schoolContext?.schoolId;
    final speechKey = _encouragementSpeechKey(task.id);
    if (schoolId != null && schoolId.trim().isNotEmpty) {
      try {
        await _toggleAudioPlayback(
          audioKey: _generatedSampleAudioKey(speechKey, schoolId, text),
          resolvePath: () => _resolveGeneratedSampleAudioPath(
            schoolId: schoolId,
            taskId: speechKey,
            text: text,
          ),
          rethrowOnError: true,
        );
        return;
      } catch (_) {
        _showMessage('远程鼓励语暂时没有生成成功，先用本地语音继续。');
      }
    }

    await _speakTextLocally(speechKey, text);
  }

  Future<void> _speakTextLocally(String speechKey, String text) async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _playingAudioKey = null;
        _loadingAudioKey = null;
      });
    }

    if (_speakingTaskId == speechKey) {
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
      _speakingTaskId = speechKey;
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
    final currentTask = activity.tasks.firstWhere(
      (task) => task.id == (_focusedTaskId ?? activity.tasks.first.id),
      orElse: () => activity.tasks.first,
    );

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
      ref.invalidate(portalActivityByIdProvider(widget.activityId));
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedAudio = null;
      });
      _focusNextPendingTask(activity, submittedTaskTitle: currentTask.title);
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

  void _syncStatusRefresh(SubmissionFlowStatus status) {
    final shouldRefresh =
        status == SubmissionFlowStatus.queued ||
        status == SubmissionFlowStatus.processing;

    if (!shouldRefresh) {
      _statusRefreshTimer?.cancel();
      _statusRefreshTimer = null;
      _statusRefreshMode = null;
      return;
    }

    if (_statusRefreshTimer != null && _statusRefreshMode == status) {
      return;
    }

    _statusRefreshTimer?.cancel();
    _statusRefreshMode = status;
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(portalActivityByIdProvider(widget.activityId));
    });
  }

  void _focusNextPendingTask(
    PortalActivity activity, {
    String? submittedTaskTitle,
  }) {
    final currentIndex = activity.tasks.indexWhere(
      (task) => task.id == _focusedTaskId,
    );
    final orderedTasks = activity.tasks;
    if (orderedTasks.isEmpty) {
      return;
    }

    PortalTask? nextTask;
    if (currentIndex >= 0) {
      for (var i = currentIndex + 1; i < orderedTasks.length; i += 1) {
        if (orderedTasks[i].reviewStatus != TaskReviewStatus.checked) {
          nextTask = orderedTasks[i];
          break;
        }
      }
    }

    nextTask ??= orderedTasks.firstWhere(
      (task) => task.reviewStatus != TaskReviewStatus.checked,
      orElse: () => orderedTasks.first,
    );

    if (_focusedTaskId == nextTask.id || !mounted) {
      return;
    }
    if ((submittedTaskTitle ?? '').trim().isNotEmpty) {
      _showAutoAdvanceHint('$submittedTaskTitle 已提交，继续下一句。');
    }
    _setFocusedTask(nextTask.id);
  }

  void _setFocusedTask(String taskId) {
    if (!mounted) {
      return;
    }
    setState(() {
      _focusedTaskId = taskId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFocusedTaskIntoView();
    });
  }

  Future<void> _scrollFocusedTaskIntoView() async {
    final anchorContext = _focusedTaskAnchorKey.currentContext;
    if (!mounted || anchorContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      anchorContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Future<void> _scrollTextbookIntoView() async {
    final anchorContext = _textbookAnchorKey.currentContext;
    if (!mounted || anchorContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      anchorContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  void _showAutoAdvanceHint(String message) {
    _autoAdvanceHintTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _autoAdvanceHint = message;
    });
    _autoAdvanceHintTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _autoAdvanceHint = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(
      portalActivityByIdProvider(widget.activityId),
    );
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();

    final latestActivity = activityAsync.valueOrNull;
    if (latestActivity != null) {
      _staleActivity = latestActivity;
    }
    final activity =
        latestActivity ??
        (_staleActivity?.id == widget.activityId ? _staleActivity : null);

    if (activityAsync.isLoading && activity == null) {
      return TabletShell(
        activeSection: TabletSection.teaching,
        brandName: schoolContext.displayName,
        brandSubtitle: '学校学习入口',
        title: '任务详情',
        subtitle: '正在加载今天的学习任务',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (activityAsync.hasError && activity == null) {
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

    _syncStatusRefresh(activity.submissionFlowStatus);

    final selectedAudioKey = _selectedAudio == null
        ? null
        : _pendingAudioKey(_selectedAudio!);
    final storedAudioKey = (activity.submissionAudioPath ?? '').trim().isEmpty
        ? null
        : _storedAudioKey(activity.submissionAudioPath!);

    final autoFocusTask = activity.tasks.firstWhere(
      (task) => task.reviewStatus != TaskReviewStatus.checked,
      orElse: () => activity.tasks.first,
    );
    final focusedTaskId =
        activity.tasks.any((task) => task.id == _focusedTaskId)
        ? _focusedTaskId!
        : autoFocusTask.id;
    final focusTask = activity.tasks.firstWhere(
      (task) => task.id == focusedTaskId,
    );

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
      child: ListView(
        children: [
          Container(
            key: _textbookAnchorKey,
            child: _TextbookStageCard(
              activity: activity,
              tasks: activity.tasks,
              task: focusTask,
              focusedTaskId: focusedTaskId,
              taskIndex:
                  activity.tasks.indexWhere((task) => task.id == focusTask.id) +
                  1,
              totalTasks: activity.tasks.length,
              onSelectTask: _setFocusedTask,
              onOpenFullScreen: () =>
                  _openReadingPage(activity, task: focusTask),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _autoAdvanceHint == null
                ? const SizedBox(height: 0, key: ValueKey('empty-hint'))
                : Padding(
                    key: ValueKey(_autoAdvanceHint),
                    padding: const EdgeInsets.only(top: 14),
                    child: _AutoAdvanceBanner(message: _autoAdvanceHint!),
                  ),
          ),
          if (activity.tasks.length > 1) ...[
            const SizedBox(height: 14),
            _SentenceSwitchStrip(
              tasks: activity.tasks,
              focusedTaskId: focusedTaskId,
              onSelectTask: _setFocusedTask,
            ),
          ],
          const SizedBox(height: 16),
          _SectionHeading(
            eyebrow: '当前句子',
            title: focusTask.reviewStatus == TaskReviewStatus.checked
                ? '这一句的点评就在下面。'
                : '先看这一句，再录音提交。',
            subtitle: focusTask.reviewStatus == TaskReviewStatus.checked
                ? '绿色标签表示 AI 初评；如果老师已经复核，会额外标明老师已复核。'
                : '上方是教材，下方这张卡只处理当前这一句的示范、录音和提交。',
          ),
          const SizedBox(height: 12),
          Container(
            key: _focusedTaskAnchorKey,
            child: _TaskCard(
              index:
                  activity.tasks.indexWhere((task) => task.id == focusTask.id) +
                  1,
              task: focusTask,
              submissionFlowStatus: activity.submissionFlowStatus,
              submissionStatusHint: activity.submissionStatusHint,
              selectedAudioLabel: _selectedAudio?.name,
              existingAudioLabel: activity.submissionAudioName,
              isSubmitting: _isSubmitting,
              isRecording: _isRecording,
              isSpeaking: _speakingTaskId == _sampleSpeechKey(focusTask.id),
              isSamplePlaying: focusTask.hasReferenceAudio
                  ? _referenceAudioKey(focusTask.referenceAudioPath!) ==
                        _playingAudioKey
                  : _speakingTaskId == _sampleSpeechKey(focusTask.id),
              isSampleLoading: focusTask.hasReferenceAudio
                  ? _referenceAudioKey(focusTask.referenceAudioPath!) ==
                        _loadingAudioKey
                  : false,
              isEncouragementPlaying:
                  (focusTask.review?.encouragement.trim().isNotEmpty == true &&
                      _generatedSampleAudioKey(
                            _encouragementSpeechKey(focusTask.id),
                            schoolContext.schoolId ?? 'local',
                            focusTask.review!.encouragement,
                          ) ==
                          _playingAudioKey) ||
                  _speakingTaskId == _encouragementSpeechKey(focusTask.id),
              isEncouragementLoading:
                  focusTask.review?.encouragement.trim().isNotEmpty == true &&
                  _generatedSampleAudioKey(
                        _encouragementSpeechKey(focusTask.id),
                        schoolContext.schoolId ?? 'local',
                        focusTask.review!.encouragement,
                      ) ==
                      _loadingAudioKey,
              isSelectedAudioPlaying: selectedAudioKey == _playingAudioKey,
              isSelectedAudioLoading: selectedAudioKey == _loadingAudioKey,
              isStoredAudioPlaying: storedAudioKey == _playingAudioKey,
              isStoredAudioLoading: storedAudioKey == _loadingAudioKey,
              onOpenReading: activity.materialPdfPath == null
                  ? null
                  : _scrollTextbookIntoView,
              onSpeakSample: focusTask.hasReferenceAudio
                  ? () => _toggleReferenceAudioPlayback(focusTask)
                  : _sampleTextFor(focusTask) == null
                  ? null
                  : () => _speakSample(focusTask),
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
              onPlayEncouragement: focusTask.review == null
                  ? null
                  : () => _playEncouragement(focusTask),
              onPrimaryAction: () => _handlePrimaryAction(activity),
              isFocusTask: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: const Color(0xFF2FA77D),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AutoAdvanceBanner extends StatelessWidget {
  const _AutoAdvanceBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBF1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6F2E2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF2FA77D),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF0F8B6D),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfStateMessage extends StatelessWidget {
  const _PdfStateMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 44,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextbookStageCard extends StatefulWidget {
  const _TextbookStageCard({
    required this.activity,
    required this.tasks,
    required this.task,
    required this.focusedTaskId,
    required this.taskIndex,
    required this.totalTasks,
    required this.onSelectTask,
    required this.onOpenFullScreen,
  });

  final PortalActivity activity;
  final List<PortalTask> tasks;
  final PortalTask task;
  final String focusedTaskId;
  final int taskIndex;
  final int totalTasks;
  final ValueChanged<String> onSelectTask;
  final VoidCallback onOpenFullScreen;

  @override
  State<_TextbookStageCard> createState() => _TextbookStageCardState();
}

class _TextbookStageCardState extends State<_TextbookStageCard> {
  late final PdfViewerController _pdfController;
  late Future<Uint8List> _pdfFuture;
  bool _documentReady = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _reloadPdf();
  }

  @override
  void didUpdateWidget(covariant _TextbookStageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activity.materialPdfPath != oldWidget.activity.materialPdfPath) {
      _reloadPdf();
      return;
    }
    if (widget.task.startPage != oldWidget.task.startPage ||
        widget.task.endPage != oldWidget.task.endPage) {
      _jumpToTaskPage();
    }
  }

  void _reloadPdf() {
    _documentReady = false;
    _pdfFuture = _loadPdfBytes();
  }

  Future<Uint8List> _loadPdfBytes() async {
    final pdfPath = widget.activity.materialPdfPath;
    if (pdfPath == null || pdfPath.trim().isEmpty) {
      throw StateError('老师还没有上传教材 PDF。');
    }

    return Supabase.instance.client.storage.from('materials').download(pdfPath);
  }

  void _jumpToTaskPage() {
    if (!_documentReady) {
      return;
    }
    final startPage = widget.task.startPage;
    if (startPage == null || startPage <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _pdfController.jumpToPage(startPage);
    });
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageLabel = _pageRangeLabel(widget.task);
    final focusedPageImagePath = widget.task.region?.pageImagePath;
    final pageTasks = focusedPageImagePath == null
        ? const <PortalTask>[]
        : widget.tasks
              .where((task) => task.region?.pageImagePath == focusedPageImagePath)
              .toList()
            ..sort(
              (left, right) =>
                  (left.region?.pageNumber ?? 0) == (right.region?.pageNumber ?? 0)
                  ? left.title.compareTo(right.title)
                  : (left.region?.pageNumber ?? 0).compareTo(
                      right.region?.pageNumber ?? 0,
                    ),
            );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2FBF5), Color(0xFFFFF7E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
              Text(
                widget.activity.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w900,
                ),
              ),
              _OverviewChip(
                icon: Icons.flag_rounded,
                label: '当前第 ${widget.taskIndex} / ${widget.totalTasks} 句',
              ),
              _OverviewChip(icon: Icons.menu_book_rounded, label: pageLabel),
              if ((widget.activity.materialTitle ?? '').trim().isNotEmpty)
                _OverviewChip(
                  icon: Icons.auto_stories_rounded,
                  label: widget.activity.materialTitle!,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '先在这页课本里看内容，再在下面完成这一句的示范、录音和提交。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 460,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: focusedPageImagePath != null
                  ? _TextbookImageStage(
                      pageImagePath: focusedPageImagePath,
                      tasks: pageTasks,
                      focusedTaskId: widget.focusedTaskId,
                      onSelectTask: widget.onSelectTask,
                    )
                  : FutureBuilder<Uint8List>(
                      future: _pdfFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError || !snapshot.hasData) {
                          return _PdfStateMessage(
                            title: '教材暂时打不开',
                            message: snapshot.error?.toString() ?? '请稍后重试。',
                          );
                        }

                        return Stack(
                          children: [
                            SfPdfViewer.memory(
                              snapshot.data!,
                              controller: _pdfController,
                              canShowPaginationDialog: false,
                              canShowScrollHead: false,
                              onDocumentLoaded: (_) {
                                _documentReady = true;
                                _jumpToTaskPage();
                              },
                            ),
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: FilledButton.tonalIcon(
                                onPressed: widget.onOpenFullScreen,
                                icon: const Icon(Icons.open_in_full_rounded),
                                label: const Text('放大看教材'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextbookImageStage extends StatelessWidget {
  const _TextbookImageStage({
    required this.pageImagePath,
    required this.tasks,
    required this.focusedTaskId,
    required this.onSelectTask,
  });

  final String pageImagePath;
  final List<PortalTask> tasks;
  final String focusedTaskId;
  final ValueChanged<String> onSelectTask;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _StageImage(path: pageImagePath),
        for (final task in tasks)
          if (task.region != null)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final region = task.region!;
                  final left = constraints.maxWidth * region.x;
                  final top = constraints.maxHeight * region.y;
                  final width = constraints.maxWidth * region.width;
                  final height = constraints.maxHeight * region.height;
                  final isFocused = task.id == focusedTaskId;
                  final isDone = task.reviewStatus == TaskReviewStatus.checked;

                  return Stack(
                    children: [
                      Positioned(
                        left: left,
                        top: top,
                        width: width,
                        height: height,
                        child: GestureDetector(
                          onTap: () => onSelectTask(task.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? const Color(0x33F97316)
                                  : isDone
                                  ? const Color(0x2216A34A)
                                  : const Color(0x22FFFFFF),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isFocused
                                    ? const Color(0xFFF97316)
                                    : isDone
                                    ? const Color(0xFF16A34A)
                                    : const Color(0x66FFFFFF),
                                width: isFocused ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: isFocused
                                            ? const Color(0xFFEA580C)
                                            : const Color(0xFF1E293B),
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
      ],
    );
  }
}

class _StageImage extends StatelessWidget {
  const _StageImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('asset:')) {
      return Image.asset(
        path.substring('asset:'.length),
        fit: BoxFit.contain,
      );
    }

    return FutureBuilder<Uint8List>(
      future: Supabase.instance.client.storage.from('material-pages').download(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _PdfStateMessage(
            title: '教材页暂时打不开',
            message: snapshot.error?.toString() ?? '请稍后重试。',
          );
        }
        return Image.memory(snapshot.data!, fit: BoxFit.contain);
      },
    );
  }
}

class _SentenceSwitchStrip extends StatelessWidget {
  const _SentenceSwitchStrip({
    required this.tasks,
    required this.focusedTaskId,
    required this.onSelectTask,
  });

  final List<PortalTask> tasks;
  final String focusedTaskId;
  final ValueChanged<String> onSelectTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '句子切换',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: const Color(0xFF2FA77D),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isFocused = task.id == focusedTaskId;
              return ChoiceChip(
                label: Text('句子 ${index + 1}'),
                selected: isFocused,
                onSelected: (_) => onSelectTask(task.id),
                selectedColor: const Color(0xFFFFEDD5),
                labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isFocused
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide(
                  color: isFocused
                      ? const Color(0xFFEA580C)
                      : const Color(0xFFDDE6E6),
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                showCheckmark: false,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LabeledTextBlock extends StatelessWidget {
  const _LabeledTextBlock({
    required this.label,
    required this.text,
    required this.background,
    this.foreground = const Color(0xFF475569),
  });

  final String label;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
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

class _TaskReviewPanel extends StatelessWidget {
  const _TaskReviewPanel({
    required this.review,
    required this.isEncouragementPlaying,
    required this.isEncouragementLoading,
    this.onPlayEncouragement,
  });

  final PortalTaskReview review;
  final bool isEncouragementPlaying;
  final bool isEncouragementLoading;
  final VoidCallback? onPlayEncouragement;

  @override
  Widget build(BuildContext context) {
    final scoreLabel = review.score.toStringAsFixed(0);
    final canPlayEncouragement =
        onPlayEncouragement != null && review.encouragement.trim().isNotEmpty;
    final reviewBadgeLabel = isEncouragementLoading
        ? 'AI 初评生成中'
        : isEncouragementPlaying
        ? '停止鼓励语'
        : 'AI 初评';
    final subheading = review.isTeacherReviewedReference
        ? '下面是这一句的 AI 初评，老师已经看过整份作业。'
        : '下面是这一句的 AI 初评。';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FBF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9F1E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review.isTeacherReviewedReference ? '这一句的 AI 点评' : 'AI 句子点评',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subheading,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: review.isTeacherReviewedReference
                  ? const Color(0xFFE0F2FE)
                  : const Color(0xFFEAFBF1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              review.isTeacherReviewedReference
                  ? '点评来源：AI 初评，老师已复核整份作业'
                  : '点评来源：AI 初评',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: review.isTeacherReviewedReference
                    ? const Color(0xFF0369A1)
                    : const Color(0xFF0F8B6D),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReviewBadge(
                icon: isEncouragementLoading
                    ? Icons.hourglass_top_rounded
                    : isEncouragementPlaying
                    ? Icons.stop_circle_rounded
                    : Icons.auto_awesome_rounded,
                label: reviewBadgeLabel,
                color: const Color(0xFF0F8B6D),
                background: const Color(0xFFDFF8EC),
                onTap: canPlayEncouragement ? onPlayEncouragement : null,
              ),
              if (review.isTeacherReviewedReference)
                const _ReviewBadge(
                  icon: Icons.person_rounded,
                  label: '老师已复核整份作业',
                  color: Color(0xFF0369A1),
                  background: Color(0xFFE0F2FE),
                ),
              _ReviewBadge(
                icon: Icons.star_rounded,
                label: '本句得分 $scoreLabel',
                color: const Color(0xFFF97316),
                background: const Color(0xFFFFEBD9),
              ),
              if (review.pronunciationScore != null)
                _ReviewMetricChip(
                  label: '发音 ${review.pronunciationScore!.toStringAsFixed(0)}',
                ),
              if (review.fluencyScore != null)
                _ReviewMetricChip(
                  label: '流利度 ${review.fluencyScore!.toStringAsFixed(0)}',
                ),
              if (review.completenessScore != null)
                _ReviewMetricChip(
                  label: '完整度 ${review.completenessScore!.toStringAsFixed(0)}',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            review.summaryFeedback,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w800,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isPhone = constraints.maxWidth < 720;
              final strengthsCard = _ReviewListCard(
                title: '这句读得好的地方',
                icon: Icons.thumb_up_alt_rounded,
                background: const Color(0xFFEAFBF1),
                foreground: const Color(0xFF0F8B6D),
                items: review.strengths.isEmpty
                    ? const ['这句已经认真开口读出来了。']
                    : review.strengths,
              );
              final improvementCard = _ReviewListCard(
                title: '下次可以继续加强',
                icon: Icons.flag_rounded,
                background: const Color(0xFFFFF4E8),
                foreground: const Color(0xFFB45309),
                items: review.improvementPoints.isEmpty
                    ? const ['再跟着示范多读一遍，会更顺。']
                    : review.improvementPoints,
              );

              if (isPhone) {
                return Column(
                  children: [
                    strengthsCard,
                    const SizedBox(height: 12),
                    improvementCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: strengthsCard),
                  const SizedBox(width: 12),
                  Expanded(child: improvementCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: onTap == null
            ? null
            : Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return badge;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: badge,
      ),
    );
  }
}

class _ReviewMetricChip extends StatelessWidget {
  const _ReviewMetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE7E3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF475569),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReviewListCard extends StatelessWidget {
  const _ReviewListCard({
    required this.title,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color background;
  final Color foreground;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w700,
                        height: 1.45,
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
    required this.isEncouragementPlaying,
    required this.isEncouragementLoading,
    this.onOpenReading,
    this.onSpeakSample,
    this.onPickAudio,
    this.onRecordAudio,
    this.onClearSelectedAudio,
    this.onPlaySelectedAudio,
    this.onPlayStoredAudio,
    this.onPlayEncouragement,
    required this.onPrimaryAction,
    this.isFocusTask = false,
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
  final bool isEncouragementPlaying;
  final bool isEncouragementLoading;
  final VoidCallback? onOpenReading;
  final VoidCallback? onSpeakSample;
  final VoidCallback? onPickAudio;
  final VoidCallback? onRecordAudio;
  final VoidCallback? onPlaySelectedAudio;
  final VoidCallback? onPlayStoredAudio;
  final VoidCallback? onPlayEncouragement;
  final VoidCallback? onClearSelectedAudio;
  final VoidCallback onPrimaryAction;
  final bool isFocusTask;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(task.reviewStatus);
    final statusColor = _statusColor(task.reviewStatus);
    final sampleText = _sampleTextFor(task);
    final samplePreviewLabel = isSampleLoading
        ? '示范加载中'
        : isSamplePlaying
        ? '点一下停止示范'
        : task.hasReferenceAudio
        ? '点这里听示范音频'
        : '点这里听示范';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 720;
          final preview = Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSpeakSample,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                width: isPhone ? double.infinity : 140,
                height: 82,
                decoration: BoxDecoration(
                  gradient: _previewGradient(task.kind),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  children: [
                    Align(
                      child: isSampleLoading
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isSamplePlaying
                                  ? Icons.stop_circle_rounded
                                  : _previewIcon(task.kind),
                              color: Colors.white,
                              size: 36,
                            ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Text(
                        samplePreviewLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                _LabeledTextBlock(
                  label: '老师提示',
                  text: task.promptText!,
                  background: const Color(0xFFF8FAFC),
                ),
              ],
              if (sampleText != null) ...[
                const SizedBox(height: 10),
                _LabeledTextBlock(
                  label: '这句原文',
                  text: sampleText,
                  background: const Color(0xFFF7F7FF),
                  foreground: const Color(0xFF1E293B),
                ),
              ],
              if (task.review != null) ...[
                const SizedBox(height: 16),
                _TaskReviewPanel(
                  review: task.review!,
                  onPlayEncouragement: onPlayEncouragement,
                  isEncouragementPlaying: isEncouragementPlaying,
                  isEncouragementLoading: isEncouragementLoading,
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
                      onTap: onOpenReading,
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
                onRecordAudio: onRecordAudio,
                onClearSelectedAudio: onClearSelectedAudio,
                onPlaySelectedAudio: onPlaySelectedAudio,
                onPlayStoredAudio: onPlayStoredAudio,
                onPrimaryAction: onPrimaryAction,
              ),
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
            children: [header],
          );
        },
      ),
    );
  }

  String _statusLabel(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return '这一句的 AI 点评已生成';
      case TaskReviewStatus.pendingReview:
        return '已经提交，等待 AI 和老师处理';
      case TaskReviewStatus.inProgress:
        return '先听示范，再录音提交';
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
    this.onRecordAudio,
    this.onClearSelectedAudio,
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
  final VoidCallback? onRecordAudio;
  final VoidCallback? onClearSelectedAudio;
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
      SubmissionFlowStatus.completed => 'AI 点评已生成',
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
        isRecording ? '读完后点击“结束录音并保存”，再提交给老师。' : '先听示范，再录音，然后提交给老师。',
      SubmissionFlowStatus.queued => submissionStatusHint ?? '已经提交成功，等待老师查看。',
      SubmissionFlowStatus.processing =>
        submissionStatusHint ?? '系统正在生成 AI 初评，请稍后刷新查看。',
      SubmissionFlowStatus.failed =>
        submissionStatusHint ?? '这次没有完成自动处理，你可以重新提交一次。',
      SubmissionFlowStatus.completed =>
        '这一句的 AI 点评已经显示在上面了，如果想读得更好，可以重新录音后再次提交。',
    };
    final canSubmit =
        submissionFlowStatus == SubmissionFlowStatus.notStarted ||
        submissionFlowStatus == SubmissionFlowStatus.failed ||
        submissionFlowStatus == SubmissionFlowStatus.completed;
    final hasSelectedAudio = (selectedAudioLabel ?? '').trim().isNotEmpty;
    final primaryLabel = isRecording
        ? '结束录音并保存'
        : hasSelectedAudio
        ? (isSubmitting
              ? (submissionFlowStatus == SubmissionFlowStatus.failed
                    ? '重新提交中'
                    : submissionFlowStatus == SubmissionFlowStatus.completed
                    ? '再次提交中'
                    : '提交中')
              : (submissionFlowStatus == SubmissionFlowStatus.failed
                    ? '重新提交这一句'
                    : submissionFlowStatus == SubmissionFlowStatus.completed
                    ? '再次提交这一句'
                    : '提交这一句'))
        : '开始录音';
    final primaryIcon = isSubmitting
        ? null
        : isRecording
        ? Icons.stop_circle_rounded
        : hasSelectedAudio
        ? (submissionFlowStatus == SubmissionFlowStatus.failed
              ? Icons.refresh_rounded
              : submissionFlowStatus == SubmissionFlowStatus.completed
              ? Icons.restart_alt_rounded
              : Icons.cloud_upload_rounded)
        : Icons.mic_rounded;
    final primaryAction = isSubmitting
        ? null
        : isRecording
        ? onRecordAudio
        : hasSelectedAudio
        ? (canSubmit ? onPrimaryAction : null)
        : onRecordAudio;

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
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: primaryAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFFFF8F4D),
              foregroundColor: Colors.white,
            ),
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(primaryIcon),
            label: Text(primaryLabel),
          ),
          const SizedBox(height: 12),
          if (hasSelectedAudio && onClearSelectedAudio != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isSubmitting ? null : onClearSelectedAudio,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('删除这段音频'),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskInfoChip extends StatelessWidget {
  const _TaskInfoChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: onTap == null
            ? const Color(0xFFF8FAFC)
            : const Color(0xFFEAFBF1),
        borderRadius: BorderRadius.circular(14),
        border: onTap == null
            ? null
            : Border.all(color: const Color(0xFFD6F2E2)),
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
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: Color(0xFF2FA77D),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return chip;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: chip,
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

String _sampleSpeechKey(String taskId) {
  return 'sample:$taskId';
}

String _encouragementSpeechKey(String taskId) {
  return 'encouragement:$taskId';
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
