function test_debug_harness_manual
% Manual GUI regression steps. MATLAB/Simulink required.
% 1. Build harness with two scenarios, Build Test, Run Test case #2.
% 2. Click Open Harness next to case #2; verify Signal Editor ActiveScenario
%    is #2, not the first scenario, and the Signal Editor window opens.
% 3. Run the harness manually; confirm the expected #2 input is used.
% 4. Click Open Harness next to case #1; verify ActiveScenario changes.
% 5. Enable Fast Restart, simulate, then select case #2 while compiled.
% 6. Test the checkbox and Select All remain independent of Open Harness.
% 7. While the harness is actively running, verify the button refuses to
%    change ActiveScenario, with an informative alert.
fprintf('Run interactive debug harness scenario selection checklist.\n');
end
