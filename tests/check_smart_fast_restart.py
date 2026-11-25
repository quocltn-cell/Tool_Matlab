from pathlib import Path
root=Path(__file__).resolve().parents[1]
a=(root/'BusHarnessApp.m').read_text(encoding='utf-8')
b=(root/'createBusTestHarness.m').read_text(encoding='utf-8')
c=(root/'validateScenarioUpdate.m').read_text(encoding='utf-8')
assert 'verifyHarnessMatBeforeRun(savedHarnessFile(), selected)' in a
assert 'compatibility = validateScenarioUpdate(string(matFile), scenarioData)' in b
assert b.index('compatibility = validateScenarioUpdate') < b.index("staged = [tempname(folder) '.mat']")
assert "if keepFastRestart" in b
assert "backupReloadFile(staged, matFile);" in b
assert "save_system(harness);" in b
assert "'SmartRestartCompatible', compatibility.Compatible" in b
assert "getElementNames" in c and "sa(1)=[]; sb(1)=[]" in c
print('PASS: MAT interface guard, fast-restart-preserving branch, and pre-run scenario preflight are present')
