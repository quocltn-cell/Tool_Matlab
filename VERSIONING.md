# Versioning policy — Simulink Testing

This repository follows [Semantic Versioning 2.0.0](https://semver.org/): `MAJOR.MINOR.PATCH`.
The **single source of truth** is the root `VERSION` file, read by
`simulinkTestingVersion.m` when the MATLAB tool creates a harness.

## Choosing a release type

| Type | When to increment | Example from 1.2.80 |
| --- | --- | --- |
| **PATCH** | Backward-compatible bug fixes, internal refactors, tests, docs, packaging and maintenance with no new user-visible functionality | `1.2.81` |
| **MINOR** | Backward-compatible capabilities, additional buttons/options, new testcase syntax, supported workflows | `1.3.0` |
| **MAJOR** | Incompatible changes requiring users to migrate, e.g. removed supported features, breaking `.prj` schema without automatic migration, incompatible testcase format/API | `2.0.0` |

- A release can include several changes: choose the **highest-impact** type (MAJOR > MINOR > PATCH).
- On MINOR bump, reset PATCH to zero. On MAJOR bump, reset MINOR and PATCH to zero.
- A defect fix changing faulty behavior to documented behavior is PATCH; if it deliberately breaks existing supported behavior, MAJOR.
- Do not equate number of edited files with type of release.
- Keep pre-release identifiers such as `1.3.0-rc.1` only for intentional candidate builds; stable releases use three numeric components.
- Current transition: `1.2.79` -> `1.2.80` is PATCH to establish the policy and align the runtime version with the artifact version. Earlier historical releases are not retroactively renumbered.

## Workflow for every subsequent change

1. Classify changes as `major`, `minor`, or `patch` **before implementation**.
2. Implement changes and add appropriate tests; run static tests and MATLAB tests when possible.
3. Use `python tools/bump_version.py <major|minor|patch> --note "Short description"` to update `VERSION`, `README.md` and `CHANGELOG.md` (the script refuses to run without a note).
4. Validate with `python tests/check_versioning.py` and `python -m unittest discover -s tests -p 'test_semver*.py'`. Review other tests before release.
5. Package the complete project as `SimulinkTesting_v<version>.zip`. Verify every required file is present and the ZIP opens.
6. Commit source, tests, `VERSION`, `README.md`, `CHANGELOG.md`, and relevant docs together to GitHub `main`; report the actual commit SHA.
7. Never describe unexecuted MATLAB/Simulink tests as passed. Identify whether a change is only statically verified.

**For the next change following v1.2.80:** a bug fix becomes `v1.2.81`; a compatible new feature becomes `v1.3.0`; a breaking change becomes `v2.0.0`.
