# SpotnSend Mobile Front-End

This repository contains the SpotnSend Flutter mobile front-end built with Riverpod, go_router, and MapLibre.

## Getting started

1. Ensure Flutter (3.22 or newer) is installed and on your PATH.
2. From the project root run:
   `ash
   flutter pub get
   flutter run --dart-define=MAPTILER_KEY=baucnweLIulZSBRwopDh
   `
3. When running in debug the app boots into the login screen. Use a username that contains erified to simulate a verified user; any other username simulates a pending user.

## Key features

- Authentication flow with three-step onboarding and verification states.
- Bottom navigation shell with Map, Report, Notifications, Account, and Settings tabs.
- MapLibre integration with MapTiler styles, radius filters, saved spots, and list view.
- Report submission flow with audience targeting, media attachments, and warning modal.
- Notifications center with mark-read and delete actions.
- Account management with saved spots, stats, and editable contact info.
- Settings for notifications, 2FA, language (EN/AR), and theme (Light/Dark/System).

## Assets & fonts

- Replace ssets/images/logo_spotnsend.png with the official brand logo if required.
- Add brand font files under ssets/fonts/ and update the theme if you wish to use the custom families.

## Platform permissions

Remember to update platform-specific permission descriptions (Android Manifest and iOS Info.plist) to align with the plugins in use (location, permission_handler, image_picker).
