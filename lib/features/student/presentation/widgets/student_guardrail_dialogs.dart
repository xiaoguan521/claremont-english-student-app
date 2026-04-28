import 'package:flutter/material.dart';

class StudentExitPracticeDialog extends StatelessWidget {
  const StudentExitPracticeDialog({super.key, required this.isRecording});

  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      icon: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4CC),
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Icon(
          Icons.sentiment_satisfied_alt_rounded,
          color: Color(0xFFFF8F4D),
          size: 38,
        ),
      ),
      title: const Text('先离开这次练习吗？'),
      content: Text(
        isRecording ? '现在正在录音，离开前我们会先帮你结束并保存这段录音。' : '当前进度已经在本地保存，下次回来可以继续完成。',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('继续练习'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('保存并离开'),
        ),
      ],
    );
  }
}
