# Maintaining Houston

## Prerequisites

- macOS with Xcode installed
- Developer ID Application certificate: Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application
- Apple ID app-specific password: appleid.apple.com > Sign-In and Security > App-Specific Passwords

## One-time local setup

Store notarization credentials in a keychain profile:

```
xcrun notarytool store-credentials "Houston" \
  --apple-id YOUR_APPLE_ID \
  --team-id 98C3ZR73ZM
```

When prompted for a password, enter the app-specific password generated above, not your Apple ID password.

## Versioning

Set MARKETING_VERSION in the Xcode project: Houston target > General > Identity > Version. The Makefile reads this value automatically. CI overrides it from the git tag.

## Local release

```
make release
```

This runs the full pipeline: archive, export, notarize app, create DMG, notarize DMG, staple. Output lands at `build/Houston-VERSION-ARCH.dmg`.

Individual stages are available as separate targets: `make archive`, `make export`, `make notarize`, `make dmg`.

## CI release

Push a version tag to trigger the GitHub Actions workflow:

```
git tag v1.2.0
git push origin v1.2.0
```

The workflow archives, signs, notarizes, builds a DMG, and creates a GitHub Release with auto-generated notes. It runs on `macos-15`.

### Required repository secrets

| Secret | Value |
|---|---|
| CERTIFICATE_P12 | Base64-encoded Developer ID Application certificate (.p12) |
| CERTIFICATE_PASSWORD | Password for the .p12 file |
| KEYCHAIN_PASSWORD | Arbitrary password for the ephemeral CI keychain |
| TEAM_ID | Apple Developer team ID |
| APPLE_ID | Apple ID email for notarization |
| APPLE_PASSWORD | App-specific password for that Apple ID |

To export the certificate as base64:

```
base64 -i Certificates.p12 | pbcopy
```
