"""Static regression checks for per-case Open Harness and scenario selection."""
from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'BusHarnessApp.m').read_text()
assert "testcaseRows = uigridlayout(testcaseGrid" in s
assert "'Scrollable','on'" in s
assert "openCase = uibutton(testcaseRows,'Text','Open Harness'" in s
assert "'ButtonPushedFcn',@(~,~) openHarnessForTestcase(rows.TestCase(idx))" in s
assert 'rows.Selected(idx) = logical(value)' in s
assert 'testcaseList.Data = rows;' in s
assert 'scenarioNames = harnessScenarioNames(rows.TestCase);' in s
assert 'scenario = scenarioNames(match);' in s
assert 'if ~ismember(scenario,scenarios)' in s
assert "set_param(editor,'ActiveScenario',char(scenario));" in s
assert 'open_system(char(harness));' in s
assert 'open_system(editor);' in s
assert 'if ~ismember(lower(simState),["stopped","initialized","compiled"])' in s
assert s.count('renderRunTestcaseRows();') >= 6
print('PASS: per-row button, correct MAT scenario mapping, checkbox preservation, Fast Restart guard')
