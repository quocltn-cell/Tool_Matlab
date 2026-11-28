#!/usr/bin/env python3
"""Bump VERSION, README and CHANGELOG using Semantic Versioning.

Example:
    python tools/bump_version.py minor --note "Add waveform export"

Must be run once for each *subsequent* release, after changes are classified.
"""
from __future__ import annotations
import argparse
import datetime
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


def next_version(current: str, change: str) -> str:
    match = VERSION_RE.fullmatch(current)
    if not match:
        raise ValueError(f"Unsupported stable SemVer: {current!r}")
    major, minor, patch = map(int, match.groups())
    if change == 'major':
        return f'{major + 1}.0.0'
    if change == 'minor':
        return f'{major}.{minor + 1}.0'
    if change == 'patch':
        return f'{major}.{minor}.{patch + 1}'
    raise ValueError(f'Unknown change type: {change}')


def bump(change: str, note: str, date: str, *, root: Path = ROOT) -> str:
    note = note.strip()
    if not note or '\n' in note or '\r' in note:
        raise ValueError('Provide one non-empty single-line release note')
    before = (root / 'VERSION').read_text(encoding='utf-8').strip()
    after = next_version(before, change)
    changelog = (root / 'CHANGELOG.md').read_text(encoding='utf-8')
    readme = (root / 'README.md').read_text(encoding='utf-8')
    if not readme.startswith(f'# Simulink Testing v{before}\n'):
        raise ValueError('README version does not match VERSION')
    if f'## [{after}]' in changelog:
        raise ValueError(f'{after} already exists in CHANGELOG')
    label = {'major': 'Changed', 'minor': 'Added', 'patch': 'Fixed'}[change]
    changelog_marker = '\n## ['
    pos = changelog.find(changelog_marker)
    if pos < 0:
        raise ValueError('Cannot locate changelog release section')
    entry = f'\n## [{after}] - {date}\n\n### {label}\n- {note}\n'
    changelog = changelog[:pos] + entry + changelog[pos:]
    readme = readme.replace(f'# Simulink Testing v{before}\n',
                            f'# Simulink Testing v{after}\n', 1)
    index = readme.find('\n## ', len(f'# Simulink Testing v{after}\n'))
    next_section = readme.find('\n## ', index + 4)
    if next_section < 0:
        raise ValueError('Cannot locate historical README sections')
    readme = readme[:next_section] + f'\n## v{after} — {note}\n\n- Release type: **{change.upper()}**.\n' + readme[next_section:]
    (root / 'VERSION').write_text(after + '\n', encoding='utf-8')
    (root / 'CHANGELOG.md').write_text(changelog, encoding='utf-8')
    (root / 'README.md').write_text(readme, encoding='utf-8')
    return after


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('change', choices=('major', 'minor', 'patch'))
    parser.add_argument('--note', required=True, help='One-line description')
    parser.add_argument('--date', default=datetime.date.today().isoformat())
    args = parser.parse_args()
    print('New version:', bump(args.change, args.note, args.date))


if __name__ == '__main__':
    main()
