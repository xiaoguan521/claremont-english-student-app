import 'dart:io';

const _pageRoots = [
  'lib/features/home/presentation/pages',
  'lib/features/portal/presentation/pages',
  'lib/features/settings/presentation/pages',
  'lib/features/student/presentation/pages',
];

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
      if (_allowedFiles.contains(normalized)) {
        continue;
      }
      final content = entity.readAsStringSync();
      if (_hardcodedColorPattern.hasMatch(content)) {
        violations.add('$normalized uses hardcoded Color(0x...).');
      }
      if (_magicSizedBoxPattern.hasMatch(content)) {
        violations.add('$normalized uses literal SizedBox dimensions.');
      }
      if (_magicClampPattern.hasMatch(content)) {
        violations.add('$normalized uses literal clamp dimensions.');
      }
    }
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
