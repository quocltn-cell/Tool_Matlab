"""Regression guards for the slider-thumb jump and Output drag-to-zoom."""
from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'testDataViewer.m').read_text(encoding='utf-8')
assert "'ValueChangingFcn',@(~,evt) sliderChanging(mode,evt)" in s
assert "'ValueChangedFcn',@(src,evt) sliderChanged(mode,src,evt)" in s
changing=s.split('    function sliderChanging(mode,evt)',1)[1].split('    function sliderChanged',1)[0]
assert 'changeCursor(mode,evt.Value,false)' in changing
assert 'v.Cursor.Value =' not in changing
changed=s.split('    function sliderChanged(mode,src,evt)',1)[1].split('    function changeCursor',1)[0]
assert 'changeCursor(mode,t,true)' in changed
apply=s.split('    function changeCursor(mode,t,commitSlider)',1)[1].split('\nend\n\nfunction result = clipPointToAxes',1)[0]
assert 'if commitSlider' in apply and 'v.Cursor.Value = t;' in apply
assert apply.index('if commitSlider') < apply.index('v.Cursor.Value = t;')
assert 'v.CursorValue = t;' in apply
assert 'disableDefaultInteractivity(ax);' in s
assert 'drawMatching(ax,s,@(~,~) clickAxis(mode,[],ax))' in s
overlay=s.split('function drawMatching(ax,s,onClick)',1)[1].split('function v = sampleAt(',1)[0]
assert "'PickableParts','visible','ButtonDownFcn',onClick" in overlay
assert 'function startZoomDrag(mode,ax)' in s
assert 'WindowButtonUpFcn = @(~,~) endZoomDrag(true);' in s
print('PASS: slider is never reset while moving; both Output traces and matching overlays can start custom zoom')
