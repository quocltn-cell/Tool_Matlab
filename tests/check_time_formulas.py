"""Static regression guard for time formulas in Build Harness and Reload."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
src = (root / 'createBusTestHarness.m').read_text(encoding='utf-8')
parser = (root / 'testcaseTimeFormula.m').read_text(encoding='utf-8')
grid = (root / 'testcaseFormulaTimeline.m').read_text(encoding='utf-8')
assert 'toolVersion = simulinkTestingVersion();' in src
assert 'rebuildExistingMatScenarios(cases, matFile, previous.(oldScenario)' in src
assert "str2double(get_param(harness, 'FixedStep'))" in src
assert 'time = testcaseFormulaTimeline(' in src
assert src.count('testcaseFormulaTimeline(') == 2, 'Build and Reload must both expand the time grid'
assert src.count('testcaseTimeFormula(') == 2, 'Both waveform writers must parse formulas'
assert src.count('validateSignalValueRange(formulaValue, sample)') == 2
assert src.count("strcmpi(clock, 'EnableTime')") == 2
assert src.count('data(from:end,1) = cast(formulaValue') == 1
assert src.count('data(first:end,1) = cast(formulaValue') == 1
assert 'CurrentTime|EnableTime' in parser
assert 'regexpi(' in parser and 'eval(' not in parser
assert "{'stopped','initialized','compiled'}" in src
assert '250000' in grid and 'grid = (0:count)' in grid
print('PASS: Build/Reload both support safe time formulas with fixed-step samples and range validation')
