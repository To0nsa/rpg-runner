# Hub UI Theme

Hub-scoped UI defaults live in `UiHubTheme` (`lib/ui/theme/ui_hub_theme.dart`).

This is intentionally separate from `UiTokens` so component-specific defaults
(like hub select card sizing) do not leak into the global token contract.

Current values:

- selectCardWidth: 240
- selectCardHeight: 144
