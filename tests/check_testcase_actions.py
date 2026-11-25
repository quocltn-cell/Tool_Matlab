"""Static smoke checks for automatic MAT refresh and structural rebuild."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
src=(root / "BusHarnessApp.m").read_text(encoding="utf-8")
helper=(root / "createBusTestHarness.m").read_text(encoding="utf-8")
assert "'Text', 'Reload Testcase'" in src
assert "'Text', 'Load Testcase to Harness'" in src
preview=src.split("    function reloadExcelPreview(~, ~)",1)[1].split("    function loadTestcaseToHarness(~, ~)",1)[0]
assert "readTestcaseNames()" in preview
assert "processHarness(true, true);" in preview
assert 'if harnessFile == "" || ~isfile(harnessFile)' in preview
assert "save_system(" not in preview
structural=src.split("    function loadTestcaseToHarness(~, ~)",1)[1].split("    function [visible,checked]",1)[0]
assert "uiconfirm(app" in structural
assert "processHarness(false, true);" in structural
load=src.split("    function processHarness(reload, updateAll)",1)[1].split("    function buildTest(~, ~)",1)[0]
assert "currentMatNames = importedScenarioNames()" in load
assert "selected = excelNames(ismember(availableNames,currentMatNames))" in load
assert 'info = createBusTestHarness(model, "", mergedPaths, outputFolder, "", existingHarness)' in load
assert "info = buildSingleHarness(model, mergedPaths, outputFolder)" in load
assert "MAT scenarios updated:" in load
assert "dataViewer.clear();" in load
assert "function info = reloadSignalEditor" in helper
assert "save(staged, '-struct', 'scenarioData')" in helper
print("PASS: Reload updates MAT automatically; structural button rebuilds after confirmation")
