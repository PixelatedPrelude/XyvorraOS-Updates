# XyvorraOS Updates

This repository is the update channel for [XyvorraOS](https://github.com/PixelatedPrelude/XyvorraOS-Linux-Distro).

Installed systems pull updates from here using the `xyvorra-update` command.

## How it works

- `manifest.json` — index of all releases, read by `xyvorra-update --check`
- `VERSION` — always contains the latest stable version string
- `releases/<version>/` — files, scripts, themes and hooks for each release

## Versioning

| Type | Example | When |
|------|---------|------|
| Minor | 1.1.0 → 1.2.0 | New features, themes, apps |
| Patch | 1.1.0 → 1.1.1 | Bug fixes, small config changes |
| Major | 1.x → 2.0.0 | Breaking changes, full rebuilds |

## Update command (on an installed XyvorraOS system)

\`\`\`bash
xyvorra-update           # interactive — check, preview, apply
xyvorra-update --check   # check for updates only
xyvorra-update --apply   # silent, non-interactive apply
xyvorra-update --rollback  # revert last update
\`\`\`

## Branch structure

- `main` — stable releases only, tagged
- `dev` — work in progress, never pulled by installed systems
