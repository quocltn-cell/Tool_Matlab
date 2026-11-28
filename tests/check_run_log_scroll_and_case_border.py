"""Regression: scrollable Run Log, bordered imported testcase rows."""
from pathlib import Path
s = (Path(__file__).resolve().parents[1]/'BusHarnessApp.m').read_text(encoding='utf-8')
assert "testLayout = uigridlayout(testTab, [4 3]" in s
assert "'RowHeight', {30, '1x', 8, '1x'}" in s
assert "verticalSplit = uipanel(testLayout" in s
assert "horizontalSplit = uipanel(testLayout" in s
for old in ('logSplitSlider', 'splitHeightLabel', 'resizeRunLog', "'Log height'"):
    assert old not in s, old
assert "testMessages = uitextarea(testLogLayout, 'Editable', 'off'" in s
assert "testMessages.Layout.Row = 2;" in s
assert "'RowHeight', {30,'1x'}" in s
assert "'Scrollable','on'" in s
assert "testcaseRows = uigridlayout(testcaseGrid,[1 1]" in s
assert "casePanel = uipanel(testcaseRows,'BorderType','line'" in s
assert "'BorderColor',[0.78 0.81 0.86]" in s
assert "caseRow = uigridlayout(casePanel,[1 3]" in s
assert "tick = uicheckbox(caseRow" in s
assert "nameLabel = uilabel(caseRow" in s
assert "openCase = uibutton(caseRow,'Text','Open Harness'" in s
assert "function onRunCaseChecked(idx,value)" in s
assert "testcaseList.Data = rows;" in s
print('PASS: native scrolling Run Log, no height control, bordered rows and controls preserved')
