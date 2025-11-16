# Changelog

All notable changes to this project will be documented in this file.

The format roughly follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0] – 2025-11-16

### Added

- New `--help` (`-h`) option with detailed usage text.
- New `--list-devices` (`-l`) option to list network interfaces as seen by macOS.
- Best-effort vendor / manufacturer lookup based on the MAC address OUI.
- Environment variable `MACCHANGER_OUI_PATH` to point at a custom OUI database.

### Changed

- Rewritten script for modern shell best practices:
  - Uses `#!/usr/bin/env bash` and `set -euo pipefail`.
  - Proper quoting of variables and stricter error handling.
  - Clear, colour-coded log messages.
- More robust Wi‑Fi handling:
  - Detects the `airport` binary path on newer macOS versions.
  - Disassociates Wi‑Fi before changing the MAC, then triggers hardware re-detection.
- Random MAC generation now explicitly ensures a locally-administered, unicast address.
- Improved user-facing output, including clearer error messages.

## [0.1.0] – 2016

### Added

- Initial release of `macchanger` script for macOS.
- Support for:
  - Showing current and permanent MAC addresses.
  - Setting a random MAC.
  - Setting a specific MAC.
  - Resetting the interface to its permanent MAC.

_Original version by **shilch** – <https://github.com/shilch/macchanger>_
