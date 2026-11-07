import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/numberinbox/tag_editor_race_guard.dart';

const _disposedMessage =
    'A ValueNotifier<String?> was used after being disposed.';
final _tagEditorStack = StackTrace.fromString(
  '#4      TagsEditorState._updateValidationSuggestionItem '
  '(package:super_tag_editor/tag_editor.dart:355:39)\n',
);

/// Delivers [error] to the zone it is scheduled from, as an uncaught async error.
void _raiseLater(Object error, StackTrace stack) {
  final zone = Zone.current;
  scheduleMicrotask(() => zone.handleUncaughtError(error, stack));
}

void main() {
  group('isTagEditorDisposedNotifier', () {
    test(
      'matches the disposed-notifier assertion raised inside super_tag_editor',
      () {
        expect(
          isTagEditorDisposedNotifier(
            FlutterError(_disposedMessage),
            _tagEditorStack,
          ),
          isTrue,
        );
      },
    );

    test('ignores the same assertion raised anywhere else', () {
      final elsewhere = StackTrace.fromString(
        '#0 Composer.dispose (package:tmail_ui_user/x.dart:1:1)',
      );
      expect(
        isTagEditorDisposedNotifier(FlutterError(_disposedMessage), elsewhere),
        isFalse,
      );
    });

    test('ignores other errors raised inside super_tag_editor', () {
      expect(
        isTagEditorDisposedNotifier(
          StateError('something else'),
          _tagEditorStack,
        ),
        isFalse,
      );
    });
  });

  group('ignoringTagEditorDisposedNotifier', () {
    test('lets the body finish when the late assertion arrives', () async {
      await ignoringTagEditorDisposedNotifier(() async {
        _raiseLater(FlutterError(_disposedMessage), _tagEditorStack);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
    });

    test('still fails on any other uncaught error', () async {
      await expectLater(
        ignoringTagEditorDisposedNotifier(() async {
          _raiseLater(StateError('unrelated'), _tagEditorStack);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('still fails when the body itself throws', () async {
      await expectLater(
        ignoringTagEditorDisposedNotifier(
          () async => throw TestFailure('expectation failed'),
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
