"""Static smoke test for Fast Restart synchronization in the Unit Test app."""
from pathlib import Path
s = (Path(__file__).resolve().parents[1] / "BusHarnessApp.m").read_text(encoding="utf-8")
assert "'ValueChangedFcn', @onFastRestartChanged" in s
assert "function onFastRestartChanged(~, ~)" in s
assert "setHarnessFastRestart(harnessFile, requested)" in s
assert "applyFastRestartToTestManager(requested, modelName)" in s
assert "setProperty(tcSync, 'FastRestart', logical(enabled))" in s
assert "saveToFile(tfSync)" in s
assert "set_param(name, 'FastRestart', requested)" in s
assert "applyRunSettings(tf, tc, harness);" in s
assert "setHarnessFastRestart(savedHarnessFile(), logical(fastRestart.Value))" in s
assert s.index("configureOutputLoggingForTest(tc,harness)") < s.index("applyRunSettings(tf, tc, harness);")
assert 'toolVersion = simulinkTestingVersion();' in (Path(__file__).resolve().parents[1] / "createBusTestHarness.m").read_text(encoding="utf-8")
print("PASS: Fast Restart checkbox and Run Test synchronize harness and Test Manager")
