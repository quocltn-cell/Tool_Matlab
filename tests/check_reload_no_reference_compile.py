"""Regression checks for MAT-only reload of an already compiled hierarchy."""
from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'createBusTestHarness.m').read_text()
assert 'toolVersion = "1.2.77"' in s
head=s.split('function info = reloadSignalEditor',1)[0]
assert head.index('if existingHarness ~= ""') < head.index("model = get_param(load_system(char(model)), 'Name');")
reload=s.split('function info = reloadSignalEditor',1)[1].split('function backupReloadFile',1)[0]
assert '[inputs, outputs] = inspectSourceModel(' not in reload
assert 'get_param(model,' not in reload
assert not any(line.lstrip().startswith("feval(model") for line in reload.splitlines())
assert 'rebuildExistingMatScenarios(cases, matFile' in reload
assert "{'stopped','initialized','compiled'}" in reload
assert 'compatibility = validateScenarioUpdate' in reload
assert 'isequaln(written.(scenarioName), scenarioData.(scenarioName))' in reload
assert 'backupReloadFile(matBackup, matFile)' in reload
assert 'getElement(dataset' in reload and 'setElement(dataset' in reload
assert 'validateSignalValueRange(newValue, sample)' in reload
assert 'BusHarness:MATSignalAmbiguous' in reload
assert 'set_param(editor' not in reload
assert 'save_system(' not in reload
print('PASS: reload never compiles/re-queries referenced model; updates from MAT schema')
