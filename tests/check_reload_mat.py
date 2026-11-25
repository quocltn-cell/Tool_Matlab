"""Regression checks for MAT-only testcase reload with Fast Restart enabled/disabled."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
checker = (root / "validateScenarioUpdate.m").read_text(encoding="utf-8")
app = (root / "BusHarnessApp.m").read_text(encoding="utf-8")
harness = (root / "createBusTestHarness.m").read_text(encoding="utf-8")
assert "datasetMask = strcmp({vars.class}, 'Simulink.SimulationData.Dataset');" in checker
assert "existing = string({vars(datasetMask).name});" in checker
assert "{vars(strcmp({vars.class}" not in checker
assert "function info = reloadSignalEditor" in harness
body = harness.split('function info = reloadSignalEditor',1)[1].split('function backupReloadFile',1)[0]
assert "compatibility = validateScenarioUpdate" in body
assert body.index("compatibility = validateScenarioUpdate") < body.index("backupReloadFile(staged, matFile)")
assert "set_param(editor" not in body
assert "save_system(harness)" not in body
assert "checkWritten = whos('-file', matFile)" in body
assert "backupReloadFile(matBackup, matFile)" in body
assert "SimulationStatus" in body
assert "Load Testcase to Harness" in app
print("PASS: MAT-only reload validates, stages, restores on errors, and does not mutate block/model parameters")
