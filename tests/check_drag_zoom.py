"""Static regression for SDI-style rectangular zoom on Input & Output."""
from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'testDataViewer.m').read_text()
for label in ('Cursor','Zoom In','Zoom Time','Zoom Y','Fit [ ]','Fit X','Fit Y'):
    assert f"'{label}'" in s, label
for snippet in ('function startZoomDrag(mode,ax)', 'function moveZoomDrag(varargin)',
                'function endZoomDrag(apply)', 'function fitView(mode,dimension)',
                'function changePointerMode(mode,pointer)', 'function handleZoomKey(src,evt)',
                'WindowButtonMotionFcn = @moveZoomDrag', 'WindowButtonUpFcn = @(~,~) endZoomDrag(true)',
                'WindowButtonMotionFcn = dragState.MotionCallback',
                'WindowButtonUpFcn = dragState.UpCallback', 'FaceAlpha',
                "if strcmp(pointer,'Zoom Time'), y = ylim(ax); end",
                "if strcmp(pointer,'Zoom Y'), x = xlim(ax); end",
                'setSharedX(mode,sort([startPoint(1),point(1)]))',
                'ylim(ax,sort([startPoint(2),point(2)]))',
                "strcmp(key,'space')", "strcmp(key,'t')", "strcmp(key,'y')"):
    assert snippet in s, snippet
assert 'for mode = 1:2' in s
assert "priorKeyHandler = viewerFigure.WindowKeyPressFcn" in s
assert "trace.ButtonDownFcn = @(~,~) clickAxis(mode,[],ax);" in s
assert 'refreshZoomCursors(mode);' in s
assert "'Fit selected subplot to view in Y'" not in s  # replaced dropdown with Fit Y shortcut
print('PASS: pointer dropdown, drag select, X/Y-only zoom, callback restoration, shortcuts, both tabs')
