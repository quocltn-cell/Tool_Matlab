function test_zoom_limits
% Manual interactive smoke test; requires MATLAB UI support.
% Open Simulink Testing, Data > Input and Output and test these steps:
%  1. Select two signals, click the second waveform; focus shows 2/2.
%  2. Zoom Time; both X ranges shrink identically, Y unchanged.
%  3. Zoom Y; only second Y range shrinks, X unchanged.
%  4. Zoom In / Zoom Out; X changes together, focused Y changes.
%  5. Fit to view; all X/Y reset to the plot's data boundaries.
%  6. Fit to view in time; X reset, current Y zoom retained.
%  7. Fit selected subplot to view in Y; only focused Y resets.
%  8. Move cursor; waveform labels still show correct samples.
%  9. Repeat after changing testcase and on Data > Output.
% This script is documentation only; axes handles are app-private.
fprintf('Use the documented interactive zoom/fit test checklist.\n');
end
