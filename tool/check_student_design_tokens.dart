import 'dart:io';

const _pageRoots = [
  'lib/features/home/presentation/pages',
  'lib/features/portal/presentation/pages',
  'lib/features/settings/presentation/pages',
  'lib/features/student/presentation/pages',
];

const _strictWidgetFiles = {
  'lib/features/portal/presentation/widgets/audio_record_button.dart',
  'lib/features/portal/presentation/widgets/practice_control_dock.dart',
  'lib/features/portal/presentation/widgets/practice_submission_dock.dart',
  'lib/features/portal/presentation/widgets/practice_stages/practice_stage_scaffold.dart',
};

const _allowedFiles = {
  // Legacy pages still contain historical magic values. Keep this baseline
  // explicit so new student-facing pages do not accidentally copy the pattern.
  'lib/features/home/presentation/pages/home_page.dart',
  'lib/features/home/presentation/pages/error_showcase_page.dart',
  'lib/features/home/presentation/pages/file_upload_showcase_page.dart',
  'lib/features/home/presentation/pages/language_showcase_page.dart',
  'lib/features/home/presentation/pages/skeleton_showcase_page.dart',
  'lib/features/home/presentation/pages/ui_showcase_page.dart',
  'lib/features/portal/presentation/pages/task_detail_page.dart',
  'lib/features/portal/presentation/pages/activities_page.dart',
  'lib/features/portal/presentation/pages/explore_page.dart',
  'lib/features/portal/presentation/pages/parent_contact_page.dart',
  'lib/features/portal/presentation/pages/reading_page.dart',
  'lib/features/portal/presentation/pages/review_detail_page.dart',
  'lib/features/portal/presentation/pages/student_release_lab_page.dart',
  'lib/features/student/presentation/pages/student_identity_selection_page.dart',
};

final _hardcodedColorPattern = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
final _magicSizedBoxPattern = RegExp(
  r'SizedBox\((?:width|height):\s*(?!AppUiTokens)[0-9]+(?:\.[0-9]+)?',
);
final _magicClampPattern = RegExp(
  r'\.clamp\(\s*(?!AppUiTokens)[0-9]+(?:\.[0-9]+)?',
);

void main() {
  final violations = <String>[];
  final scannedFiles = <String>{};
  for (final root in _pageRoots) {
    final directory = Directory(root);
    if (!directory.existsSync()) {
      continue;
    }
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final normalized = entity.path.replaceAll('\\', '/');
      scannedFiles.add(normalized);
      if (_allowedFiles.contains(normalized)) {
        continue;
      }
      _collectViolations(entity, normalized, violations);
    }
  }
  for (final path in _strictWidgetFiles) {
    if (scannedFiles.contains(path)) {
      continue;
    }
    final file = File(path);
    if (!file.existsSync()) {
      violations.add('$path is listed for strict token checks but is missing.');
      continue;
    }
    _collectViolations(file, path, violations);
  }

  if (violations.isEmpty) {
    stdout.writeln('Student design token guard passed.');
    return;
  }

  stderr.writeln('Student design token guard failed:');
  for (final violation in violations) {
    stderr.writeln('- $violation');
  }
  stderr.writeln(
    'Move student-facing colors/sizes to AppUiTokens or shared components.',
  );
  exitCode = 1;
}

void _collectViolations(File file, String normalized, List<String> violations) {
  final content = file.readAsStringSync();
  if (_hardcodedColorPattern.hasMatch(content)) {
    violations.add('$normalized uses hardcoded Color(0x...).');
  }
  if (_magicSizedBoxPattern.hasMatch(content)) {
    violations.add('$normalized uses literal SizedBox dimensions.');
  }
  final hasDimensionClamp = _magicClampPattern.allMatches(content).any((match) {
    final expression = match.group(0) ?? '';
    return !expression.contains('.clamp(0.0') &&
        !expression.contains('.clamp(0,');
  });
  if (hasDimensionClamp) {
    violations.add('$normalized uses literal clamp dimensions.');
  }
}
