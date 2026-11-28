# Semantic Versioning — Simulink Testing

Repository rule: every subsequent change to this project follows **Semantic Versioning 2.0.0** (`MAJOR.MINOR.PATCH`). Read this file **before modifying or releasing code**.

## Choose the version bump

| Type | Use when | From `1.2.82` |
| --- | --- | --- |
| **PATCH** | Bug fixes, refactoring, docs, tests, tooling, and maintenance that preserve existing supported functionality | `1.2.83` |
| **MINOR** | Add backward-compatible features (new buttons, testcase features, import formats, data tools) | `1.3.0` |
| **MAJOR** | Make an incompatible change (breaking testcase or project schema without migration, removing supported features, incompatible public API) | `2.0.0` |

Choose the highest required type when a release contains multiple changes: **MAJOR > MINOR > PATCH**. Minor bumps reset PATCH to `0`; major bumps reset MINOR and PATCH to `0`. Do not increase PATCH merely because a feature is small; new compatible functionality is MINOR.

## Workflow for every future update

1. Identify the scope and classify the changes (PATCH / MINOR / MAJOR) using the table above.
2. Make and test the changes, including relevant regressions. Report MATLAB/Simulink runtime testing separately from static tests.
3. Update `VERSION` (the canonical version, read by `simulinkTestingVersion.m`), `README.md` and `CHANGELOG.md`. You can use `python tools/bump_version.py patch|minor|major --note "Description"`.
4. Validate with `python tests/check_versioning.py` and the applicable test suite. **No GitHub Actions workflow is required**; run tests locally or as part of the release process.
5. Build `SimulinkTesting_v<version>.zip`, verify its contents, then commit and push the changed source to GitHub `main` and report the exact commit SHA.
6. Do not claim MATLAB runtime behavior has been tested if MATLAB was unavailable.

## Example

- Current version: `1.2.82` (policy simplification and workflow removal: PATCH).
- Next bug fix: `1.2.83`.
- Next backward-compatible feature: `1.3.0`.
- Next incompatible change: `2.0.0`.

The versioning policy is maintained in this **single file `semantic.md`**. `VERSION` and `CHANGELOG.md` are version metadata and release history, not duplicate policy documents.
