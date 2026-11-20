"""Static smoke checks for the Setting testcase actions. Run with Python 3."""
from pathlib import Path
src = (Path(__file__).resolve().parents[1] / "BusHarnessApp.m").read_text(encoding="utf-8")
helper = (Path(__file__).resolve().parents[1] / "createBusTestHarness.m").read_text(encoding="utf-8")
assert "'Text', 'Reload Testcase'" in src
assert "'Text', 'Load Testcase to Harness'" in src
preview = src.split("    function reloadExcelPreview(~, ~)",1)[1].split("    function [visible,checked] = addPendingRow",1)[0]
assert "readTestcaseNames()" in preview
assert "createBusTestHarness(" not in preview
assert "writeMergedWorkbook(" not in preview
assert "save_system(" not in preview
load = src.split("    function processHarness(reload)",1)[1].split("    function buildTest(~, ~)",1)[0]
assert "if reload" in load and "existingHarness);" in load and "createBusTestHarness(model," in load
assert "dataViewer.clear();" in load
assert "function info = reloadSignalEditor" in helper
assert "save(staged, '-struct', 'scenarioData')" in helper
assert "previousScenarioNames" in helper
print("PASS: preview and MAT update paths are distinct")
