import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/portal_models.dart';

class ReadingPage extends StatefulWidget {
  const ReadingPage({
    required this.activity,
    this.task,
    this.startFullscreen = false,
    super.key,
  });

  final PortalActivity activity;
  final PortalTask? task;
  final bool startFullscreen;

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> with WidgetsBindingObserver {
  late final PdfViewerController _pdfController;
  late final Future<Uint8List?> _pdfFuture;
  late bool _isFullscreen;
  int _currentPageNumber = 1;
  bool _documentReady = false;
  bool _prefersPortrait = false;
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pdfController = PdfViewerController();
    _pdfFuture = _loadPdfBytes();
    _isFullscreen = widget.startFullscreen;
    _currentPageNumber = widget.task?.startPage ?? 1;
    _prepareReaderWindow();
  }

  Future<Uint8List?> _loadPdfBytes() async {
    final pdfPath = widget.activity.materialPdfPath;
    if (pdfPath == null || pdfPath.trim().isEmpty) {
      return null;
    }

    if (pdfPath.startsWith('asset:')) {
      final bytes = await rootBundle.load(pdfPath.substring('asset:'.length));
      return bytes.buffer.asUint8List();
    }

    return Supabase.instance.client.storage.from('materials').download(pdfPath);
  }

  Future<void> _prepareReaderWindow() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await _applySystemUiMode();
  }

  Future<void> _applyDocumentOrientation(bool prefersPortrait) async {
    await SystemChrome.setPreferredOrientations(
      prefersPortrait
          ? const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
          : const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
    );
  }

  Future<void> _applySystemUiMode() {
    return SystemChrome.setEnabledSystemUIMode(
      _isFullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  void _fitCurrentPage() {
    if (!_documentReady || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_documentReady || _pdfController.pageCount == 0) {
        return;
      }

      final page = _currentPageNumber.clamp(1, _pdfController.pageCount);
      _pdfController.jumpToPage(page);
      _pdfController.zoomLevel = 1;
    });
  }

  Future<void> _toggleFullscreen() async {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    await _applySystemUiMode();
  }

  void _zoomIn() {
    final nextZoom = (_pdfController.zoomLevel + 0.35).clamp(1.0, 4.5);
    _pdfController.zoomLevel = nextZoom;
  }

  void _zoomOut() {
    final nextZoom = (_pdfController.zoomLevel - 0.35).clamp(1.0, 4.5);
    _pdfController.zoomLevel = nextZoom;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _fitCurrentPage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final pageRangeLabel = _pageRangeLabel(task);
    final title = widget.activity.materialTitle ?? widget.activity.title;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: FutureBuilder<Uint8List?>(
        future: _pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _PdfStateMessage(
              title: '教材暂时打不开',
              message: snapshot.error?.toString() ?? '请稍后重试。',
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const _PdfStateMessage(
              title: '这份教材还在准备中',
              message: '老师还没有上传这一页的教材，先去完成别的任务吧。',
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final orientation = constraints.maxWidth > constraints.maxHeight
                  ? Orientation.landscape
                  : Orientation.portrait;
              if (_lastOrientation != orientation) {
                _lastOrientation = orientation;
                _fitCurrentPage();
              }

              return Stack(
                children: [
                  Positioned.fill(
                    child: SfPdfViewer.memory(
                      snapshot.data!,
                      controller: _pdfController,
                      canShowPaginationDialog: true,
                      canShowScrollHead: !_isFullscreen,
                      canShowScrollStatus: false,
                      enableDoubleTapZooming: true,
                      maxZoomLevel: 4.5,
                      pageSpacing: _isFullscreen ? 6 : 12,
                      pageLayoutMode: _prefersPortrait
                          ? PdfPageLayoutMode.single
                          : PdfPageLayoutMode.continuous,
                      scrollDirection: _prefersPortrait
                          ? PdfScrollDirection.horizontal
                          : PdfScrollDirection.vertical,
                      onZoomLevelChanged: (_) {
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      onPageChanged: (details) {
                        if (mounted) {
                          setState(() {
                            _currentPageNumber = details.newPageNumber;
                          });
                        }
                      },
                      onDocumentLoaded: (details) async {
                        _documentReady = true;
                        final pageCount = details.document.pages.count;
                        final startPage = (task?.startPage ?? 1).clamp(
                          1,
                          pageCount == 0 ? 1 : pageCount,
                        );
                        _currentPageNumber = startPage;
                        final pageSize =
                            details.document.pages[startPage - 1].size;
                        final prefersPortrait =
                            pageSize.height >= pageSize.width;

                        await _applyDocumentOrientation(prefersPortrait);
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _prefersPortrait = prefersPortrait;
                        });
                        _fitCurrentPage();
                      },
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          _ReaderIconButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          if (!_isFullscreen) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    if (pageRangeLabel != null)
                                      Text(
                                        pageRangeLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.84,
                                              ),
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ] else
                            const Spacer(),
                          const SizedBox(width: 12),
                          _ReaderIconButton(
                            icon: _prefersPortrait
                                ? Icons.stay_current_portrait_rounded
                                : Icons.stay_current_landscape_rounded,
                            onTap: null,
                            active: true,
                          ),
                          const SizedBox(width: 8),
                          _ReaderIconButton(
                            icon: Icons.fit_screen_rounded,
                            onTap: _fitCurrentPage,
                          ),
                          const SizedBox(width: 8),
                          _ReaderIconButton(
                            icon: Icons.remove_rounded,
                            onTap: _zoomOut,
                          ),
                          const SizedBox(width: 8),
                          _ReaderIconButton(
                            icon: Icons.add_rounded,
                            onTap: _zoomIn,
                          ),
                          const SizedBox(width: 8),
                          _ReaderIconButton(
                            icon: _isFullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            onTap: _toggleFullscreen,
                            active: _isFullscreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: SafeArea(
                      top: false,
                      left: false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$_currentPageNumber/${_pdfController.pageCount == 0 ? widget.activity.materialPageCount ?? 1 : _pdfController.pageCount}'
                          '  ·  ${(100 * _pdfController.zoomLevel).round()}%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String? _pageRangeLabel(PortalTask? task) {
    if (task == null || !task.hasPageRange) {
      return null;
    }

    final start = task.startPage;
    final end = task.endPage;
    if (start != null && end != null && start != end) {
      return '阅读第 $start - $end 页';
    }
    final target = start ?? end;
    return target == null ? null : '阅读第 $target 页';
  }
}

class _ReaderIconButton extends StatelessWidget {
  const _ReaderIconButton({
    required this.icon,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFFF8F4D)
            : Colors.black.withValues(alpha: 0.28),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: active ? 0.08 : 0.14),
        ),
      ),
      child: Icon(
        icon,
        size: 22,
        color: onTap == null
            ? Colors.white.withValues(alpha: 0.72)
            : Colors.white,
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: child,
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
