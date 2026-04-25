import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_starter/features/portal/data/portal_models.dart';
import 'package:flutter_starter/features/portal/data/practice_protocol_models.dart';

void main() {
  test('dubbing task with enough tokens becomes word bank protocol', () {
    const task = PortalTask(
      id: 'task-1',
      title: 'Make a sentence',
      kind: TaskKind.dubbing,
      reviewStatus: TaskReviewStatus.inProgress,
      previewAsset: 'preview.png',
      promptText: 'Arrange the words',
      ttsText: 'I like English class',
    );

    final protocol = task.toPracticeProtocol();

    expect(protocol.type, PracticeTaskType.wordBank);
    expect(
      protocol.content['expectedTokens'],
      equals(<String>['I', 'like', 'English', 'class']),
    );
  });

  test('phonics task becomes listen and choose protocol', () {
    const task = PortalTask(
      id: 'task-2',
      title: 'Pick the sound',
      kind: TaskKind.phonics,
      reviewStatus: TaskReviewStatus.inProgress,
      previewAsset: 'preview.png',
      promptText: 'Choose the right sound',
      ttsText: 'cat, cap, can',
    );

    final protocol = task.toPracticeProtocol();

    expect(protocol.type, PracticeTaskType.listenAndChoose);
    expect(protocol.content['correctOption'], 'cat');
    expect(protocol.content['options'], containsAll(<String>['cat', 'cap']));
  });

  test('task with region becomes hotspot protocol', () {
    const task = PortalTask(
      id: 'task-3',
      title: 'Tap the apple',
      kind: TaskKind.recording,
      reviewStatus: TaskReviewStatus.inProgress,
      previewAsset: 'preview.png',
      promptText: 'Tap the apple',
      region: PortalTaskRegion(
        id: 'region-1',
        pageNumber: 4,
        pageImagePath: 'assets/textbooks/page-4.png',
        x: 0.1,
        y: 0.2,
        width: 0.3,
        height: 0.2,
      ),
    );

    final protocol = task.toPracticeProtocol();

    expect(protocol.type, PracticeTaskType.hotspotSelect);
    expect(protocol.content['pageNumber'], 4);
  });

  test('protocol from map falls back to unsupported type', () {
    final protocol = PracticeTaskProtocol.fromMap(<String, Object?>{
      'id': 'future-task',
      'type': 'future_mode',
      'version': 1,
      'prompt': 'Future task',
    });

    expect(protocol.type, PracticeTaskType.unsupported);
  });
}
