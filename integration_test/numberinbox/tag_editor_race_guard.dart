import 'dart:async';

/// True for one known debug-only assertion from the recipient tag editor.
///
/// `super_tag_editor` starts a debounced suggestion search on every text change
/// and never cancels it when the editor is disposed. Closing the composer within
/// the debounce window of a field change therefore ends with
/// `ValueNotifier ... was used after being disposed`. Debug builds assert on it;
/// release builds do not. It is inherited behaviour, so the fork leaves the
/// package alone.
bool isTagEditorDisposedNotifier(Object error, StackTrace? stack) =>
    error.toString().contains('was used after being disposed') &&
    (stack?.toString().contains('package:super_tag_editor/') ?? false);

/// Runs [body] in its own error zone and drops only that assertion.
///
/// The late search timer is created by code the test drives, so it belongs to this
/// zone and its error reaches the handler below before the test binding sees it.
/// Every other error, including failures thrown by [body] itself, still fails the
/// test. Use it only in a test that closes the composer right after typing.
Future<void> ignoringTagEditorDisposedNotifier(Future<void> Function() body) {
  final finished = Completer<void>();
  runZonedGuarded(
    () async {
      try {
        await body();
        if (!finished.isCompleted) finished.complete();
      } catch (error, stack) {
        if (!finished.isCompleted) finished.completeError(error, stack);
      }
    },
    (error, stack) {
      if (isTagEditorDisposedNotifier(error, stack)) return;
      if (!finished.isCompleted) {
        finished.completeError(error, stack);
      } else {
        // The body is over: hand the error to the surrounding zone unchanged.
        Zone.current.handleUncaughtError(error, stack);
      }
    },
  );
  return finished.future;
}
