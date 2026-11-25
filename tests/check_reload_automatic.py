"""Check lightweight Reload route preserves harness while updating MAT."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'BusHarnessApp.m').read_text(encoding='utf-8')
h=(root/'createBusTestHarness.m').read_text(encoding='utf-8')
reload=s.split('    function reloadExcelPreview(~, ~)',1)[1].split('    function loadTestcaseToHarness',1)[0]
assert 'processHarness(true, true);' in reload
assert 'processHarness(false' not in reload
structural=s.split('    function loadTestcaseToHarness(~, ~)',1)[1].split('    function [visible,checked]',1)[0]
assert "'DefaultOption','Cancel'" in structural
assert 'processHarness(false, true);' in structural
assert 'selected = excelNames(ismember(availableNames,currentMatNames));' in s
assert 'createBusTestHarness(model, "", mergedPaths, outputFolder, "", existingHarness)' in s
assert 'compatibility = validateScenarioUpdate(string(matFile), scenarioData)' in h
assert 'set_param(editor' not in h.split('function info = reloadSignalEditor',1)[1].split('function backupReloadFile',1)[0]
print('PASS: Excel Reload updates only existing MAT scenarios, leaves FR/model params alone')
