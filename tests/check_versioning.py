"""Validate a single source of SemVer and release bookkeeping."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
version = (root / 'VERSION').read_text(encoding='utf-8').strip()
assert re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', version), version
readme = (root / 'README.md').read_text(encoding='utf-8')
change = (root / 'CHANGELOG.md').read_text(encoding='utf-8')
harness = (root / 'createBusTestHarness.m').read_text(encoding='utf-8')
resolver = (root / 'simulinkTestingVersion.m').read_text(encoding='utf-8')
assert readme.startswith('# Simulink Testing v' + version + '\n')
assert f'## [{version}] - ' in change
assert 'toolVersion = simulinkTestingVersion();' in harness
assert "fileread(fullfile(root, 'VERSION'))" in resolver
assert (root / 'VERSIONING.md').is_file()
assert (root / 'tools/bump_version.py').is_file()
print(f'PASS: v{version} SemVer, README, CHANGELOG and runtime version synchronized')
