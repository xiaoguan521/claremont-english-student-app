import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/portal_models.dart';

class ReadingPage extends StatefulWidget {
  const ReadingPage({required this.activity, this.task, super.key});

  final PortalActivity activity;
  final PortalTask? task;

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  late final PdfViewerController _pdfController;
  late final Future<Uint8List?> _pdfFuture;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _pdfFuture = _loadPdfBytes();
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

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final pageRangeLabel = _pageRangeLabel(task);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        title: Text(widget.activity.materialTitle ?? widget.activity.title),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2F67F6), Color(0xFF69C8FF)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  task?.title ?? widget.activity.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (pageRangeLabel != null)
                  _InfoChip(
                    icon: Icons.menu_book_rounded,
                    label: pageRangeLabel,
                  ),
                if ((widget.activity.materialPageCount ?? 0) > 0)
                  _InfoChip(
                    icon: Icons.picture_as_pdf_rounded,
                    label: '共 ${widget.activity.materialPageCount} 页',
                  ),
                if ((task?.promptText ?? '').trim().isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      task!.promptText!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Material(
                  color: Colors.white,
                  child: FutureBuilder<Uint8List?>(
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

                      return SfPdfViewer.memory(
                        snapshot.data!,
                        controller: _pdfController,
                        canShowPaginationDialog: true,
                        onDocumentLoaded: (_) {
                          final startPage = task?.startPage;
                          if (startPage != null && startPage > 0) {
                            _pdfController.jumpToPage(startPage);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
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
