# Android listing assets

[long_run_icon.svg](long_run_icon.svg) is the editable source for the shared
Android launcher icon and [512 px Play icon](play_icon.png). It uses the companion
Lothringen brand's dimmed sun, road and aged-gold/charcoal palette. Environment
names remain in the launcher labels; this image contains no platform branding,
rating, review claim or promotional text.

The five `android/app/src/main/res/mipmap-*/ic_launcher.png` exports are 48, 72,
96, 144 and 192 px. Generate them from the SVG, not from another PNG. Current
exports use `@resvg/resvg-js` 2.6.2, with `fitTo: {mode: 'width', value: size}`
and `font: {loadSystemFonts: false}`. No fonts or linked images are required.
The renderer is an authoring tool, not an application dependency.

The Play export is square, fully opaque, 512 × 512, under 1 MB, with no baked-in
rounded corners or drop shadow. Visual inspection includes the 48 px launcher
size. Actual Play upload/readback remains part of the active
[release checklist](../../building/android_beta_release.md).

Store screenshots and the feature graphic are still pending. Screenshots must
come from the accepted Android candidate; do not substitute web captures or
invented gameplay.
