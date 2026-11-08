# ADR 0126: Native JMAP push without the ticket capability

Date: 2026-11-08. Status: implemented for review; device checks pending.

Upstream's `BaseController.injectWebSocket` requires the account-level WebSocket
capability and the Linagora ticket capability (`com:linagora:params:jmap:ws:ticket`).
Stalwart advertises neither the ticket nor an account-level WebSocket entry, so the
app never opened a push connection even though the datasource already supports a
ticket-less connection with the user's Basic credentials. This is an intentional
NumberInbox server-compatibility divergence, not an upstream sync.

## Decision

A NumberInbox-owned `Session` extension (`canStartWebSocketPush`) replaces the
inherited gate. Push starts when all of these hold:

- the selected account exists in the session;
- WebSocket push is supported, resolved with the datasource's precedence: an
  explicit account `supportsPush` wins; when the account omits it (including an
  empty account capability) the global capability is used;
- either the account supports the ticket capability (existing ticket flow,
  unchanged), or the platform is not web and Basic credentials are held.

OIDC without a ticket and browser Basic without a ticket stay unavailable, as
upstream, so they never loop on 401. Unknown accounts are refused without throwing.

`BaseController` changes only its gate and one import. Binding registration,
controller initialization, logging and the exception boundary are unchanged. No
datasource, WebSocket controller, authentication, FCM, dependency, reconnect, TLS
or plaintext-socket change.

## Observed server shape

Stalwart v0.16.26 (2026-11-08): the global capabilities contain the WebSocket
`url` (`/jmap/ws`) and `supportsPush: true`; the account contains an empty
WebSocket capability; no ticket capability anywhere. The test fixture
(`test/fixtures/web_socket_session_fixtures.dart`) reproduces this with synthetic
origins and identifiers.

## Transport policy still applies

The datasource refuses plaintext `ws://` to any non-loopback host. A server
whose session advertises a plain `ws://` URL on a non-loopback address (for
example an emulator host alias) therefore still gets no push. Production
advertises `wss://`.

## Limits and follow-ups

- Production runs two Stalwart nodes without a coordinator; a connection is told
  only about mail that arrived on its own node. FCM remains the dependable
  real-time path.
- Before release: a foreground soak test against production (Cloudflare and
  Traefik idle behaviour; `WS_ECHO_PING` is the likely mitigation, an env change),
  background/resume reconnection, live refresh on a device, and FCM
  non-duplication.

## Tests

- `web_socket_push_availability_test.dart`: 15 cases, including the real
  `Session.fromJson` decode of the Stalwart shape and account/global precedence.
- `base_controller_test.dart`: Basic Stalwart registers the connection
  interactor, OIDC without a ticket does not, ticket servers still do.
- `web_socket_datasource_impl_test.dart`: with no ticket the handshake carries the
  Basic header and the `jmap` subprotocol, targets `/jmap/ws` and has no
  `ticket` query; a plaintext emulator alias is refused before credentials are read.
