function test_drag_zoom_manual()
% Interactive test checklist (requires MATLAB with graphics environment).
% 1. Open Data > Input, select two signals. Select Zoom In and drag a
%    rectangle in the second subplot. X zoom must affect both axes while
%    Y zoom only affects the second subplot.
% 2. Select Zoom Time and drag horizontally: only X changes, all subplots.
% 3. Select Zoom Y and drag vertically: only focused subplot Y changes.
% 4. Check the same interactions under Data > Output (Model & Expect).
% 5. Fit [ ] button or Space resets all X and Y axes.
% 6. Fit X button or Ctrl+Alt+T resets all X, keeping Y.
% 7. Fit Y button or Ctrl+Alt+Y resets selected subplot Y only.
% 8. Zoom Out button doubles span; Time cursor clicks still work after
%    selecting Cursor from the pointer dropdown.
% 9. Verify project menu hover works after completing a zoom drag, and
%    Escape cancels a drag without changing axes.
% 10. Repeat after choosing different testcase and after Run Test.
fprintf('Use the manual drag zoom checklist in this test file.\n');
end
