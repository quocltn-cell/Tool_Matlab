"""Static regression test for synchronized SDI-style navigation in both Data tabs.
Run: python tests/check_zoom_controls.py
"""
from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'testDataViewer.m').read_text()
assert 'for mode = 1:2' in s
assert "rightGrid = uigridlayout(right,[6 1]" in s
for control in ('Zoom In','Zoom Time','Zoom Y',
                'Fit [ ]','Fit X','Fit Y'):
    assert "'" + control + "'" in s, control
for key in ('function selectAxis(mode,ax)','function changeZoom(mode,kind)',
            'function fitView(mode,dimension)','function setSharedX(mode,limits)',
            'function refreshZoomCursors(mode)',
            'function limits = scaleXWithin','function limits = paddedSignalY'):
    assert key in s, key
assert 'v.FocusedAxis = index;' in s
assert "v.Axes{end+1} = ax;" in s
assert "v.DataYLimits(end+1,:) = fullY;" in s
assert "v.FullXLim = [plotStart plotEnd];" in s
assert 'changeCursor(mode,v.Cursor.Value);' in s
assert 'v.Markers{index}.YData = ylim(v.Axes{index});' in s
assert 'trace.ButtonDownFcn = @(~,~) clickAxis(mode,[],ax);' in s
assert 'v.Cursor.Limits = [plotStart plotEnd];' in s
print('PASS: shared toolbar, X sync, focused subplot Y, fit behavior, cursor refresh')
