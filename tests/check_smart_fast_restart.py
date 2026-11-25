from pathlib import Path
root=Path(__file__).resolve().parents[1]
a=(root/'BusHarnessApp.m').read_text(encoding='utf-8')
b=(root/'createBusTestHarness.m').read_text(encoding='utf-8')
c=(root/'validateScenarioUpdate.m').read_text(encoding='utf-8')
assert 'verifyHarnessMatBeforeRun(savedHarnessFile(), selected)' in a
assert 'compatibility = validateScenarioUpdate(string(matFile), scenarioData)' in b
assert b.index('compatibility = validateScenarioUpdate') < b.index("staged = [tempname(folder) '.mat']")
reload_body = b.split('function info = reloadSignalEditor(', 1)[1].split('function backupReloadFile(', 1)[0]
assert "set_param(editor, 'Filename'" not in reload_body
assert "set_param(editor,'ActiveScenario'" not in reload_body
assert "save_system(harness)" not in reload_body
assert "backupReloadFile(matFile, matBackup)" in reload_body
assert "checkWritten = whos('-file', matFile)" in reload_body
assert "backupReloadFile(staged, matFile);" in b
assert "'SmartRestartCompatible', compatibility.Compatible" in b
assert "getElementNames" in c and "sa(1)=[]; sb(1)=[]" in c
print('PASS: MAT interface guard, fast-restart-preserving branch, and pre-run scenario preflight are present')
