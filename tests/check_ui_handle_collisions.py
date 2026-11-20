"""Regression guard for MATLAB nested-workspace GUI handle collisions.

Run: python tests/check_ui_handle_collisions.py
Checks that handles created at the top level of BusHarnessApp are not
reassigned to unrelated values in nested callbacks. This is a static test,
not a replacement for testing the app in MATLAB.
"""
from pathlib import Path
import re

src = Path(__file__).resolve().parents[1] / 'BusHarnessApp.m'
lines = src.read_text(encoding='utf-8').splitlines()
ui_constructor = re.compile(r'^([A-Za-z]\w*)\s*=\s*ui(?:figure|label|button|table|textarea|panel|gridlayout|listbox|tab|tabgroup|checkbox|slider|dropdown|editfield|buttongroup|radiobutton)\s*\(')
# Only top-level declarations are shared across nested callbacks.
handles = {m.group(1): n for n, line in enumerate(lines, 1) if (m := ui_constructor.match(line))}
errors = []
for name, declaration_line in handles.items():
    assign = re.compile(r'(?<!\w)' + re.escape(name) + r'\s*=(?!=)')
    for n, line in enumerate(lines, 1):
        if n == declaration_line or line.lstrip().startswith('%') or line.lstrip().startswith('function '):
            continue
        if assign.search(line):
            errors.append(f'{name}: UI handle declared at {declaration_line}, reassigned at {n}: {line.strip()}')
if errors:
    raise SystemExit('GUI HANDLE REASSIGNMENT DETECTED:\n' + '\n'.join(errors))
print(f'PASS: {len(handles)} top-level GUI handles have no reassignment in nested callbacks')
