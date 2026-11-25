"""Static regression check for MAT updates during initialized Fast Restart.
Run with: python tests/check_initialized_reload.py
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
h = (root / 'createBusTestHarness.m').read_text(encoding='utf-8')
app = (root / 'BusHarnessApp.m').read_text(encoding='utf-8')
body = h.split('function info = reloadSignalEditor',1)[1].split('function backupReloadFile',1)[0]
assert "{'stopped','initialized','compiled'}" in body
assert "get_param(harness, 'SimulationStatus')" in body
assert 'Stop the running simulation before updating' not in body
assert "'BusHarness:ReloadBusy'" in body
assert 'set_param(editor' not in body
assert 'save_system(' not in body
assert 'compatibility = validateScenarioUpdate' in body
assert body.index('compatibility = validateScenarioUpdate') < body.index('backupReloadFile(staged, matFile)')
assert 'isequaln(written.(scenarioName), scenarioData.(scenarioName))' in body
assert 'backupReloadFile(matBackup, matFile)' in body
assert "'MatFileVerified', true" in body
assert "'SignalEditorCacheVerified', false" in body
assert 'MAT values verified on disk. Signal Editor runtime cache not verified.' in app
print('PASS: initialized/compiled allowed, active simulations blocked, content checked, cache not falsely claimed refreshed')
