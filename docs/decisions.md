# Decisions

Decisions taken on tmail-flutter, oldest first. Append only: a decision that changes gets a new entry that replaces the old one and cites it. Entry format: the `twake-decisions` skill of [linagora/twake-guidelines](https://github.com/linagora/twake-guidelines/blob/main/skills/twake-decisions/SKILL.md).

Categories: UX, UI, Product, Architecture, Infra, Tech.

## 2026-11-21, [Infra] Validate NumberInbox main with the synchronized toolchain

- Decision: NumberInbox main commits receive the analysis and test gate, and device validation uses the same branch and Flutter 3.47.9 toolchain with exact-commit CI and ancestry checks.
- Decided by: Manish Thakur, Codex chat, November 21, 2026, approving upstream synchronization and private CI alignment.
- Why: Published main commits need executable checks matching the synchronized app's SDK requirement.
- Scope: NumberInbox mobile CI and its device validation.
