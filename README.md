# SMB Client App

A Flutter Android app for browsing and downloading files from SMB/CIFS network shares.

## Features

- **SMB authentication** — host, share, username, password with optional credential saving
- **File browser** — navigate shares and folders, tap files to download and open
- **Multi-select download** — long-press to select multiple files/folders, download as a single ZIP

## Build

```bash
flutter pub get
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

For smaller per-architecture APKs:

```bash
flutter build apk --split-per-abi
```

## Requirements

### Runtime
- Android 10+ (API 29)
- SMBv2/3 compatible server (Windows shares, Samba 4.x, TrueNAS, OpenMediaVault, etc.)
- Device and server on the same network (or reachable via VPN)
- Internet permission (granted at install)

### Server-side SMB configuration
- SMB signing not required (client doesn't enforce it)
- Guest access disabled — username/password authentication only
- Share permissions must allow read access for the connecting user

## License

MIT
