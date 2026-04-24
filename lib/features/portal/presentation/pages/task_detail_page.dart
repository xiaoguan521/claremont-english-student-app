import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';

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
  final Map<String, String> _storedVideoCache = {};
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

  Future<void> _openTeachingVideo(PortalTask task) async {
    final videoPath = task.teachingVideoPath;
    if (videoPath == null || videoPath.trim().isEmpty) {
      _showMessage('这句暂时还没有配套动画。');
      return;
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => _TeachingVideoDialog(
        title: task.title,
        rawReference: videoPath,
        onResolveStoragePath: (reference) => _resolveStorageVideoPath(
          reference,
          defaultBucket: 'teaching-video',
        ),
      ),
    );
  }

  Future<void> _openReadingPage(
    PortalActivity activity, {
    PortalTask? task,
    bool startFullscreen = false,
  }) async {
    if ((activity.materialPdfPath ?? '').trim().isEmpty) {
      _showMessage('老师还没有上传教材 PDF。');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReadingPage(
          activity: activity,
          task: task,
          startFullscreen: startFullscreen,
        ),
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

    if (resolvedReference.bucketId == 'asset') {
      final assetPath = _normalizeBundledAssetPath(resolvedReference.path);
      final bytes = await _loadBundledAssetBytes(assetPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = assetPath.split('/').last;
      final targetPath =
          '${tempDir.path}/asset-audio-${DateTime.now().millisecondsSinceEpoch}-$fileName';
      await File(
        targetPath,
      ).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      _storedAudioCache[cacheKey] = targetPath;
      return targetPath;
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

  Future<String> _resolveStorageVideoPath(
    String storageReference, {
    required String defaultBucket,
  }) async {
    final resolvedReference = _resolveStorageReference(
      storageReference,
      defaultBucket: defaultBucket,
    );
    final cacheKey = '${resolvedReference.bucketId}:${resolvedReference.path}';
    final cachedPath = _storedVideoCache[cacheKey];
    if (cachedPath != null && await File(cachedPath).exists()) {
      return cachedPath;
    }

    if (resolvedReference.bucketId == 'asset') {
      final assetPath = _normalizeBundledAssetPath(resolvedReference.path);
      final bytes = await _loadBundledAssetBytes(assetPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = assetPath.split('/').last;
      final targetPath =
          '${tempDir.path}/asset-video-${DateTime.now().millisecondsSinceEpoch}-$fileName';
      await File(
        targetPath,
      ).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      _storedVideoCache[cacheKey] = targetPath;
      return targetPath;
    }

    final bytes = await Supabase.instance.client.storage
        .from(resolvedReference.bucketId)
        .download(resolvedReference.path);
    final tempDir = await getTemporaryDirectory();
    final fileName = resolvedReference.path.split('/').last;
    final targetPath =
        '${tempDir.path}/${resolvedReference.bucketId.replaceAll(RegExp(r"[^a-zA-Z0-9_-]"), "_")}-video-$fileName';
    await File(targetPath).writeAsBytes(bytes, flush: true);
    _storedVideoCache[cacheKey] = targetPath;
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscapePhone =
              constraints.maxWidth > constraints.maxHeight &&
              constraints.maxWidth < 1100;
          final visualScale = isLandscapePhone
              ? _taskDetailLandscapeVisualScale(
                  constraints.maxWidth,
                  constraints.maxHeight,
                )
              : 1.0;
          final textScale = isLandscapePhone
              ? (MediaQuery.textScalerOf(context).scale(1) * visualScale).clamp(
                  0.82,
                  1.0,
                )
              : MediaQuery.textScalerOf(context).scale(1);
          final stageCard = Container(
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
              onOpenFullScreen: () => _openReadingPage(
                activity,
                task: focusTask,
                startFullscreen: true,
              ),
              compact: isLandscapePhone,
              visualScale: visualScale,
              bottomSheet: _TextbookFloatingPanel(
                task: focusTask,
                submissionFlowStatus: activity.submissionFlowStatus,
                submissionStatusHint: activity.submissionStatusHint,
                selectedAudioLabel: _selectedAudio?.name,
                existingAudioLabel: activity.submissionAudioName,
                isSubmitting: _isSubmitting,
                isRecording: _isRecording,
                isSamplePlaying: focusTask.hasReferenceAudio
                    ? _referenceAudioKey(focusTask.referenceAudioPath!) ==
                          _playingAudioKey
                    : _speakingTaskId == _sampleSpeechKey(focusTask.id),
                isSampleLoading: focusTask.hasReferenceAudio
                    ? _referenceAudioKey(focusTask.referenceAudioPath!) ==
                          _loadingAudioKey
                    : false,
                isSelectedAudioPlaying: selectedAudioKey == _playingAudioKey,
                isSelectedAudioLoading: selectedAudioKey == _loadingAudioKey,
                isStoredAudioPlaying: storedAudioKey == _playingAudioKey,
                isStoredAudioLoading: storedAudioKey == _loadingAudioKey,
                onOpenReading: activity.materialPdfPath == null
                    ? null
                    : () => _openReadingPage(activity, task: focusTask),
                onSpeakSample: focusTask.hasReferenceAudio
                    ? () => _toggleReferenceAudioPlayback(focusTask)
                    : _sampleTextFor(focusTask) == null
                    ? null
                    : () => _speakSample(focusTask),
                onOpenVideo: focusTask.hasTeachingVideo
                    ? () => _openTeachingVideo(focusTask)
                    : null,
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
              ),
            ),
          );

          final reviewPanel = _LandscapeReviewColumn(
            autoAdvanceHint: _autoAdvanceHint,
            tasks: activity.tasks,
            focusedTaskId: focusedTaskId,
            onSelectTask: _setFocusedTask,
            focusTask: focusTask,
            activity: activity,
            schoolContext: schoolContext,
            focusedTaskAnchorKey: _focusedTaskAnchorKey,
            selectedAudio: _selectedAudio,
            isSubmitting: _isSubmitting,
            isRecording: _isRecording,
            speakingTaskId: _speakingTaskId,
            playingAudioKey: _playingAudioKey,
            loadingAudioKey: _loadingAudioKey,
            storedAudioKey: storedAudioKey,
            sampleSpeechKeyForTask: _sampleSpeechKey(focusTask.id),
            onOpenReading: activity.materialPdfPath == null
                ? null
                : _scrollTextbookIntoView,
            onSpeakSample: focusTask.hasReferenceAudio
                ? () => _toggleReferenceAudioPlayback(focusTask)
                : _sampleTextFor(focusTask) == null
                ? null
                : () => _speakSample(focusTask),
            onOpenVideo: focusTask.hasTeachingVideo
                ? () => _openTeachingVideo(focusTask)
                : null,
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
            visualScale: visualScale,
          );

          if (isLandscapePhone) {
            final reviewWidth = constraints.maxWidth < 920 ? 292.0 : 332.0;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(child: stageCard),
                  ),
                  SizedBox(width: 16 * visualScale),
                  SizedBox(
                    width: reviewWidth * visualScale,
                    child: reviewPanel,
                  ),
                ],
              ),
            );
          }

          return ListView(
            children: [
              stageCard,
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
                title: focusTask.reviewStatus == TaskReviewStatus.checked
                    ? '这一句完成了'
                    : '做这一句',
              ),
              const SizedBox(height: 12),
              Container(
                key: _focusedTaskAnchorKey,
                child: _TaskCard(
                  index:
                      activity.tasks.indexWhere(
                        (task) => task.id == focusTask.id,
                      ) +
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
                      (focusTask.review?.encouragement.trim().isNotEmpty ==
                              true &&
                          _generatedSampleAudioKey(
                                _encouragementSpeechKey(focusTask.id),
                                schoolContext.schoolId ?? 'local',
                                focusTask.review!.encouragement,
                              ) ==
                              _playingAudioKey) ||
                      _speakingTaskId == _encouragementSpeechKey(focusTask.id),
                  isEncouragementLoading:
                      focusTask.review?.encouragement.trim().isNotEmpty ==
                          true &&
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
                  onOpenVideo: focusTask.hasTeachingVideo
                      ? () => _openTeachingVideo(focusTask)
                      : null,
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
                  showSubmissionSection: false,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _LandscapeReviewColumn extends StatelessWidget {
  const _LandscapeReviewColumn({
    required this.autoAdvanceHint,
    required this.tasks,
    required this.focusedTaskId,
    required this.onSelectTask,
    required this.focusTask,
    required this.activity,
    required this.schoolContext,
    required this.focusedTaskAnchorKey,
    required this.selectedAudio,
    required this.isSubmitting,
    required this.isRecording,
    required this.speakingTaskId,
    required this.playingAudioKey,
    required this.loadingAudioKey,
    required this.storedAudioKey,
    required this.sampleSpeechKeyForTask,
    this.onOpenReading,
    this.onSpeakSample,
    this.onOpenVideo,
    this.onPickAudio,
    this.onRecordAudio,
    this.onClearSelectedAudio,
    this.onPlaySelectedAudio,
    this.onPlayStoredAudio,
    this.onPlayEncouragement,
    required this.onPrimaryAction,
    this.visualScale = 1,
  });

  final String? autoAdvanceHint;
  final List<PortalTask> tasks;
  final String focusedTaskId;
  final ValueChanged<String> onSelectTask;
  final PortalTask focusTask;
  final PortalActivity activity;
  final SchoolContext schoolContext;
  final GlobalKey focusedTaskAnchorKey;
  final _PendingAudioFile? selectedAudio;
  final bool isSubmitting;
  final bool isRecording;
  final String? speakingTaskId;
  final String? playingAudioKey;
  final String? loadingAudioKey;
  final String? storedAudioKey;
  final String sampleSpeechKeyForTask;
  final VoidCallback? onOpenReading;
  final VoidCallback? onSpeakSample;
  final VoidCallback? onOpenVideo;
  final VoidCallback? onPickAudio;
  final VoidCallback? onRecordAudio;
  final VoidCallback? onClearSelectedAudio;
  final VoidCallback? onPlaySelectedAudio;
  final VoidCallback? onPlayStoredAudio;
  final VoidCallback? onPlayEncouragement;
  final VoidCallback onPrimaryAction;
  final double visualScale;

  @override
  Widget build(BuildContext context) {
    final selectedAudioKey = selectedAudio == null
        ? null
        : _pendingAudioKey(selectedAudio!);
    return Column(
      children: [
        if (autoAdvanceHint != null)
          Padding(
            padding: EdgeInsets.only(bottom: 12 * visualScale),
            child: _AutoAdvanceBanner(message: autoAdvanceHint!),
          ),
        Container(
          padding: EdgeInsets.all(18 * visualScale),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(title: '句子列表'),
              if (tasks.length > 1) ...[
                SizedBox(height: 12 * visualScale),
                _SentenceSwitchStrip(
                  tasks: tasks,
                  focusedTaskId: focusedTaskId,
                  onSelectTask: onSelectTask,
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 14 * visualScale),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              key: focusedTaskAnchorKey,
              child: _TaskCard(
                index:
                    activity.tasks.indexWhere(
                      (task) => task.id == focusTask.id,
                    ) +
                    1,
                task: focusTask,
                submissionFlowStatus: activity.submissionFlowStatus,
                submissionStatusHint: activity.submissionStatusHint,
                selectedAudioLabel: selectedAudio?.name,
                existingAudioLabel: activity.submissionAudioName,
                isSubmitting: isSubmitting,
                isRecording: isRecording,
                isSpeaking: speakingTaskId == sampleSpeechKeyForTask,
                isSamplePlaying: focusTask.hasReferenceAudio
                    ? _referenceAudioKey(focusTask.referenceAudioPath!) ==
                          playingAudioKey
                    : speakingTaskId == sampleSpeechKeyForTask,
                isSampleLoading: focusTask.hasReferenceAudio
                    ? _referenceAudioKey(focusTask.referenceAudioPath!) ==
                          loadingAudioKey
                    : false,
                isEncouragementPlaying:
                    (focusTask.review?.encouragement.trim().isNotEmpty ==
                            true &&
                        _generatedSampleAudioKey(
                              _encouragementSpeechKey(focusTask.id),
                              schoolContext.schoolId ?? 'local',
                              focusTask.review!.encouragement,
                            ) ==
                            playingAudioKey) ||
                    speakingTaskId == _encouragementSpeechKey(focusTask.id),
                isEncouragementLoading:
                    focusTask.review?.encouragement.trim().isNotEmpty == true &&
                    _generatedSampleAudioKey(
                          _encouragementSpeechKey(focusTask.id),
                          schoolContext.schoolId ?? 'local',
                          focusTask.review!.encouragement,
                        ) ==
                        loadingAudioKey,
                isSelectedAudioPlaying: selectedAudioKey == playingAudioKey,
                isSelectedAudioLoading: selectedAudioKey == loadingAudioKey,
                isStoredAudioPlaying: storedAudioKey == playingAudioKey,
                isStoredAudioLoading: storedAudioKey == loadingAudioKey,
                onOpenReading: onOpenReading,
                onSpeakSample: onSpeakSample,
                onOpenVideo: onOpenVideo,
                onPickAudio: onPickAudio,
                onRecordAudio: onRecordAudio,
                onClearSelectedAudio: onClearSelectedAudio,
                onPlaySelectedAudio: onPlaySelectedAudio,
                onPlayStoredAudio: onPlayStoredAudio,
                onPlayEncouragement: onPlayEncouragement,
                onPrimaryAction: onPrimaryAction,
                isFocusTask: true,
                showSubmissionSection: false,
              ),
            ),
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
    required this.bottomSheet,
    this.compact = false,
    this.visualScale = 1,
  });

  final PortalActivity activity;
  final List<PortalTask> tasks;
  final PortalTask task;
  final String focusedTaskId;
  final int taskIndex;
  final int totalTasks;
  final ValueChanged<String> onSelectTask;
  final VoidCallback onOpenFullScreen;
  final Widget bottomSheet;
  final bool compact;
  final double visualScale;

  @override
  State<_TextbookStageCard> createState() => _TextbookStageCardState();
}

class _TextbookStageCardState extends State<_TextbookStageCard> {
  late final PdfViewerController _pdfController;
  late Future<Uint8List?> _pdfFuture;
  late Future<_EmbeddedTextbookLayoutData> _layoutFuture;
  bool _documentReady = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _reloadPdf();
    _reloadLayout();
  }

  @override
  void didUpdateWidget(covariant _TextbookStageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activity.materialPdfPath != oldWidget.activity.materialPdfPath) {
      _reloadPdf();
      _reloadLayout();
      return;
    }
    if (widget.task.region?.pageImagePath !=
        oldWidget.task.region?.pageImagePath) {
      _reloadLayout();
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

  void _reloadLayout() {
    _layoutFuture = _loadEmbeddedTextbookLayout();
  }

  Future<Uint8List?> _loadPdfBytes() async {
    final pdfPath = widget.activity.materialPdfPath;
    if (pdfPath == null || pdfPath.trim().isEmpty) {
      return null;
    }

    if (pdfPath.startsWith('asset:')) {
      return _loadBundledAssetBytes(pdfPath.substring('asset:'.length));
    }

    return Supabase.instance.client.storage.from('materials').download(pdfPath);
  }

  Future<_EmbeddedTextbookLayoutData> _loadEmbeddedTextbookLayout() async {
    final pageImagePath = widget.task.region?.pageImagePath;
    if (pageImagePath != null && pageImagePath.trim().isNotEmpty) {
      final imageData = await _loadStageImageData(pageImagePath);
      return _EmbeddedTextbookLayoutData(
        viewportAspectRatio: imageData.width / imageData.height,
        stageImageData: imageData,
      );
    }

    return const _EmbeddedTextbookLayoutData(viewportAspectRatio: 0.72);
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
        ? <PortalTask>[]
        : widget.tasks
              .where(
                (task) => task.region?.pageImagePath == focusedPageImagePath,
              )
              .toList();

    pageTasks.sort(
      (left, right) =>
          (left.region?.pageNumber ?? 0) == (right.region?.pageNumber ?? 0)
          ? left.title.compareTo(right.title)
          : (left.region?.pageNumber ?? 0).compareTo(
              right.region?.pageNumber ?? 0,
            ),
    );

    final stageBottomInset =
        (widget.compact ? 154.0 : 184.0) * widget.visualScale;

    return Container(
      padding: EdgeInsets.all((widget.compact ? 16 : 20) * widget.visualScale),
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
            spacing: 12 * widget.visualScale,
            runSpacing: 12 * widget.visualScale,
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
          SizedBox(height: (widget.compact ? 10 : 12) * widget.visualScale),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StageLegendChip(
                label: '当前',
                background: Color(0xFFFFEDD5),
                foreground: Color(0xFFEA580C),
                icon: Icons.radio_button_checked_rounded,
              ),
              _StageLegendChip(
                label: '已完成',
                background: Color(0xFFEAFBF1),
                foreground: Color(0xFF16A34A),
                icon: Icons.check_circle_rounded,
              ),
              _StageLegendChip(
                label: '待完成',
                background: Color(0xFFFFFFFF),
                foreground: Color(0xFF64748B),
                icon: Icons.panorama_fish_eye_rounded,
              ),
            ],
          ),
          SizedBox(height: (widget.compact ? 12 : 16) * widget.visualScale),
          LayoutBuilder(
            builder: (context, constraints) {
              final fallbackAspectRatio = widget.compact ? 0.82 : 0.72;
              final minVisibleHeight =
                  (widget.compact ? 260.0 : 360.0) * widget.visualScale;
              final maxVisibleHeight =
                  (widget.compact ? 760.0 : 1180.0) * widget.visualScale;

              return FutureBuilder<_EmbeddedTextbookLayoutData>(
                future: _layoutFuture,
                builder: (context, snapshot) {
                  final viewportAspectRatio =
                      snapshot.data?.viewportAspectRatio ?? fallbackAspectRatio;
                  final visibleHeight =
                      (constraints.maxWidth / viewportAspectRatio).clamp(
                        minVisibleHeight,
                        maxVisibleHeight,
                      );
                  final contentHeight = visibleHeight + stageBottomInset;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: contentHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                0,
                                0,
                                0,
                                stageBottomInset,
                              ),
                              child: focusedPageImagePath != null
                                  ? _TextbookImageStage(
                                      pageImagePath: focusedPageImagePath,
                                      stageImageData:
                                          snapshot.data?.stageImageData,
                                      tasks: pageTasks,
                                      focusedTaskId: widget.focusedTaskId,
                                      onSelectTask: widget.onSelectTask,
                                    )
                                  : FutureBuilder<Uint8List?>(
                                      future: _pdfFuture,
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState !=
                                            ConnectionState.done) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }

                                        if (snapshot.hasError) {
                                          return _PdfStateMessage(
                                            title: '教材暂时打不开',
                                            message:
                                                snapshot.error?.toString() ??
                                                '请稍后重试。',
                                          );
                                        }

                                        if (!snapshot.hasData ||
                                            snapshot.data == null) {
                                          return const _PdfStateMessage(
                                            title: '这句课本内容还在准备中',
                                            message:
                                                '老师还没有把这一页教材传上来，先切到别的句子继续练习吧。',
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
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ),
                          if ((widget.activity.materialPdfPath ?? '')
                              .trim()
                              .isNotEmpty)
                            Positioned(
                              top: 16 * widget.visualScale,
                              right: 16 * widget.visualScale,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.onOpenFullScreen,
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    width: 44 * widget.visualScale,
                                    height: 44 * widget.visualScale,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.34,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.open_in_full_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 16 * widget.visualScale,
                            right: 16 * widget.visualScale,
                            bottom: 16 * widget.visualScale,
                            child: widget.bottomSheet,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmbeddedTextbookLayoutData {
  const _EmbeddedTextbookLayoutData({
    required this.viewportAspectRatio,
    this.stageImageData,
  });

  final double viewportAspectRatio;
  final _StageImageData? stageImageData;
}

class _TextbookImageStage extends StatelessWidget {
  const _TextbookImageStage({
    required this.pageImagePath,
    required this.tasks,
    required this.focusedTaskId,
    required this.onSelectTask,
    this.stageImageData,
  });

  final String pageImagePath;
  final List<PortalTask> tasks;
  final String focusedTaskId;
  final ValueChanged<String> onSelectTask;
  final _StageImageData? stageImageData;

  @override
  Widget build(BuildContext context) {
    if (stageImageData != null) {
      return _TextbookImageStageBody(
        data: stageImageData!,
        tasks: tasks,
        focusedTaskId: focusedTaskId,
        onSelectTask: onSelectTask,
      );
    }

    return FutureBuilder<_StageImageData>(
      future: _loadStageImageData(pageImagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const _PdfStateMessage(
            title: '教材页暂时打不开',
            message: '这页教材图片还没有准备好，请稍后再试，或先切换到别的句子继续练习。',
          );
        }

        return _TextbookImageStageBody(
          data: snapshot.data!,
          tasks: tasks,
          focusedTaskId: focusedTaskId,
          onSelectTask: onSelectTask,
        );
      },
    );
  }
}

class _TextbookImageStageBody extends StatelessWidget {
  const _TextbookImageStageBody({
    required this.data,
    required this.tasks,
    required this.focusedTaskId,
    required this.onSelectTask,
  });

  final _StageImageData data;
  final List<PortalTask> tasks;
  final String focusedTaskId;
  final ValueChanged<String> onSelectTask;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final imageAspect = data.width / data.height;
        final viewportAspect = maxWidth / maxHeight;
        final imageWidth = viewportAspect > imageAspect
            ? maxHeight * imageAspect
            : maxWidth;
        final imageHeight = viewportAspect > imageAspect
            ? maxHeight
            : maxWidth / imageAspect;
        final imageLeft = (maxWidth - imageWidth) / 2;
        final imageTop = (maxHeight - imageHeight) / 2;

        return Stack(
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(180),
              clipBehavior: Clip.none,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: imageLeft,
                    top: imageTop,
                    width: imageWidth,
                    height: imageHeight,
                    child: Image.memory(
                      data.bytes,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                  ),
                  for (final task in tasks)
                    if (task.region != null)
                      _TextbookRegionOverlay(
                        task: task,
                        focusedTaskId: focusedTaskId,
                        imageLeft: imageLeft,
                        imageTop: imageTop,
                        imageWidth: imageWidth,
                        imageHeight: imageHeight,
                        onSelectTask: onSelectTask,
                      ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '双指放大 · 拖动看全页',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TextbookRegionOverlay extends StatelessWidget {
  const _TextbookRegionOverlay({
    required this.task,
    required this.focusedTaskId,
    required this.imageLeft,
    required this.imageTop,
    required this.imageWidth,
    required this.imageHeight,
    required this.onSelectTask,
  });

  final PortalTask task;
  final String focusedTaskId;
  final double imageLeft;
  final double imageTop;
  final double imageWidth;
  final double imageHeight;
  final ValueChanged<String> onSelectTask;

  @override
  Widget build(BuildContext context) {
    final region = task.region!;
    final left = imageLeft + imageWidth * region.x;
    final top = imageTop + imageHeight * region.y;
    final width = imageWidth * region.width;
    final height = imageHeight * region.height;
    final isFocused = task.id == focusedTaskId;
    final isDone = task.reviewStatus == TaskReviewStatus.checked;
    final overlayColor = isFocused
        ? const Color(0x33F97316)
        : isDone
        ? const Color(0x2816A34A)
        : const Color(0x12FFFFFF);
    final borderColor = isFocused
        ? const Color(0xFFEA580C)
        : isDone
        ? const Color(0xFF16A34A)
        : const Color(0x88FFFFFF);
    final chipBackground = isFocused
        ? const Color(0xFFFFF7ED)
        : isDone
        ? const Color(0xFFEAFBF1)
        : Colors.white.withValues(alpha: 0.94);
    final chipForeground = isFocused
        ? const Color(0xFFEA580C)
        : isDone
        ? const Color(0xFF15803D)
        : const Color(0xFF1E293B);
    final statusLabel = isFocused
        ? '当前'
        : isDone
        ? '完成'
        : '待做';

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => onSelectTask(task.id),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          scale: isFocused ? 1.015 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: overlayColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: isFocused ? 3 : 2),
              boxShadow: [
                BoxShadow(
                  color:
                      (isFocused
                              ? const Color(0xFFEA580C)
                              : isDone
                              ? const Color(0xFF16A34A)
                              : Colors.black)
                          .withValues(alpha: isFocused ? 0.18 : 0.07),
                  blurRadius: isFocused ? 18 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    margin: const EdgeInsets.all(7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: chipBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: chipForeground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (isDone)
                  const Positioned(
                    right: 8,
                    bottom: 8,
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                      size: 22,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageImageData {
  const _StageImageData({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final double width;
  final double height;
}

Future<_StageImageData> _loadStageImageData(String path) async {
  final bytes = await _loadStageImageBytes(path);
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  return _StageImageData(
    bytes: bytes,
    width: image.width.toDouble(),
    height: image.height.toDouble(),
  );
}

Future<Uint8List> _loadStageImageBytes(String path) {
  if (path.startsWith('asset:')) {
    return _loadBundledAssetBytes(path.substring('asset:'.length));
  }

  final reference = _resolveStorageReference(
    path,
    defaultBucket: 'material-pages',
  );
  if (reference.bucketId == 'asset') {
    return _loadBundledAssetBytes(reference.path);
  }

  return Supabase.instance.client.storage
      .from(reference.bucketId)
      .download(reference.path);
}

class _StageLegendChip extends StatelessWidget {
  const _StageLegendChip({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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

class _TextbookFloatingPanel extends StatelessWidget {
  const _TextbookFloatingPanel({
    required this.task,
    required this.submissionFlowStatus,
    required this.submissionStatusHint,
    required this.selectedAudioLabel,
    required this.existingAudioLabel,
    required this.isSubmitting,
    required this.isRecording,
    required this.isSamplePlaying,
    required this.isSampleLoading,
    required this.isSelectedAudioPlaying,
    required this.isSelectedAudioLoading,
    required this.isStoredAudioPlaying,
    required this.isStoredAudioLoading,
    this.onOpenReading,
    this.onSpeakSample,
    this.onOpenVideo,
    this.onPickAudio,
    this.onRecordAudio,
    this.onClearSelectedAudio,
    this.onPlaySelectedAudio,
    this.onPlayStoredAudio,
    required this.onPrimaryAction,
  });

  final PortalTask task;
  final SubmissionFlowStatus submissionFlowStatus;
  final String? submissionStatusHint;
  final String? selectedAudioLabel;
  final String? existingAudioLabel;
  final bool isSubmitting;
  final bool isRecording;
  final bool isSamplePlaying;
  final bool isSampleLoading;
  final bool isSelectedAudioPlaying;
  final bool isSelectedAudioLoading;
  final bool isStoredAudioPlaying;
  final bool isStoredAudioLoading;
  final VoidCallback? onOpenReading;
  final VoidCallback? onSpeakSample;
  final VoidCallback? onOpenVideo;
  final VoidCallback? onPickAudio;
  final VoidCallback? onRecordAudio;
  final VoidCallback? onClearSelectedAudio;
  final VoidCallback? onPlaySelectedAudio;
  final VoidCallback? onPlayStoredAudio;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final sampleText = _sampleTextFor(task);
    final pageLabel = _pageRangeLabel(task);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 760;
          final header = isPhone
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color(0xFF1E293B),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        if (task.hasPageRange)
                          _TaskInfoChip(
                            icon: Icons.menu_book_rounded,
                            label: pageLabel,
                            onTap: onOpenReading,
                            iconOnly: true,
                          ),
                      ],
                    ),
                    if (sampleText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        sampleText,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF334155),
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color(0xFF1E293B),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          if (sampleText != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              sampleText,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF334155),
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (task.hasPageRange)
                      _TaskInfoChip(
                        icon: Icons.menu_book_rounded,
                        label: pageLabel,
                        onTap: onOpenReading,
                        iconOnly: true,
                      ),
                  ],
                );

          final actionChips = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TaskInfoChip(
                icon: isSamplePlaying
                    ? Icons.pause_circle_filled_rounded
                    : task.hasReferenceAudio
                    ? Icons.audiotrack_rounded
                    : Icons.volume_up_rounded,
                label: isSampleLoading
                    ? '加载中'
                    : isSamplePlaying
                    ? '停止'
                    : '示范',
                onTap: onSpeakSample,
                iconOnly: true,
              ),
              if (task.hasTeachingVideo)
                _TaskInfoChip(
                  icon: Icons.smart_display_rounded,
                  label: '视频',
                  onTap: onOpenVideo,
                  iconOnly: true,
                ),
              if (selectedAudioLabel != null)
                _TaskInfoChip(
                  icon: isSelectedAudioPlaying
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_outline_rounded,
                  label: isSelectedAudioLoading
                      ? '加载中'
                      : isSelectedAudioPlaying
                      ? '停止'
                      : '试听',
                  onTap: onPlaySelectedAudio,
                  iconOnly: true,
                ),
              if (existingAudioLabel != null &&
                  submissionFlowStatus != SubmissionFlowStatus.notStarted)
                _TaskInfoChip(
                  icon: isStoredAudioPlaying
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_outline_rounded,
                  label: isStoredAudioLoading
                      ? '加载中'
                      : isStoredAudioPlaying
                      ? '停止'
                      : '回听',
                  onTap: onPlayStoredAudio,
                  iconOnly: true,
                ),
              if (selectedAudioLabel != null && onClearSelectedAudio != null)
                _TaskInfoChip(
                  icon: Icons.delete_outline_rounded,
                  label: '删除',
                  onTap: onClearSelectedAudio,
                  iconOnly: true,
                ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 12),
              actionChips,
              const SizedBox(height: 14),
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
                onPlaySelectedAudio: null,
                onPlayStoredAudio: null,
                onPrimaryAction: onPrimaryAction,
                compact: true,
              ),
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
              : _RoundOutlineIconButton(
                  onPressed: onAction,
                  tooltip: isLoading ? '加载中' : (isPlaying ? '停止播放' : '播放录音'),
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
                          color: const Color(0xFF0F766E),
                        ),
                );
          final deleteAction = onDelete == null
              ? null
              : _RoundOutlineIconButton(
                  onPressed: onDelete,
                  tooltip: '删除录音',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626),
                  ),
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

class _TeachingVideoDialog extends StatefulWidget {
  const _TeachingVideoDialog({
    required this.title,
    required this.rawReference,
    required this.onResolveStoragePath,
  });

  final String title;
  final String rawReference;
  final Future<String> Function(String reference) onResolveStoragePath;

  @override
  State<_TeachingVideoDialog> createState() => _TeachingVideoDialogState();
}

class _TeachingVideoDialogState extends State<_TeachingVideoDialog> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prepareController();
  }

  Future<void> _prepareController() async {
    try {
      final controller = await _buildController();
      _controller = controller;
      _initializeFuture = controller.initialize().then((_) async {
        await controller.setLooping(true);
      });
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      _errorMessage = '这段动画暂时打不开，请稍后再试。';
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<VideoPlayerController> _buildController() async {
    if (widget.rawReference.startsWith('asset:')) {
      return VideoPlayerController.asset(
        _normalizeBundledAssetPath(
          widget.rawReference.substring('asset:'.length),
        ),
      );
    }

    final path = await widget.onResolveStoragePath(widget.rawReference);
    return VideoPlayerController.file(File(path));
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.title} · 配套动画',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              _PdfStateMessage(title: '动画暂时打不开', message: _errorMessage!)
            else if (_initializeFuture == null || _controller == null)
              const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              FutureBuilder<void>(
                future: _initializeFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 260,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return const _PdfStateMessage(
                      title: '动画暂时打不开',
                      message: '这段动画还没有准备好，请稍后再试。',
                    );
                  }
                  final controller = _controller!;
                  return AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0
                        ? 16 / 9
                        : controller.value.aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF112331),
                                  Color(0xFF1E293B),
                                  Color(0xFF0F172A),
                                ],
                              ),
                            ),
                            child: VideoPlayer(controller),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _togglePlayback,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                color: controller.value.isPlaying
                                    ? Colors.black.withValues(alpha: 0.02)
                                    : Colors.black.withValues(alpha: 0.14),
                                child: Center(
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 180),
                                    scale: controller.value.isPlaying ? 0.9 : 1,
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      opacity: controller.value.isPlaying
                                          ? 0
                                          : 1,
                                      child: Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.18,
                                              ),
                                              blurRadius: 24,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 56,
                                          color: Color(0xFFFF8F4D),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 14,
                            bottom: 14,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: controller.value.isPlaying ? 1 : 0.84,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.46),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Icon(
                                    controller.value.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
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
        ? '生成中'
        : isEncouragementPlaying
        ? '停止'
        : 'AI';
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
                  label: '老师已看',
                  color: Color(0xFF0369A1),
                  background: Color(0xFFE0F2FE),
                ),
              _ReviewBadge(
                icon: Icons.star_rounded,
                label: '$scoreLabel 分',
                color: const Color(0xFFF97316),
                background: const Color(0xFFFFEBD9),
              ),
              if (review.pronunciationScore != null)
                _ReviewMetricChip(
                  label: '发音 ${review.pronunciationScore!.toStringAsFixed(0)}',
                ),
              if (review.fluencyScore != null)
                _ReviewMetricChip(
                  label: '流利 ${review.fluencyScore!.toStringAsFixed(0)}',
                ),
              if (review.completenessScore != null)
                _ReviewMetricChip(
                  label: '完整 ${review.completenessScore!.toStringAsFixed(0)}',
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
                title: '读得好',
                icon: Icons.thumb_up_alt_rounded,
                background: const Color(0xFFEAFBF1),
                foreground: const Color(0xFF0F8B6D),
                items: review.strengths.isEmpty
                    ? const ['愿意开口读。']
                    : review.strengths,
              );
              final improvementCard = _ReviewListCard(
                title: '再练练',
                icon: Icons.flag_rounded,
                background: const Color(0xFFFFF4E8),
                foreground: const Color(0xFFB45309),
                items: review.improvementPoints.isEmpty
                    ? const ['再跟示范读一遍。']
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
    this.onOpenVideo,
    this.onPickAudio,
    this.onRecordAudio,
    this.onClearSelectedAudio,
    this.onPlaySelectedAudio,
    this.onPlayStoredAudio,
    this.onPlayEncouragement,
    required this.onPrimaryAction,
    this.isFocusTask = false,
    this.showSubmissionSection = true,
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
  final VoidCallback? onOpenVideo;
  final VoidCallback? onPickAudio;
  final VoidCallback? onRecordAudio;
  final VoidCallback? onPlaySelectedAudio;
  final VoidCallback? onPlayStoredAudio;
  final VoidCallback? onPlayEncouragement;
  final VoidCallback? onClearSelectedAudio;
  final VoidCallback onPrimaryAction;
  final bool isFocusTask;
  final bool showSubmissionSection;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(task.reviewStatus);
    final statusColor = _statusColor(task.reviewStatus);
    final sampleText = _sampleTextFor(task);
    final samplePreviewLabel = isSampleLoading
        ? '示范加载中'
        : isSamplePlaying
        ? '停止示范'
        : '播放示范';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 720;
          final preview = Tooltip(
            message: samplePreviewLabel,
            child: Material(
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
                  child: Center(
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
              if ((task.promptText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  task.promptText!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ],
              if (sampleText != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    sampleText,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
                      iconOnly: true,
                    ),
                  if (sampleText != null)
                    _TaskInfoChip(
                      icon: isSamplePlaying
                          ? Icons.pause_circle_filled_rounded
                          : task.hasReferenceAudio
                          ? Icons.audiotrack_rounded
                          : Icons.volume_up_rounded,
                      label: task.hasReferenceAudio
                          ? (isSamplePlaying ? '停止示范' : '示范')
                          : (isSpeaking ? '停止示范' : '示范'),
                      onTap: onSpeakSample,
                      iconOnly: true,
                    ),
                  if (task.hasTeachingVideo)
                    _TaskInfoChip(
                      icon: Icons.smart_display_rounded,
                      label: '动画',
                      onTap: onOpenVideo,
                      iconOnly: true,
                    ),
                ],
              ),
              if (showSubmissionSection) ...[
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
        return '已点评';
      case TaskReviewStatus.pendingReview:
        return '等待点评';
      case TaskReviewStatus.inProgress:
        return '去完成';
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
    this.compact = false,
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
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (submissionFlowStatus) {
      SubmissionFlowStatus.notStarted => isRecording ? '录音中' : '未提交',
      SubmissionFlowStatus.queued => '已提交',
      SubmissionFlowStatus.processing => '评分中',
      SubmissionFlowStatus.failed => isRecording ? '录音中' : '重试',
      SubmissionFlowStatus.completed => '已点评',
    };
    final statusColor = switch (submissionFlowStatus) {
      SubmissionFlowStatus.notStarted => const Color(0xFF2563EB),
      SubmissionFlowStatus.queued => const Color(0xFFF97316),
      SubmissionFlowStatus.processing => const Color(0xFFFF8F4D),
      SubmissionFlowStatus.failed => const Color(0xFFDC2626),
      SubmissionFlowStatus.completed => const Color(0xFF16A34A),
    };
    final subtitle = switch (submissionFlowStatus) {
      SubmissionFlowStatus.notStarted => '',
      SubmissionFlowStatus.queued => '',
      SubmissionFlowStatus.processing => '',
      SubmissionFlowStatus.failed => '',
      SubmissionFlowStatus.completed => '',
    };
    final canSubmit =
        submissionFlowStatus == SubmissionFlowStatus.notStarted ||
        submissionFlowStatus == SubmissionFlowStatus.failed ||
        submissionFlowStatus == SubmissionFlowStatus.completed;
    final hasSelectedAudio = (selectedAudioLabel ?? '').trim().isNotEmpty;
    final primaryLabel = isRecording
        ? (compact ? '停止' : '结束录音')
        : hasSelectedAudio
        ? (isSubmitting
              ? (submissionFlowStatus == SubmissionFlowStatus.failed
                    ? '重交中'
                    : submissionFlowStatus == SubmissionFlowStatus.completed
                    ? '再交中'
                    : '提交中')
              : (submissionFlowStatus == SubmissionFlowStatus.failed
                    ? (compact ? '重交' : '重新提交')
                    : submissionFlowStatus == SubmissionFlowStatus.completed
                    ? (compact ? '再交' : '再次提交')
                    : (compact ? '提交' : '提交这一句')))
        : (compact ? '录音' : '开始录音');
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
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: compact ? const Color(0xFFF7FAF8) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
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
              if (!compact && subtitle.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (selectedAudioLabel != null) ...[
            const SizedBox(height: 12),
            _AudioInfoCard(
              title: '待提交',
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
              title: '已提交',
              fileName: existingAudioLabel!,
              onAction: onPlayStoredAudio,
              isPlaying: isStoredAudioPlaying,
              isLoading: isStoredAudioLoading,
            ),
          ],
          const SizedBox(height: 14),
          if (compact)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: primaryAction,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
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
                ),
              ],
            )
          else ...[
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
                child: _RoundOutlineIconButton(
                  onPressed: isSubmitting ? null : onClearSelectedAudio,
                  tooltip: '删除这段音频',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TaskInfoChip extends StatelessWidget {
  const _TaskInfoChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconOnly = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final chipColor = onTap == null
        ? const Color(0xFFF8FAFC)
        : const Color(0xFFEAFBF1);
    final borderColor = onTap == null ? null : const Color(0xFFD6F2E2);

    if (iconOnly) {
      final chip = Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(14),
          border: borderColor == null ? null : Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF2FA77D)),
      );

      final wrapped = Tooltip(message: label, child: chip);
      if (onTap == null) {
        return wrapped;
      }

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: wrapped,
        ),
      );
    }

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(14),
        border: borderColor == null ? null : Border.all(color: borderColor),
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
    final size = MediaQuery.sizeOf(context);
    final iconOnly = size.width > size.height && size.height < 640;
    final isTightLandscapePhone = size.width > size.height && size.height < 430;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly
                ? (isTightLandscapePhone ? 10 : 12)
                : (isTightLandscapePhone ? 12 : 16),
            vertical: isTightLandscapePhone ? 9 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: isTightLandscapePhone ? 16 : 18,
              ),
              if (!iconOnly) ...[
                SizedBox(width: isTightLandscapePhone ? 6 : 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: isTightLandscapePhone ? 13 : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundOutlineIconButton extends StatelessWidget {
  const _RoundOutlineIconButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(42, 42),
          maximumSize: const Size(42, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: icon,
      ),
    );
  }
}

double _taskDetailLandscapeVisualScale(double maxWidth, double maxHeight) {
  final heightScale = (maxHeight / 430).clamp(0.8, 1.0);
  final widthScale = (maxWidth / 960).clamp(0.9, 1.0);
  return (heightScale * widthScale).clamp(0.8, 1.0);
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

Future<Uint8List> _loadBundledAssetBytes(String assetPath) async {
  final trimmedPath = assetPath.trim();
  final candidates = <String>{
    trimmedPath,
    _normalizeBundledAssetPath(trimmedPath),
  };
  Object? lastError;

  for (final candidate in candidates) {
    if (candidate.isEmpty) {
      continue;
    }
    try {
      final bytes = await rootBundle.load(candidate);
      return bytes.buffer.asUint8List();
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError ?? FlutterError('Unable to load asset: "$trimmedPath".');
}

String _normalizeBundledAssetPath(String rawPath) {
  final trimmed = rawPath.trim();
  if (trimmed.startsWith('assets/textbook/')) {
    return 'assets/textbooks/${trimmed.substring('assets/textbook/'.length)}';
  }
  return trimmed;
}

_StorageAudioReference _resolveStorageReference(
  String rawReference, {
  required String defaultBucket,
}) {
  final trimmed = rawReference.trim();
  if (trimmed.startsWith('assets/')) {
    return _StorageAudioReference(
      bucketId: 'asset',
      path: _normalizeBundledAssetPath(trimmed),
    );
  }
  if (trimmed.contains(':')) {
    final index = trimmed.indexOf(':');
    final bucketId = trimmed.substring(0, index).trim();
    var path = trimmed.substring(index + 1).trim();
    if (bucketId == 'asset') {
      path = _normalizeBundledAssetPath(path);
    }
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
