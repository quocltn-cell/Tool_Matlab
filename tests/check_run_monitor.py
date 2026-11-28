"""Static regression checks for Run Test layout / run status / timer.
Run: python tests/check_run_monitor.py
"""
from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'BusHarnessApp.m').read_text()
for snippet in (
    "testLayout = uigridlayout(testTab, [4 3]",
    "testcases.Layout.Row = [2 4]",
    "verticalSplit.Layout.Column = 2;",
    "horizontalSplit.Layout.Row = 3;",
    "logSplitSlider = uislider(testActions",
    "function resizeRunLog(value)",
    "testLog.Layout.Row = 4;",
    "testLog.Layout.Column = 3;",
    "runStatusLabel = uilabel(runMonitorBar",
    "runElapsedLabel = uilabel(runMonitorBar",
    "runCompileLabel = uilabel(runMonitorBar",
    "runMonitorTimer = timer('ExecutionMode','fixedSpacing'",
    "'Period',1,'BusyMode','drop'",
    "function stopRunMonitor()",
    "result = run(tc);",
    "stopRunMonitor();",
    "get_param(name,'SimulationStatus')",
    "seconds(details(j).Duration)",
    "getTimingInfo(details(j))",
    "function addCompileDiagnostics(messages)",
    "Compiled model count:",
    "not reported by Test Manager",
    "setRunStatus('Completed with Failures')",
    "setRunStatus('Error')",
    "setRunStatus('Completed')",
):
    assert snippet in s, snippet
assert s.count("stopRunMonitor();") >= 4
assert "'1x', '1x'}, 'ColumnWidth', {'3x', '2x'}" not in s
assert (Path(__file__).resolve().parents[1] / 'VERSION').read_text().strip() == '1.4.0'
print('PASS: layout split + status, compile diagnostic, timer and iteration timing')
