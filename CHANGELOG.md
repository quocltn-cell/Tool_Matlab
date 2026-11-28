# Changelog

Significant changes are recorded here in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) style and versions follow [SemVer](https://semver.org/).

## [1.4.0] - 2026-11-28

### Added
- Run Test status monitor, elapsed seconds and per-iteration execution/init timing logs; best-effort compile model diagnostics.
- Log height slider to resize Settings and Run Log panels.

### Fixed
- Restored visible split between testcase list, Test Settings and Run Log.

## [1.3.0] - 2026-11-28

### Added
- Open Harness button for each imported testcase in Run Test, setting its matching Signal Editor scenario for manual debugging.


## [1.2.82] - 2026-11-28

### Fixed
- Simplify version rules into semantic.md and remove GitHub Actions workflow

## [1.2.81] - 2026-11-28

### Fixed
- Fix cursor slider position and Output drag-to-zoom gestures

## [1.2.80] - 2026-11-28

### Changed
- Adopted SemVer release rules and a single source of version truth (`VERSION`); the MATLAB harness generator reads it through `simulinkTestingVersion.m`.
- Added version bump helper, validation, and CI verification so future updates select MAJOR, MINOR or PATCH by compatibility impact.
- Replaced a hardcoded historical version in the Fast Restart regression test.

## [1.2.79] - 2026-11-28

### Added
- Drag-to-zoom selection modes and keyboard Fit shortcuts in Input and Output signal plots.

For historical details of versions 1.2.78 and earlier, consult `README.md` and Git history.
