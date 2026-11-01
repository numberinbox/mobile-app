# NumberInbox device tests

These parameterized Dart tests belong to the app fork. Private CI supplies the
disposable test-stack configuration; no production service or reviewer account is
encoded here.

The runner selects these exact targets in order:

1. `numberinbox_login_test.dart`: a cleared installation, wrong-code refusal,
   ordinary OTP login, reading seeded mail and opening the composer.
2. `numberinbox_relaunch_test.dart`: a force-stop and relaunch with application
   data preserved; no new phone or OTP prompt may appear.
3. `numberinbox_deletion_test.dart`: a separate account, seeded mail, deletion,
   recreation and an empty mailbox.

Inputs are supplied as dart-defines: `OTP_HELPER_URL` is the disposable OTP
provider's loopback URL, and `SMOKE_TEST_NUMBER` is the disposable number for that
stage. The current picker flow uses Thailand, so the runner supplies a valid
`+66` number. API and JMAP origins use the app's normal configuration inputs.
The runner seeds a message with the subject `Smoke seeded message` before login
and deletion stages. Test steps and captured diagnostics must be kept private and
redacted because they can contain values entered into fields.

Run explicit files; do not glob this folder or add the inherited suite's Android
tag filter to these targets. `store_capture/` is a separate screenshot helper
using `IntegrationTestWidgetsFlutterBinding`, not a Patrol regression target.
Its capture scripts and runtime-input instructions are under `docs/store/`.
