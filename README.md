# Simulink Testing v1.2.74

## v1.2.74 — Allow compiled Fast Restart state during Reload Testcase

- MAT-only Reload Testcase permits `SimulationStatus` `stopped`, `initialized`, and `compiled`, checking both before and after loading the harness.
- Active states such as `running`, `paused`, `initializing`, and `stopping` remain blocked.
- Does not change Signal Editor block parameters, the harness model, or its Fast Restart setting.
- The updated MAT values are verified on disk, but an already-compiled Signal Editor's in-memory data cache is **not** verified. Run Test output must be checked to confirm new Value/Time was consumed.
- No MATLAB/Simulink runtime test has been performed in this environment.

# Simulink Testing v1.2.73

## v1.2.73 — Reload MAT while Fast Restart is initialized

- **Reload Testcase** permits MAT-only updates when the harness `SimulationStatus` is `stopped`, `initialized`, or `compiled`. Other simulation states (running, paused, initializing, etc.) are blocked with the exact state in Build Log.
- Reload preserves the loaded harness, its FastRestart setting, Signal Editor `Filename` and `ActiveScenario`; it does not call `set_param` or `save_system` to force a MAT reload.
- After atomic MAT replacement, verify the *actual saved Dataset values* for each updated scenario. On a verification/write error, restore the previous MAT backup.
- Build Log distinguishes **verified MAT values on disk** from **unverified Signal Editor runtime cache**. An initialized model may still use cached data; the next simulation output must be checked before relying on it.
- **Important:** MathWorks documents editing Signal Editor data under Fast Restart, but does not guarantee that an arbitrary external MAT overwrite forces an initialized Signal Editor block to reread it. This change removes the overly strict guard; it does not prove reuse of compiled state across separate Test Manager runs.
- MATLAB/Simulink runtime testing is still required.

# Simulink Testing v1.2.72

## v1.2.72 — Reload Testcase automatically updates MAT

- **Reload Testcase** refreshes the Excel File/Sheet/Testcase list and automatically updates every already-imported scenario in the Signal Editor MAT using current Excel Value/Time. No checkbox selection is required for this fast path.
- The MAT-only path validates signal names, datatypes, dimensions and bus structure before writing; it preserves the harness model, existing unselected MAT scenarios and its Fast Restart setting. New scenarios are not imported automatically; the Build Log identifies that a structural import is needed.
- **Load Testcase to Harness** now explicitly asks for confirmation before rebuilding the harness with **all Excel testcases**. Rebuild is reserved for structural changes and requires Build Test afterward to refresh iterations.
- If no harness exists, Reload Testcase only refreshes the Excel list and directs the user to Build Harness.
- Actual Signal Editor MAT cache refresh and compile reuse between separate Test Manager runs require MATLAB runtime testing.

# Simulink Testing v1.2.71

## v1.2.71 — Repair testcase MAT reload with Fast Restart on/off

- Fix syntax error in `validateScenarioUpdate.m` when finding Dataset variables.
- `Load Testcase to Harness` updates the existing Signal Editor MAT without changing `Filename`, `ActiveScenario`, or saving the harness, for either Fast Restart setting.
- Allow MAT-only updates when the harness is dirty, but reject an actively running simulation.
- Stage and validate the new MAT; retain a backup and restore the original MAT if writing or validation fails.
- Do not claim the model reuses compilation or refreshes previously cached signal data across independent Test Manager runs; verify the new values in the next simulation. If the running/initialized environment caches old MAT data, finish the Fast Restart session before restarting the test.

# Simulink Testing v1.2.71

## v1.2.71 — Smart Fast Restart-compatible testcase MAT updates

- **Load Testcase to Harness** checks the incoming Signal Editor Dataset scenarios against the current MAT file **before** writing data. A change limited to Time / Value / number of samples is accepted if bus field names, types, per-sample dimensions, and Dataset port names/order remain the same. Incompatible changes abort with the exact signal path and instructions to **Build Harness**, leaving the original MAT file intact.
- MAT updates are staged and backed up. When harness `FastRestart=on`, the import updates its MAT file **without changing the Signal Editor filename or saving/rebuilding the harness**. When Fast Restart is off, the previous conservative filename-rebind path is retained. These behaviors aim to avoid unnecessary recompilation, not to override Simulink's own compile decisions.
- If new scenarios are imported, Setting Build Log says to use **Build Test** to add corresponding Test Manager iterations.
- **Run Test** performs a preflight that the currently linked Signal Editor MAT file exists and includes all selected scenario datasets; missing or stale links cause a clear error rather than silently testing an old scenario list.
- `Reload Testcase` remains a preview-only Excel refresh and does not change the MAT file.
- **Limitation:** updating an external MAT file does not guarantee an already-initialized Signal Editor block rereads it without recompilation. Test Manager Fast Restart primarily reuses compilation *between compatible iterations within a run*. Reuse across separate `run(tc)` calls depends on the MATLAB release, run lifecycle, and cached state. Verify with a representative model that the new waveform is actually used. If Simulink will not refresh the data, disable Fast Restart, reload/reinitialize and run again (which may compile).
- Checked with Python static smoke tests and ZIP integrity; **MATLAB/Simulink execution has not been performed**.

# Simulink Testing v1.2.69

## v1.2.69 — Output Signal comparison highlighting

- In Data → Output, each row of **Output Signals (Excel)** is colored light red if the logged Model output and Signal Editor Expected output differ at any discrete step in the testcase input timeline.
- Rows are colored light green only if both Model and Expect are available, paired unambiguously and their values match throughout that timeline.
- Missing or ambiguous Model/Expect signals and unreadable/non-scalar waveforms retain a neutral background, never a false green status.
- Comparison is exact and uses zero-order hold across the union of recorded sample times. Coloring is informational, not a substitute for Test Manager assessments or tolerance-based verification.
- Highlighting updates when you change the selected output testcase or refresh Run Test results. It is independent of the signal Plot checkboxes.
- Existing Model (red), Expect (purple), matching segments (green), cursor and plot functionality remain unchanged.
- Changes are viewer-only: no Build Harness or Build Test is necessary. MATLAB runtime validation is still required.

# Simulink Testing v1.2.68

## v1.2.68 — Sync Fast Restart on Harness and Test Manager

- The **Fast Restart mode** checkbox in Run Test now updates the loaded harness model via `set_param(harness, 'FastRestart', 'on'/'off')` and the Test Manager test case `FastRestart` property. The latter governs running its iterations in Fast Restart.
- The same synchronization is applied before Run Test; signal logging configuration is performed first. If no harness/MLDATX exists when checking the option, the selection is retained and applied on Run Test when available.
- If immediate synchronization to a built Test Manager file fails, the UI selection and loaded harness FastRestart state are rolled back and a diagnostic alert is shown. Model fast-restart state is a runtime state; the tool does not recompile the model merely by checking the box.
- Requires validation in MATLAB/Simulink for the installed release and model configurations.

## v1.2.67 — Separate Excel preview refresh from Signal Editor MAT import

- **Reload Testcase** (Setting): re-read all currently selected testcase Excel workbooks, refresh the File → Sheet → Testcase checklist and its imported-name preview; do **not** write the Signal Editor MAT file or rebuild the harness. Current individual checkbox selections are preserved for matching workbook/sheet/testcase entries.
- Rename the previous **Load Test Case** action to **Load Testcase to Harness**. This action uses only the ticked Excel testcases, upserts their scenario datasets into the existing `<Harness>_Inputs.mat` generated by Build Harness, and preserves unselected scenarios. The harness must already exist; it never creates a second harness.
- The existing MAT update path validates input/output datatypes, parameter values, scenario bus interface and duplicate names. To ensure the Signal Editor refreshes its scenarios, the current implementation may refresh/save the harness model reference to that MAT file; the testcase waveforms are stored in the MAT file, not a new harness model.
- After a successful MAT import, stale Data/Gen Report results are cleared. An Excel-only Reload Testcase does not discard existing test results.
- **Fast Restart:** Changing just the values or times of compatible Signal Editor signals normally does not require recompilation **between simulations**, but MATLAB must actually reload the modified MAT/scenario before the next run. Changes in datatype, dimensions, model sample time, or structure require a new compile. The tool does not claim that a running/initialized model will automatically notice arbitrary disk edits; stop/reinitialize as needed.

## v1.2.66 — Fix Run Test status UI collision on re-import

- Fixed another MATLAB nested-function shared variable collision: `status` held the Setting `uilabel`, but `runTest` also used `status` for each iteration outcome. After Run Test, the label was overwritten by a string and `processHarness` failed at `status.Text` on Load Test Case.
- Use separate `statusLabel` (the UI handle) and `iterationStatus` (the result text). The earlier `buildLogArea` separation from v1.2.65 is preserved.
- Added `tests/check_ui_handle_collisions.py` to detect accidental reassignment of GUI handles in `BusHarnessApp.m` during future edits.
- To clear the already corrupted in-memory nested workspace, close the old GUI and run `clear BusHarnessApp` before reopening.
- This is a source-level fix; MATLAB runtime testing is still required.

## v1.2.65 — Fix Load Test Case error after Run Test

- Fix the MATLAB nested-function variable collision in `BusHarnessApp.m`: `updateTestLogLine` previously used `messages` as a temporary string array, overwriting the Setting Build Log `uitextarea` handle after Run Test. Rename the UI control to `buildLogArea` and use `logLines` for the Run Test array.
- Re-importing selected Excel testcases through **Load Test Case** after **Run Test** now preserves the Build Log control and reaches the existing Create/Update scenario workflow. No change to merge, datatype checks, or simulation logic.
- Close the previous app and run `clear BusHarnessApp` before launching v1.2.65 to discard stale nested-function state.
- Source-checked only; not runtime-tested in MATLAB/Simulink.

## v1.2.64 — Multi-sheet import, hierarchical selection and strict value ranges

- Reads **all testcase sheets** in each Excel workbook (sheets without a `testcase_name` header are skipped). Test Common workbooks continue to use their separate reader.
- **Setting → testcase load:** checkbox rows grouped as **File → Sheet → Testcase**. Checking a file checks all child sheets/testcases; checking a sheet checks its testcases. Unchecking individual cases updates the parent state. Existing **Select All / Deselect All** is retained.
- Detects duplicate testcase names **across sheets and across files**, case-insensitively. **Build Log** reports the name and both Excel locations, and aborts the import. Duplicates are listed in the preview warning.
- Both `Type = I` and `Type = O` values are range-checked **before conversion to the bus signal datatype**. Examples: `uint8` requires `0..255`, `int16` requires `-32768..32767`, `boolean` requires `0/1`; out-of-range values and noninteger values for integer signals abort Build Harness/Load Test Case and show testcase, signal and Excel row in Build Log. Base Workspace parameters are validated after resolving their values.
- The import is **atomic** at testcase-batch level; if any selected testcase fails validation the batch does not complete. The tool has not been executed in MATLAB in this environment.

## v1.2.63 — Base Workspace parameters in Excel Value
- Excel `Value` cells may contain a MATLAB Base Workspace variable name (e.g. `TargetSpeed`) instead of a numeric or Boolean literal.
- Supported variables include plain numeric/logical/enum values and `Simulink.Parameter` objects (using their `.Value`). Existing numeric, Boolean and enum-member literals still work.
- The tool resolves values when creating or reloading Signal Editor testcases (including workbooks assembled from common functions); Excel expressions are **not** executed.
- If a variable is missing, empty, non-numeric where numeric is required, or has an incompatible dimension, Build Log shows the testcase, Excel row, signal path and parameter name. Import is aborted without reporting false success.
- Static/source validation only; actual Base Workspace behavior must be verified in MATLAB.

## v1.2.62 — Generate Test Manager reports
- A **Gen Report** button appears in Run Test only after the current project has completed a Run Test with available iteration results.
- The button opens a report options dialog (PDF, DOCX or ZIP; include all/pass/fail; title, author, plots, errors, coverage and launch setting), then calls the supported `sltest.testmanager.report()` API.
- Reports are saved to `<project>/output/<project>_TestReport.<extension>`, with a replacement confirmation for existing reports. A separate **Open Test Manager** button gives access to the native Test Manager interface.
- MATLAB does not document a public API for opening the native Test Manager report-options dialog directly; the tool supplies its own options dialog rather than using unsupported internal APIs.
- The report action is reset on new/open/close project, Build Test replacement and before each Run Test. Existing build, running, Data tabs and report generation are otherwise independent.
- **Validation:** ZIP integrity, source assertions and static checks only. Real MATLAB/Simulink GUI execution remains to be verified.

## v1.2.61 — One Test Manager file per project
- Build Test writes only `output/<Model>_Tests.mldatx`; no numbered `_2`/`_3` versions.
- When any `.mldatx` exists in the project's `output` folder, display **Replace / Cancel** (Cancel is the default).
- Cancel preserves existing file(s) and the project link unchanged.
- Build the new test file in a temporary directory, then replace the project-owned `.mldatx` file(s). Backups are restored if install or project-save fails.
- On successful replacement, retain exactly one `.mldatx` in `output` and update the project's `TestManagerFile` reference.
- Other Test Manager files loaded in MATLAB are not cleared. No harness or scenario modification.
- Not runtime-tested in MATLAB/Simulink; test with a backup of the project.

## v1.2.60 — Colored Output testcase statuses
- Remove the redundant PASS CASES / FAIL CASES list from Data → Output.
- Color the testcase rows in the single-selection checkbox table: light red for Failed, light green for Passed.
- Preserve totals and Pass/Fail counts above the table; keep search and one-case-only selection.
- Refresh colors whenever a search filter or Run Test result changes. Older MATLAB versions without table styling continue to show test statuses in text.

## v1.2.59 — Select All testcase

- Setting → **testcase load**: nút **Select All / Deselect All** để chọn/bỏ chọn toàn bộ testcase từ Excel.
- Run Test → **Imported Test Cases**: nút **Select All / Deselect All** để chọn/bỏ chọn toàn bộ testcase đã import.
- Nút tự đồng bộ với trạng thái checkbox, bị vô hiệu khi danh sách rỗng hoặc tool đang xử lý.
- Hai danh sách chọn độc lập; không thay đổi phần Data Input/Output.


## Data Output timeline and cursor synchronization

- Both Data Input and Data Output derive their timeline from the input signal samples of the same Signal Editor scenario / testcase. Output no longer picks its duration from partial Model or Expect logging.
- All plotted signals for that testcase use the same X axis limits.
- Slider drag, slider release, plot click and entered Time + Enter now share the same sample-time snapping function (`alignTimeToSample`). E.g. Ts=0.01 sec: 0.023 sec snaps to 0.02 sec.
- If an older scenario has no readable input samples, each tab retains a waveform-duration fallback; no fabricated source-model sample time is introduced.
- No harness/test rebuild required; this only changes the Data viewer.
- Not runtime-tested in MATLAB; please verify with a real fixed-step model.

---

# Simulink Testing v1.2.57

## Data > Output fixes

- Output testcase selection is a single-select checkbox table, matching Input.
- Run Test registers Model Under Test output ports as Test Manager logged signals (one named `DataViewer_ModelOutputs` set, reused on repeat runs).
- Reads TestIterationResult `getOutputRuns` using SDI `getAllSignals`, including bus children, with a fallback to indexed signals.
- Displays the real Model trace only if recorded data is available and the signal name matches an Expected signal. No fabricated Model values.
- When Model data is unavailable or names do not match, Data > Output explains this using the recorded names and Run Test diagnostic text.
- Expected, Model, and matching overlay use the existing purple, red, and green presentation and shared cursor.

**Verification:** source inspected and ZIP integrity tested, but cannot execute MATLAB/Simulink in this environment. Run Test again after installing, since logging changes apply only to new runs.

---

## v1.2.52 — Harness fundamental sample time + cursor tick alignment

- Build Harness sets its `FixedStep` to the fundamental fixed-step size resolved from the referenced source model, rather than leaving `auto`.
- If the source model uses `auto`, try the compiled step, then periodic sample-time information. If a positive step cannot be resolved, report a precise error instead of silently assuming a rate.
- Data viewer retrieves the harness fixed step in seconds, with fallback to the referenced source model for older harnesses.
- Slider drag and typed Time + Enter both snap to sample ticks (e.g. Ts=0.01 s: 0.02 is valid; 0.023 -> 0.02). Cursor line and signal readout update together.
- Rebuild Harness for the solver change to take effect. This rebuild may recreate the generated harness; retain a backup of hand edits.
- Static checks only; actual MATLAB/Simulink runtime is not available here.

## v1.2.48 — Fix testcase selection in Data tab

- Fix empty Input checkbox table despite available testcase count.
- Independently refresh Input and Output lists and display diagnostics for table errors.
- Select first testcase by default in both tabs.
- Retain selected Run Test cases even if SDI output cannot be extracted; mark them Unknown rather than falsely Pass/Fail.
- No change to Build Harness, Excel import, or test execution.

## v1.2.45 — Fix Data Input/Output: Unrecognized field name "Name"

- Signal Editor scenarios created by this tool store each Dataset element as a plain struct of timeseries, not necessarily a Simulink.SimulationData.Signal object.
- Read element names from Dataset.getElementNames() instead of accessing the nonexistent struct.Name.
- Flatten nested bus structures directly; maintain input and *_Exp root names for filtering/matching.
- This applies to Input and Expected Output display. Model output still requires signal logging.
- Static source checks completed; MATLAB/Simulink runtime verification is not available in this environment.

## v1.2.44 — Data viewer signal parsing fix

- Read nested bus signals stored as structures of `timeseries`, scalar structs and numeric array leaves.
- Read bus-valued SDI output signals instead of discarding everything except scalar timeseries.
- Source Signal Editor data from the MAT file attached to the active harness where possible.
- Keep input signals separate from `_Exp` expected output buses.
- Show a reason when scenario data is absent or not compatible.
- Requirements: MATLAB, Simulink, Simulink Test. Signal logging must be enabled and actual output available from Test Manager for a red Model trace.
- If outputs are not logged, expected data can still appear in purple; missing model data is not treated as a passing comparison.
- Static source validation only: MATLAB/Simulink execution was not available for this build.

# Simulink Testing v1.2.43

1. Extract the ZIP and add this folder to the MATLAB path.
2. Open the MATLAB Project that provides the source model, data dictionary and dependencies.
3. Run `BusHarnessApp`. Click **New Project** on the welcome screen or choose it from **MENU → Project**.
4. In the save dialog, choose the parent folder and enter a filename such as `AGS.prj`.
   The app creates `AGS/AGS.prj` and the folders `AGS/input/` and `AGS/output/`.
5. Select the Simulink model and Excel workbooks. The app derives the harness name from the model.
   The app saves these selections automatically. Use **MENU → Project → Save Project** to save the current project on demand.
6. Tick the desired Excel test cases in **Excel Test Cases Not Yet Imported to Signal Editor**, then click **Build Harness**. The app saves the harness and Signal Editor MAT file in `input/`.
7. Use **Open Project** to select the saved `.prj` file.
   The app restores the saved selections and reads the test case list. **Open Harness** opens the latest saved harness.

**Close Project** offers Save, Don’t Save, and Cancel. Don’t Save skips the final write. Changes already saved automatically stay in the project file.

The app stores the path to the selected workbook in the project file and uses the workbook at that location. It also refers to the source model at its original location.
The `output/` folder is reserved for future reports. Older projects can still open saved files
under `testcases/` and `harness/`. The app requires MATLAB, Simulink and Simulink Test.

In Excel, start each testcase with its name in Testcase_name and close it with End in the same column on a separate row. The starting row can contain I or O data. Blank time cells reuse the last cumulative time within the testcase.

Use the circled plus button to add Excel files. Select files in the list and use the circled minus button to remove their paths. Harness generation imports only the checked testcase blocks from the listed workbooks. Test case names must be unique across the workbooks.

The app displays filenames and retains the full paths in the project. Harnesses use Model_Harness, Model_Harness_2, Model_Harness_3, and so on when names are taken.

## Common functions and reloading

- Add one or more workbooks under **Test Common Files**. Sheet 1 uses the same columns as test cases, with **Function common** in place of **Testcase_name**. Start each function with its name and finish it with **End**. Function names must be unique across the selected common workbooks.
- In a testcase, put **Func** in **Type** and the common function name in **Bus**. The app looks through sheets with a **Function common** header in the selected common files. Name matching ignores case, surrounding whitespace and invisible formatting marks.
- The app replaces the Func row with the matching function's rows from **Time(ms)** onward, including **Description**. It retains the testcase name if the call starts the testcase and leaves the testcase's own **End** in place. The common time cells are copied directly and interpreted as relative delays in the merged testcase. A time on the replaced Func row is replaced too.
- Both actions write one **<workbook>_Merged.xlsx** per testcase workbook to **input/** and use those files to load scenarios. If the filename is taken, the app adds a numeric suffix. The exports contain values from the testcase's first sheet and the expanded common rows.
- **Build Harness** uses the current workbook selections. After building a harness, use **Load Test Case** to import checked pending cases into the existing Signal Editor without deleting previously imported scenarios. It retains the existing blocks, connections and Test Assessment rules. Use **Build Harness** if the workbook changes the Signal Editor bus interface or requires different verification rules. Save any harness edits and stop simulation before reloading.

The tabs appear when a project is open. The **Setting** tab contains the project and harness workflow. The **Run Test** tab lists imported test cases with checkboxes and has a separate run log.

1. Build or load the harness scenarios from **Setting**.
2. Click **Build Test** under **Run Test** to save a new Test Manager file to the project's **output/** directory. It contains one simulation test for the harness, with one iteration per saved Signal Editor scenario.
3. Tick one or more cases and click **Run Test**. The app runs only those iterations and reports their outcomes. It restores the iteration enable settings after the run.

Before running, set **Fast Restart mode**, **Simulation Mode** (default Normal), and **Enable Coverage** in **Test Settings**. When coverage is enabled, choose the metrics to collect. Coverage settings apply at the Test Manager file level and include the referenced model under test. The app saves these options to the test file before running the selected iterations. The controls reset to their defaults when a project opens.

## v1.2.33 fix: Run Test iteration result logging

- Use the documented `TestIterationResult.Name` property instead of assuming
  every MATLAB release exposes `TestIterationResult.SignalEditorScenario`.
- Show readable iteration outcomes (Disabled, Incomplete, Passed, Failed)
  when the result API returns numeric outcome codes.
- Include failure error messages in the Run Log when available.
- No changes to Test Manager iteration creation, run settings, or harness logic.
- Requires validation in the target MATLAB/Simulink installation.

## v1.2.34: Run Test log progress and summary

- Show a single `Running: 0/N` row, updating to `1/N`, etc. as returned iteration results are processed.
- Replace the overall `Test outcome` message with `Test Result: X Pass | Y Fail`.
- Also report Incomplete, Disabled and Unknown outcomes if present, rather than counting them as failures.
- **Limitation:** MATLAB `run(tc)` is synchronous, so the progress count updates during **result processing after simulation**, not live as each simulation finishes. This preserves Fast Restart behavior and the existing single Test Manager run.
- Requires validation in MATLAB with Simulink Test.

## v1.2.35: Selective Excel testcase import

- The **Setting** tab contains a checkbox table of Excel test cases that are not yet in the saved Signal Editor scenario MAT file. Imported cases are still shown in **Run Test**.
- Tick desired pending cases. **Build Harness** imports only selected cases when creating a new harness; **Load Test Case** appends only selected pending cases to the existing harness, keeping prior MAT scenarios.
- After an import, the pending list refreshes, moving newly imported cases into the **Run Test** list.
- Import selection is temporary (not persisted to the project). The imported state comes from the saved Signal Editor MAT file.
- A changed input bus interface still requires a new harness. Test Manager iterations must be refreshed using **Build Test** after adding scenarios.
- A case already imported cannot be reimported/updated from this pending list; editing already-imported scenarios is not supported by the selective import workflow.
- Requires validation with MATLAB / Simulink Test.

## v1.2.36
- Setting: rename pending Excel scenario panel to `testcase load`.
- Display `testcase load` and `Build Log` side-by-side with equal (50/50) horizontal width.
- No changes to import or run behavior.


## v1.2.37 - Excel testcase preview fix
- The **testcase load** table previews testcase names immediately when an Excel file is added or a project opens.
- Preview does not expand `Func` rows and therefore works without Test Common Files.
- Newly added pending testcases are checked by default; existing checkbox choices are preserved during refresh.
- **Load Test Case / Build Harness** still require the referenced common functions; add their workbook under **Test Common Files** if an import reports a missing function such as `Func_a`.


## v1.2.38 - Selective testcase create/update

- `testcase load` always shows every testcase in the Excel workbook, including cases already imported into Signal Editor. Checkbox selections persist across refreshes.
- `Load Test Case` performs an upsert by scenario name: selected existing scenarios are replaced with Excel data, selected missing scenarios are created, and unselected scenarios remain unchanged.
- The Run Test list continues to show only the scenarios currently present in Signal Editor. Use **Build Test** after creating new scenarios to synchronize Test Manager iterations.
- A full Excel parse still requires referenced Test Common Files, when used.


## v1.2.39
- Build Harness reuses a saved existing harness rather than creating _2/_3 duplicates; use a fresh project to generate a separate harness.
- Setting Build Log shows only success/failure, selected testcase counts, and error message.
- Load Test Case uses the same compact reporting. Counts are atomic batch counts, not per-testcase partial success.
- Existing harness updates require a compatible Signal Editor signal interface; changes require a separately planned rebuild.

## v1.2.40: Harness naming based on input folder

- Build Harness chooses `<Model>_Harness` if no harness `.slx` or `.mdl` with that name exists in the current project's `input/` folder; otherwise it tries `_2`, `_3`, etc.
- Only model files in that `input/` folder reserve a suffix. Loaded models, model files elsewhere on the MATLAB path, and leftover `_Inputs.mat` do not force a higher suffix.
- If the chosen name is still loaded in MATLAB after its file was deleted, the build reports a clear error requesting that the open model be closed first (rather than silently generating `_3`).
- The existing-harness reuse behavior is unchanged: a saved project harness still present on disk is updated, not duplicated.
- Validate in MATLAB / Simulink.

## v1.2.41: Build Test duplicate-name diagnostics

- Check scenario names from the Signal Editor MAT file for duplicate/empty values before creating Test Manager objects.
- Remove the automatically created default Test Suite before creating the named suite and test case.
- The Build Test log now identifies the failing step, for example `adding iteration "Test_demo1"`, instead of showing only a generic duplicate-name error.
- Do not overwrite existing Test Manager files or modify Signal Editor data.
- Requires validation in MATLAB/Simulink Test.


### v1.2.42
Build Harness replaces previously generated harnesses for the selected model with one canonical `<Model>_Harness.slx`. Old matching harness files are archived temporarily and removed only on successful build; on failure they are restored. Unsaved or running harness models must be saved/stopped first. Load Test Case remains an upsert without rebuilding.

## v1.2.43: Data inspector

- New **Data** main tab with **Input** and **Output** subtabs. Data lists the
  iterations from the most recent Run Test in this application session.
- Search by testcase name and select one testcase at a time.
- Input plots the associated Signal Editor MAT dataset with one signal per axis,
  signal name in the axis panel header and a shared cursor.
- Output lists Pass/Fail totals and per-iteration outcomes. Output compares
  recorded SDI output signals with `_Exp` values from the Signal Editor scenario.
  Model = red; Expect = purple; exact matching sample intervals = green.
- Run Test attempts to enable data logging on the Model Under Test output lines.
  Output plots still require compatible SDI signals in `getOutputRuns`.
  If logging is unavailable or signal names do not match,
  the application leaves Model data unavailable instead of inventing it.
- Scalar numeric/logical time series are supported; some nested buses and
  non-scalar dimensions require additional conversion in later releases.
- The global cursor snaps to the model FixedStep when fixed-step is numeric;
  otherwise the original time stamps are retained.
- This version was inspected statically, not run inside MATLAB.


## v1.2.46 - Data viewer visibility and diagnostics

- Data Input/Output viewer now keeps an always-visible diagnostic line.
- Plot rendering exceptions are displayed instead of leaving the waveform panel blank.
- Each signal is plotted independently; one malformed signal does not hide the others.
- Waveform grid explicitly allocates one row per signal.
- When a scenario MAT file or output recording is missing, the source/path issue is shown.
- This build has not been run in MATLAB; validate with actual scenario MAT and Test Manager results.


## v1.2.47 - Excel-filtered Input plots
- Data > Input: only one testcase is selected at a time using the Test Cases checkbox table.
- Signals and Waveforms: new Input Signals (Excel) checkbox table; defaults to no plotted signals.
- Signal list is read from the selected testcase's Type=I rows, using its Bus and Signal columns.
- Only checked signals are plotted, preventing the entire model bus from being graphed.
- Works as a lightweight preview even if a common-function workbook is unavailable.
- Output tab retains existing behavior.


## v1.2.49 – Data chart cursor compatibility fix

- Replace `xline` with ordinary `line` cursor in UIAxes to avoid internal text-position dimension errors in certain MATLAB versions.
- Preserve time cursor movement by updating `XData` instead of `ConstantLine.Value`.
- Include plotting phase and MATLAB stack location in error messages if another plotting operation fails.
- Reuse the next available plot row if an individual signal fails, so valid signals can still display.
- No changes to Build Harness, Build Test, Load Test Case, or Run Test.


## v1.2.50 – Data waveform inspector display

- Input waveform is a blue step plot with X and Y grid lines and the signal name in the plot panel title.
- Place sample values next to the vertical cursor at their waveform height, rather than in a bottom readout.
- Output shows distinct red Model and purple Expect sample labels beside the cursor.
- A numeric time entry next to the slider accepts seconds and moves the cursor; moving the slider updates the entry.
- Time is snapped to the model's configured sample interval when available, with bounds enforced.
- This source has not been executed in MATLAB; verify on the target MATLAB release.


## v1.2.51 – Numeric cursor time correction

- Entering time in the numeric field and pressing Enter now positions the slider and waveform cursors at that exact time, bounded by the signal duration.
- Slider movement continues to snap to the model sample interval when available.
- Numeric time entry intentionally does not round to the model's sample interval; the displayed signal value remains a zero-order hold sample at the requested time.
- MATLAB runtime testing is still required.


## v1.2.53 – Output waveform rendering reliability

- Normalize Model and Expect timeseries to scalar waveform vectors before plotting.
- Draw the red Model and purple Expect traces before optional equality overlay and cursor labels.
- If optional green matching segments or a UIAxes cursor label fails, retain the plotted traces rather than clearing the entire chart.
- Initialize text labels with scalar coordinates and a non-empty placeholder; skip labels with a warning if the MATLAB release rejects them.
- Preserve all existing testcase selection, input plotting and solver sample-time behavior.
- MATLAB execution verification is still required.


## v1.2.54 - Data Output waveform fix

- Output has its own checkbox table of Type=O signals from the selected Excel test case. One testcase is selected at a time, and no output signals are plotted until explicitly checked.
- If the Excel output list is unavailable, the table falls back to expected `_Exp` signals in the selected MAT scenario.
- Output waveforms use separate UI labels for Model/Expect cursor values instead of UIAxes `text()` objects, avoiding the recurring `Dimensions of position argument...` graphics-text exception. The plotted Model/Expect lines remain red/purple, with equality overlay green.
- Errors display MATLAB stack location when available.
- To reload: `clear BusHarnessApp testDataViewer readHarnessExcelOutputSignals`; then launch `BusHarnessApp`. Run Test again before inspecting Output.
- MATLAB runtime verification still required.


## v1.2.55 — Output signal pairing and plot fix

- Fixed the `pairOutputs` failure reported at line 756: MATLAB string comparison `leaf == '.'` was incorrectly used as a character index. Names are now normalized as full paths, matched exactly first, then by unique bus/path suffix, finally by an unambiguous leaf.
- Model output and `_Exp` scenario signal are drawn on the same `uiaxes`, with red Model, purple Expect, and green exactly matching segments. Ambiguous or unavailable logged Model data remain missing instead of being silently paired to a different signal.
- Output axes use Input's grid, step plotting, shared slider/time cursor, and in-axes value tags. The Excel Output Signals checkbox list from v1.2.54 remains in place.
- No changes to Build Harness, Build Test, or Run Test. No rebuild of the harness is required for this viewer-only fix.


## v1.2.56 — Missing Model output diagnostics and logging

- Enable `SignalLogging` on the Simulink Test Manager test case before running it, in addition to marking the Model Under Test outputs for logging.
- Collect and retain the precise Test Manager/SDI logging status for each iteration. Exceptions are no longer silently discarded.
- Display an explicit Model-missing diagnostic with names of available logged signals; never synthesize Model samples from Expect.
- Build Log prints a diagnostic when no Model samples were collected.
- `Data -> Output` still plots Expect alone when Model is unavailable, but indicates why Model cannot be compared.
- Requires **Run Test again** after installing the update; building harness is not necessary.
- The MATLAB runtime and actual output logging in the user's project must still be verified.
