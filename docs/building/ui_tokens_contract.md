# UI Tokens Contract

This document defines the UI token contract for the Flutter UI layer. The
initial rollout is applied to the Play Hub surface only.

## Spacing Scale

Use the fixed scale below for spacing, padding, and layout gaps:

- xxs = 4
- xs = 8
- sm = 12
- md = 16
- lg = 24
- xl = 32
- xxl = 48

## Radii Scale

- sm = 8
- md = 12
- lg = 16
- xl = 24

## Typography Roles

- display: 32, bold
- title: 24, bold
- headline: 16, semi-bold
- body: 12, regular
- label: 12, semi-bold (letter spaced)
- caption: 12, medium

Hub card roles (shadowed, all caps friendly):
- cardLabel: 12, bold, letter spaced
- cardTitle: 16, bold
- cardSubtitle: 12, bold

## Color Roles

- background, surface, cardBackground
- textPrimary, textMuted
- outline, outlineStrong
- accent, accentStrong
- danger, success
- scrim, shadow
- buttonBg, buttonFg, buttonBorder

## Component Sizes (Play Hub)

- tapTarget: 48 (minimum)
- buttonHeight: 48 (minimum)
- playButtonWidth: 192
- weeklyButtonWidth: 96
- leaderboardButtonWidth: 144
- iconSize: xs=12, sm=16, md=24, lg=32
- dividerThickness: 4
- borderWidth: 4

Hub select card sizing is hub-scoped:

- selectCardWidth: 240
- selectCardHeight: 144
- characterPreviewSize: 96

## Effects Tokens

- card shadow
- strong text shadow

## Rules

- New Play Hub UI uses tokens only (no magic numbers).
- Tap targets are never below 48dp.
- Spacing uses the fixed scale above.
