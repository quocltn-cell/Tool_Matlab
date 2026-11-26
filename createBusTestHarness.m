function info = createBusTestHarness(model, harnessName, excelFile, outputFolder, commonFiles, existingHarness)
%CREATEBUSTESTHARNESS Create a standalone simulation model around a Model block.
%   info = createBusTestHarness() opens a dialog for the model and Excel file.
%   info = createBusTestHarness(model, "", excelFile) imports Excel without the UI.
%   info = createBusTestHarness('Controller.slx') creates Controller_Harness.
%   info = createBusTestHarness('Controller.slx','Controller_Custom') sets the name.
%   Open the source project first to make its model and dictionary available.
%   Specify outputFolder as the fourth argument to save outside the current folder.
%   Pass common workbook paths as the fifth argument.
%   Pass an existing generated harness file as the sixth argument to reload it.
%   info.ToolVersion records the tool version used to generate the harness.

arguments
    model (1,1) string = ""
    harnessName (1,1) string = ""
    excelFile string = ""
    outputFolder (1,1) string = ""
    commonFiles string = ""
    existingHarness (1,1) string = ""
end

toolVersion = "1.2.76";
if model == ""
    [model, excelFile] = selectHarnessFiles(toolVersion);
    if model == ""
        info = [];
        return
    end
end
cases = [];
if any(excelFile(:) ~= "")
    cases = readHarnessExcel(excelFile, commonFiles);
end

% A MAT-only Reload must NEVER load/compile/query the referenced model:
% it can already be part of the harness's Fast Restart compiled hierarchy.
if existingHarness ~= ""
    [~, sourceModelName] = fileparts(char(model));
    if isempty(sourceModelName)
        error('BusHarness:ModelName', 'Cannot identify the referenced model name.');
    end
    info = reloadSignalEditor(sourceModelName, existingHarness, cases, excelFile, toolVersion);
    return
end
model = get_param(load_system(char(model)), 'Name');
if outputFolder == ""
    outputFolder = string(pwd);
end
if ~isfolder(outputFolder)
    error('BusHarness:OutputFolder', 'Output folder does not exist: %s', char(outputFolder));
end
[found, folderInfo] = fileattrib(char(outputFolder));
if ~found
    error('BusHarness:OutputFolder', 'Cannot resolve output folder: %s', char(outputFolder));
end
outputFolder = folderInfo.Name;
if harnessName == ""
    base = [model '_Harness'];
    suffix = '';
    index = 1;
    while true
        harness = [base(1:min(end, namelengthmax-numel(suffix))) suffix];
        if ~harnessNameTaken(harness, outputFolder) && ~strcmp(harness, model)
            break
        end
        index = index + 1;
        suffix = sprintf('_%d', index);
    end
else
    harness = char(harnessName);
    if ~isvarname(harness) || strcmp(harness, model)
        error('BusHarness:InvalidName', 'Choose a valid harness name distinct from the source model.');
    end
    if harnessNameTaken(harness, outputFolder)
        error('BusHarness:NameConflict', 'A model or input file for "%s" already exists.', harness);
    end
end
% Names are reserved only by harness model files in the selected input folder.
% A model left open in MATLAB after its .slx was deleted should not silently
% force _2/_3. In that situation, ask the user to close the stale model.
if bdIsLoaded(harness)
    error('BusHarness:LoadedNameConflict', ...
        ['The harness name "%s" is available in the input folder, but a model ' ...
         'with this name is still loaded in MATLAB. Close that model ' ...
         '(save changes first if needed) and retry Build Harness.'], harness);
end
harnessFile = fullfile(outputFolder, [harness '.slx']);
matName = [harness '_Inputs.mat'];
matFile = fullfile(outputFolder, matName);

created = false;
wroteMat = false;
try
    new_system(harness, 'Model');
    created = true;
    % Match the fundamental fixed step of the referenced source model.
    % Do not leave the harness at 'auto', because the Data viewer cursor
    % and runnable scheduling must use the same seconds/sample.
    sourceStep = resolveHarnessSampleTime(model);
    set_param(harness, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
        'FixedStep', num2str(sourceStep,17));
    cut = add_block('simulink/Ports & Subsystems/Model', [harness '/Model Under Test'], ...
        'ModelName', model, 'Position', [385 100 565 260]);

    dictionaryName = get_param(model, 'DataDictionary');
    dictionary = [];
    designData = [];
    if ~isempty(dictionaryName)
        dictionary = Simulink.data.dictionary.open(dictionaryName);
        designData = getSection(dictionary, 'Design Data');
        set_param(harness, 'DataDictionary', dictionaryName);
    end
    [inputs, outputs] = inspectSourceModel(model, designData);
    ports = get_param(cut, 'PortHandles');
    if numel(ports.Inport) ~= numel(inputs) || numel(ports.Outport) ~= numel(outputs)
        error('BusHarness:PortMapping', ...
            'Root data/function-call ports do not match the Model block interface.');
    end
    inputNames = reshape(string({inputs.Name}), [], 1);
    inputTypes = reshape(string({inputs.Type}), [], 1);
    outputNames = reshape(string({outputs.Name}), [], 1);
    outputTypes = reshape(string({outputs.Type}), [], 1);
    inputBus = startsWith(inputTypes, "Bus:");
    outputBus = startsWith(outputTypes, "Bus:");
    runnable = reshape([inputs.Runnable], [], 1);
    busInputs = find(inputBus);
    dataInputs = find(~inputBus & ~runnable);

    editorPath = '';
    editorOutputs = [];
    expectedNames = strings(0,1);
    expectedTypes = strings(0,1);
    scenarioLabels = strings(0,1);
    expectedModelPorts = [];
    verifyRules = [];
    verifyCount = 0;
    if ~isempty(cases)
        [scenarioData, scenarioLabels, scenarioNames, expectedNames, expectedTypes, ...
            expectedModelPorts, verifyRules] = ...
            buildExcelScenarios(cases, inputs, outputs, busInputs, dictionary, designData);
    else
        scenarioNames = matlab.lang.makeUniqueStrings(cellstr(inputNames(busInputs)));
        Scenario = Simulink.SimulationData.Dataset;
        for k = 1:numel(busInputs)
            input = inputs(busInputs(k));
            [bus, ground] = busGround(input, dictionary, designData);
            values = busTimeseries(ground, bus, designData, input.Block, [0; 1]);
            Scenario = addElement(Scenario, values, scenarioNames{k});
        end
        scenarioData = struct('Scenario', Scenario);
        if ~isempty(busInputs)
            scenarioLabels = "Scenario";
        end
    end
    editorTypes = [inputTypes(busInputs); expectedTypes(:)];
    assessment = [harness '/Test Assessment'];
    set_param(harness, 'Description', ...
        char("Generated by createBusTestHarness v" + toolVersion));
    if ~isempty(editorTypes)
        wroteMat = true;
        save(matFile, '-struct', 'scenarioData');
        editor = add_block('simulink/Sources/Signal Editor', [harness '/Signal Editor'], ...
            'Position', [65 100 220 100+max(55, 25*numel(editorTypes))]);
        editorPath = getfullname(editor);
        set_param(editor, 'Filename', matFile);
        % Rebase the MAT path when this harness is loaded from another folder.
        set_param(harness, 'PostLoadFcn', sprintf([ ...
            'set_param(''%s/Signal Editor'', ''Filename'', ' ...
            'fullfile(fileparts(get_param(''%s'', ''FileName'')), ''%s''));'], harness, harness, matName));
        set_param(editor, 'ActiveScenario', char(scenarioLabels(1)));
        if isfield(get_param(editor, 'DialogParameters'), 'SignalPropertySource')
            set_param(editor, 'SignalPropertySource', 'Dialog parameters');
        end
        set_param(editor, 'ApplySigPropsToAllScenarios', 'on');
        for k = 1:numel(editorTypes)
            set_param(editor, 'ActiveSignal', scenarioNames{k});
            if startsWith(editorTypes(k), "Bus:")
                set_param(editor, 'IsBus', 'on');
                set_param(editor, 'OutputBusObjectStr', char(editorTypes(k)));
            end
            if ~isempty(cases)
                set_param(editor, 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
            end
        end
        editorPorts = get_param(editor, 'PortHandles');
        editorOutputs = editorPorts.Outport;
        if numel(editorOutputs) ~= numel(editorTypes)
            error('BusHarness:EditorMapping', 'Signal Editor port count does not match the scenario buses.');
        end
        for k = 1:numel(busInputs)
            add_line(harness, editorPorts.Outport(k), ports.Inport(busInputs(k)), 'autorouting', 'on');
        end
    end

    add_block('sltestlib/Test Assessment', assessment, ...
        'Position', [810 100 975 100+max(55, 25*(nnz(outputBus)+numel(expectedNames)))]);
    symbols = connectBusOutputs(harness, assessment, ports.Outport, outputTypes, ...
        outputBus, reshape([outputs.Adapt], [], 1), outputNames);

    expectedSymbols = strings(0,1);
    if ~isempty(expectedNames)
        expectedPorts = editorOutputs(numel(busInputs)+(1:numel(expectedNames)));
        expectedSymbols = connectBusOutputs(harness, assessment, expectedPorts, expectedTypes, ...
            true(numel(expectedPorts),1), false(numel(expectedPorts),1), expectedNames);
    end

    if ~isempty(verifyRules)
        configureOutputVerifies(assessment, ...
            verifyRules, find(outputBus), symbols, expectedModelPorts, expectedSymbols, cases, inputs(runnable));
        verifyCount = numel(verifyRules);
    end

    sourceY = 180 + max(55, 25*numel(editorTypes));
    sourceY = connectRunnables(harness, ports.Inport, inputs, find(runnable), sourceY);
    for k = reshape(dataInputs, 1, [])
        ground = add_block('simulink/Sources/Ground', sprintf('%s/Ground_%d', harness, k), ...
            'Position', [175 sourceY 205 sourceY+25]);
        groundPorts = get_param(ground, 'PortHandles');
        add_line(harness, groundPorts.Outport, ports.Inport(k), 'autorouting', 'on');
        sourceY = sourceY + 45;
    end

    if ~isempty(cases)
        allRows = vertcat(cases.Rows);
        finalTime = max([allRows.Time, [cases.DurationMs] / 1000]);
        stopTime = str2double(get_param(harness, 'StopTime'));
        if isfinite(stopTime) && finalTime > stopTime
            set_param(harness, 'StopTime', num2str(finalTime, 17));
        end
    end
    set_param(harness, 'SimulationCommand', 'update');
    save_system(harness, harnessFile);
catch failure
    if created
        try
            close_system(harness, 0);
        catch cleanupFailure
            failure = addCause(failure, cleanupFailure);
        end
    end
    if wroteMat
        removeReloadBackup(matFile);
    end
    rethrow(failure);
end
open_system(harness);

if isempty(editorTypes)
    matFile = '';
end
inputPorts = (1:numel(inputs)).';
runnableRates = reshape({inputs(runnable).Rate}, [], 1);
info = struct('ToolVersion', toolVersion, 'Harness', harness, 'HarnessFile', harnessFile, ...
    'ScenarioFile', matFile, 'SignalEditor', editorPath, 'TestAssessment', assessment, ...
    'ExcelFile', excelFile, 'Scenarios', scenarioLabels, 'VerifyCount', verifyCount, ...
    'ExpectedOutputs', table(expectedNames(:), expectedSymbols(:), expectedTypes(:), ...
        'VariableNames', {'Signal','Symbol','DataType'}), ...
    'Inputs', table(inputPorts, inputNames, inputTypes, ...
        'VariableNames', {'ModelPort','Signal','DataType'}), ...
    'Runnables', table(find(runnable), inputNames(runnable), runnableRates, ...
        'VariableNames', {'ModelPort','Signal','SampleTime'}), ...
    'BusOutputs', table(find(outputBus), symbols(:), outputTypes(outputBus), ...
        'VariableNames', {'ModelPort','Symbol','DataType'}));
end

function removeReloadBackup(file)
if isfile(file)
    try
        delete(file);
    catch failure
        warning('BusHarness:ReloadBackupCleanup', '%s', failure.message);
    end
end
end

function info = reloadSignalEditor(model, harnessFile, cases, excelFile, toolVersion)
if isempty(cases) || ~isfile(harnessFile)
    error('BusHarness:Reload', 'Reload requires test cases and an existing harness file.');
end
[found, attributes] = fileattrib(char(harnessFile));
if ~found
    error('BusHarness:Reload', 'Cannot resolve the existing harness file.');
end
harnessFile = attributes.Name;
[folder, harness] = fileparts(harnessFile);
if bdIsLoaded(harness)
    % This operation only updates the Signal Editor MAT file. An unsaved
    % model is not a reason to reject a data-only update, and we never save
    % or modify the loaded harness to perform this operation.
    if ~strcmpi(get_param(harness, 'FileName'), harnessFile)
        error('BusHarness:Reload', ...
            'A different model with the harness name is loaded. Close it and retry.');
    end
    % Fast Restart can leave the model 'initialized' or 'compiled' between simulations.
    % MAT-only Value/Time updates are permitted in those states; changing
    % a block parameter or the model is deliberately NOT attempted here.
    % Other states, including paused and running, are not safe to update.
    simStatus = char(get_param(harness, 'SimulationStatus'));
    if ~any(strcmpi(simStatus, {'stopped','initialized','compiled'}))
        error('BusHarness:ReloadBusy', ...
            ['Harness "%s" has SimulationStatus="%s". ' ...
             'Finish the active simulation before Reload Testcase. ' ...
             'A compiled/initialized Fast Restart session does not need to be disabled.'], ...
            harness, simStatus);
    end
end
load_system(harnessFile);
% Recheck after load_system in case another callback changed the state.
reloadStatus = char(get_param(harness, 'SimulationStatus'));
if ~any(strcmpi(reloadStatus, {'stopped','initialized','compiled'}))
    error('BusHarness:ReloadBusy', ...
        'Harness "%s" is "%s". Stop the active simulation before Reload Testcase.', ...
        harness, reloadStatus);
end
cut = [harness '/Model Under Test'];
editor = [harness '/Signal Editor'];
if getSimulinkBlockHandle(cut) < 0 || getSimulinkBlockHandle(editor) < 0 || ...
        ~strcmp(get_param(cut, 'ModelName'), model)
    error('BusHarness:Reload', 'The harness must have a Signal Editor and reference the selected model.');
end

% Build MAT changes from its existing Dataset schema, not from the compiled
% referenced model. inspectSourceModel() calls feval(model, ..., 'compile')
% and is only legal in the structural Build Harness path.
oldScenario = get_param(editor, 'ActiveScenario');
matFile = fullfile(folder, [harness '_Inputs.mat']);
if ~isfile(matFile)
    error('BusHarness:Reload', 'The harness Signal Editor MAT file is missing: %s', matFile);
end
previous = load(matFile, oldScenario);
if ~isfield(previous, oldScenario)
    error('BusHarness:Reload', 'The saved Signal Editor scenario "%s" is missing.', oldScenario);
end
[scenarioData, labels] = rebuildExistingMatScenarios(cases, matFile, previous.(oldScenario));
% Upsert selected Excel test cases by Signal Editor scenario name.
% Keep every unselected existing scenario untouched. A selected existing
% scenario is replaced with new Excel data; a selected new scenario is added.
% Preserve the original scenario ordering and append only new names.
previousVariables = whos('-file', matFile);
previousScenarioNames = reshape(string({previousVariables(strcmp({previousVariables.class}, ...
    'Simulink.SimulationData.Dataset')).name}), [], 1);
selectedScenarioNames = labels(:);
% Compare new values against the existing MAT before touching the original.
% Time/value changes are allowed; datatype, signal dimensions and port/bus
% layout changes require a harness rebuild (and potentially recompilation).
compatibility = validateScenarioUpdate(string(matFile), scenarioData);
for k = 1:numel(previousScenarioNames)
    name = char(previousScenarioNames(k));
    if ~ismember(string(name), selectedScenarioNames)
        stored = load(matFile, name);
        scenarioData.(name) = stored.(name);
    end
end
labels = [previousScenarioNames; selectedScenarioNames(~ismember(selectedScenarioNames, previousScenarioNames))];
active = oldScenario;
if ~any(labels == string(active))
    active = char(labels(1));
end

% Stage and validate the full MAT contents before replacing the live file.
% The harness block Filename remains unchanged for both FR on and off.
staged = [tempname(folder) '.mat'];
cleanup = onCleanup(@() removeReloadBackup(staged)); %#ok<NASGU>
save(staged, '-struct', 'scenarioData');
checkSaved = whos('-file', staged);
savedMask = strcmp({checkSaved.class}, 'Simulink.SimulationData.Dataset');
savedNames = string({checkSaved(savedMask).name});
if ~all(ismember(labels, savedNames))
    error('BusHarness:StagedMAT', 'Staged MAT is missing one or more scenarios. Original MAT was not changed.');
end
matBackup = [tempname(folder) '.mat'];
backupReloadFile(matFile, matBackup);
try
    % Do not change Filename, ActiveScenario or other block/model parameters.
    % set_param during Fast Restart may fail or invalidate the initialized
    % model. Refreshing the MAT cache for the next simulation depends on
    % Signal Editor/Test Manager runtime; writing a file alone cannot
    % guarantee compiled-state reuse or an in-memory cache refresh.
    backupReloadFile(staged, matFile);
    checkWritten = whos('-file', matFile);
    writtenMask = strcmp({checkWritten.class}, 'Simulink.SimulationData.Dataset');
    writtenNames = string({checkWritten(writtenMask).name});
    if ~all(ismember(labels, writtenNames))
        error('BusHarness:MATVerification', 'Updated MAT is missing scenarios after writing.');
    end
    % Verify actual scenario values, not only variable names. A successful
    % disk check does NOT prove the initialized Signal Editor cache reloaded.
    for scenarioIndex = 1:numel(selectedScenarioNames)
        scenarioName = char(selectedScenarioNames(scenarioIndex));
        written = load(matFile, scenarioName);
        if ~isfield(written, scenarioName) || ...
                ~isequaln(written.(scenarioName), scenarioData.(scenarioName))
            error('BusHarness:MATVerification', ...
                'MAT verification failed for scenario "%s". The previous MAT will be restored.', ...
                scenarioName);
        end
    end
catch failure
    try
        backupReloadFile(matBackup, matFile);
    catch restoreFailure
        failure = addCause(failure, restoreFailure);
    end
    removeReloadBackup(matBackup);
    rethrow(failure);
end
removeReloadBackup(matBackup);
info = struct('ToolVersion', toolVersion, 'Harness', harness, 'HarnessFile', harnessFile, ...
    'ScenarioFile', matFile, 'SignalEditor', editor, 'ExcelFile', excelFile, ...
    'Scenarios', labels, 'ExpectedOutputs', [], ...
    'SmartRestartCompatible', compatibility.Compatible, ...
    'MatFileVerified', true, ...
    'SignalEditorCacheVerified', false, ...
    'SimulationStatusAtReload', string(reloadStatus), ...
    'AddedScenarios', compatibility.Added, 'UpdatedScenarios', compatibility.Updated);
end

function [updates, labels] = rebuildExistingMatScenarios(cases, matFile, template)
%REBUILDEXISTINGMATSCENARIOS Pure MAT/Excel data path: no model compilation.
% The saved Dataset is the authoritative port/bus schema for MAT-only reload.
% An unknown or ambiguous port/leaf is a structural change; reject it before
% overwriting the original file rather than touching the compiled hierarchy.
labels = harnessScenarioNames(string({cases.Name}));
updates = struct;
for c = 1:numel(cases)
    name = char(labels(c));
    saved = load(matFile, name);
    if ~isfield(saved, name)
        error('BusHarness:NewScenario', ...
            'Testcase "%s" does not exist in the MAT file. Use Load Testcase to Harness.', name);
    end
    dataset = saved.(name);
    if ~isa(dataset, 'Simulink.SimulationData.Dataset') || ...
            ~isequal(string(getElementNames(dataset)), string(getElementNames(template)))
        error('BusHarness:InterfaceChanged', ...
            'Testcase "%s" has a different Dataset interface. Use Load Testcase to Harness.', name);
    end
    portNames = string(getElementNames(dataset));
    rows = cases(c).Rows;
    for r = 1:numel(rows)
        row = rows(r);
        [portIndex, leafPath] = findMatLeaf(dataset, portNames, row);
        element = getElement(dataset, portIndex);
        if isa(element, 'Simulink.SimulationData.Signal')
            element.Values = replaceMatLeaf(element.Values, leafPath, row, cases(c));
        else
            element = replaceMatLeaf(element, leafPath, row, cases(c));
        end
        dataset = setElement(dataset, portIndex, element, char(portNames(portIndex)));
    end
    updates.(name) = dataset;
end
end

function [portIndex, leafPath] = findMatLeaf(dataset, names, row)
leafPath = string(row.Signal);
bus = string(row.Bus);
if startsWith(leafPath, bus + ".")
    leafPath = extractAfter(leafPath, bus + ".");
end
if leafPath == ""
    error('BusHarness:MATSignal', 'Excel row %d has an empty signal leaf.', row.Row);
end
isExpected = endsWith(names, "_Exp");
possible = false(numel(names), 1);
for n = 1:numel(names)
    if (row.Type == "O") ~= isExpected(n)
        continue
    end
    root = getElement(dataset, n);
    if isa(root, 'Simulink.SimulationData.Signal')
        root = root.Values;
    end
    possible(n) = hasMatLeaf(root, split(leafPath, "."));
end
matches = find(possible);
if isempty(matches)
    error('BusHarness:MATSignal', ...
        'Excel row %d: signal "%s" (bus "%s") is not in the existing MAT interface. Use Load Testcase to Harness.', ...
        row.Row, char(row.Signal), char(bus));
end
% Prefer the expected bus name, but never guess if two ports match.
expectedName = bus;
if row.Type == "O", expectedName = bus + "_Exp"; end
preferred = matches(names(matches) == expectedName);
if numel(preferred) == 1
    portIndex = preferred;
elseif numel(matches) == 1
    portIndex = matches;
else
    error('BusHarness:MATSignalAmbiguous', ...
        'Excel row %d: signal "%s" belongs to multiple MAT ports (%s). Use Load Testcase to Harness.', ...
        row.Row, char(row.Signal), char(strjoin(names(matches), ', ')));
end
end

function tf = hasMatLeaf(root, path)
tf = false;
for j = 1:numel(path)
    key = char(path(j));
    if ~isstruct(root) || ~isscalar(root) || ~isfield(root,key)
        return
    end
    root = root.(key);
end
tf = isa(root,'timeseries');
end

function value = replaceMatLeaf(value, path, row, testcase)
parts = split(path, ".");
key = char(parts(1));
if numel(parts) > 1
    value.(key) = replaceMatLeaf(value.(key), strjoin(parts(2:end), "."), row, testcase);
    return
end
ts = value.(key);
if ~isa(ts, 'timeseries')
    error('BusHarness:MATSignal', 'Excel row %d: "%s" is not an existing timeseries.', ...
        row.Row, char(path));
end
% Aggregate all Excel changes for this leaf, not just the currently visited
% row. This makes edited/removed time steps replace the previous waveform.
allRows = testcase.Rows;
matching = false(numel(allRows),1);
for i = 1:numel(allRows)
    candidate = allRows(i);
    candidatePath = string(candidate.Signal);
    if startsWith(candidatePath, string(candidate.Bus) + ".")
        candidatePath = extractAfter(candidatePath, string(candidate.Bus) + ".");
    end
    matching(i) = candidate.Type == row.Type && ...
        candidate.Bus == row.Bus && candidatePath == string(path);
end
changes = allRows(matching);
changeTimes = reshape([changes.Time], [], 1);
time = unique([0; changeTimes; double(testcase.DurationMs)/1000]);
if numel(time) == 1
    time(end+1,1) = time(1) + 1;
end
sample = getdatasamples(ts, 1);
if isvector(sample)
    data = repmat(reshape(sample,1,[]), numel(time), 1);
else
    data = repmat(sample, [ones(1,ndims(sample)), numel(time)]);
end
for i = 1:numel(changes)
    try
        newValue = excelValue(changes(i).Value, sample);
        validateSignalValueRange(newValue, sample);
        if numel(newValue) ~= 1 && numel(newValue) ~= numel(sample)
            error('BusHarness:ValueDimensions', ...
                'Expected %d element(s), received %d.',numel(sample),numel(newValue));
        end
        current = sample;
        current(:) = newValue;
    catch failure
        error('BusHarness:ExcelValue', ...
            'Testcase "%s", Excel row %d, signal "%s": %s', ...
            char(testcase.Name), changes(i).Row, char(path), failure.message);
    end
    first = find(time >= changes(i).Time, 1);
    if isvector(sample)
        data(first:end,:) = repmat(reshape(current,1,[]), numel(time)-first+1, 1);
    else
        indices = repmat({':'}, 1, ndims(sample)+1);
        indices{end} = first:numel(time);
        data(indices{:}) = repmat(current, [ones(1,ndims(sample)), numel(time)-first+1]);
    end
end
value.(key) = setinterpmethod(timeseries(data,time), 'zoh');
end

function backupReloadFile(source, destination)
[ok, message] = copyfile(source, destination, 'f');
if ~ok
    error('BusHarness:ReloadFile', 'Could not copy "%s" to "%s": %s', source, destination, message);
end
end

function [model, excelFile] = selectHarnessFiles(toolVersion)
model = "";
excelFile = "";
dialog = uifigure('Name', char("Create Harness from Excel | v" + toolVersion), ...
    'Position', [180 180 700 224], 'Resize', 'off');
dialog.CloseRequestFcn = @(~,~) uiresume(dialog);
grid = uigridlayout(dialog, [4 3]);
grid.RowHeight = {40, 32, 32, 38};
grid.ColumnWidth = {92, '1x', 108};
grid.Padding = [20 12 20 12];
grid.RowSpacing = 9;
title = uilabel(grid, 'Text', 'Select a Simulink model and a test case Excel file', ...
    'FontSize', 17, 'FontWeight', 'bold');
title.Layout.Row = 1;
title.Layout.Column = [1 3];
modelLabel = uilabel(grid, 'Text', 'Model');
modelLabel.Layout.Row = 2;
modelLabel.Layout.Column = 1;
modelField = uieditfield(grid, 'text', 'Placeholder', 'Path to a .slx or .mdl file');
modelField.Layout.Row = 2;
modelField.Layout.Column = 2;
modelBrowse = uibutton(grid, 'Text', 'Select Model', 'ButtonPushedFcn', ...
    @(~,~) browse(modelField, {'*.slx;*.mdl', 'Simulink (*.slx, *.mdl)'}));
modelBrowse.Layout.Row = 2;
modelBrowse.Layout.Column = 3;
excelLabel = uilabel(grid, 'Text', 'Excel');
excelLabel.Layout.Row = 3;
excelLabel.Layout.Column = 1;
excelField = uieditfield(grid, 'text', 'Placeholder', 'Path to a .xlsx, .xls, or .xlsm file');
excelField.Layout.Row = 3;
excelField.Layout.Column = 2;
excelBrowse = uibutton(grid, 'Text', 'Select Excel', 'ButtonPushedFcn', ...
    @(~,~) browse(excelField, {'*.xlsx;*.xls;*.xlsm', 'Excel (*.xlsx, *.xls, *.xlsm)'}));
excelBrowse.Layout.Row = 3;
excelBrowse.Layout.Column = 3;
cancel = uibutton(grid, 'Text', 'Cancel', 'ButtonPushedFcn', @(~,~) uiresume(dialog));
cancel.Layout.Row = 4;
cancel.Layout.Column = 1;
submit = uibutton(grid, 'Text', 'Create Harness', 'BackgroundColor', [0.10 0.31 0.57], ...
    'FontColor', [1 1 1], 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) accept());
submit.Layout.Row = 4;
submit.Layout.Column = 3;
uiwait(dialog);
if isvalid(dialog)
    delete(dialog);
end

    function browse(field, filter)
        [file, folder] = uigetfile(filter, 'Select File', pwd);
        if ~isequal(file, 0)
            field.Value = fullfile(folder, file);
        end
    end

    function accept()
        selectedModel = strtrim(string(modelField.Value));
        selectedExcel = strtrim(string(excelField.Value));
        [~,~,modelExt] = fileparts(selectedModel);
        [~,~,excelExt] = fileparts(selectedExcel);
        if ~isfile(selectedModel) || ~any(strcmpi(modelExt, [".slx", ".mdl"]))
            uialert(dialog, 'Select a .slx or .mdl model file.', 'Invalid Model');
            return
        end
        if ~isfile(selectedExcel) || ~any(strcmpi(excelExt, [".xlsx", ".xls", ".xlsm"]))
            uialert(dialog, 'Select a .xlsx, .xls, or .xlsm Excel file.', 'Invalid Excel File');
            return
        end
        model = selectedModel;
        excelFile = selectedExcel;
        uiresume(dialog);
    end
end

function [scenarioData, labels, editorNames, expectedNames, expectedTypes, ...
        expectedPorts, rules] = buildExcelScenarios(cases, inputs, outputs, busInputs, dictionary, designData)
expectedPorts = [];
inputPort = false(numel(inputs),1);
inputPort(busInputs) = true;
outputPort = startsWith(reshape(string({outputs.Type}), [], 1), "Bus:");
for c = 1:numel(cases)
    rows = cases(c).Rows;
    for k = 1:numel(rows)
        if rows(k).Type == "I"
            rows(k).Index = matchExcelBus(rows(k), inputs, inputPort);
        else
            rows(k).Index = matchExcelBus(rows(k), outputs, outputPort);
            expectedPorts(end+1) = rows(k).Index; %#ok<AGROW>
        end
    end
    cases(c).Rows = rows;
end
expectedPorts = unique(expectedPorts, 'sorted');
expectedTypes = reshape(string({outputs(expectedPorts).Type}), [], 1);
expectedNames = strtrim(extractAfter(expectedTypes, "Bus:")) + "_Exp";
expectedNames = string(matlab.lang.makeUniqueStrings(cellstr(expectedNames)));
expectedNames = expectedNames(:);
inputNames = reshape(string({inputs(busInputs).Name}), [], 1);
inputNames = matlab.lang.makeUniqueStrings(cellstr(inputNames), cellstr(expectedNames));
editorNames = [inputNames(:); cellstr(expectedNames)];
allPorts = [reshape(inputs(busInputs), [], 1); reshape(outputs(expectedPorts), [], 1)];
buses = cell(numel(allPorts),1);
ground = cell(numel(allPorts),1);
for k = 1:numel(allPorts)
    [buses{k}, ground{k}] = busGround(allPorts(k), dictionary, designData);
end
% Resolve output paths once before constructing the common verify list.
rules = struct('Port', {}, 'Signal', {}, 'Scalar', {});
ruleKeys = strings(0,1);
for c = 1:numel(cases)
    rows = cases(c).Rows;
    for k = reshape(find([rows.Type] == "O"), 1, [])
        outputIndex = find(expectedPorts == rows(k).Index, 1);
        [rows(k).Signal, sample] = validateExcelSignal(rows(k), ground{numel(busInputs)+outputIndex});
        key = string(rows(k).Index) + ":" + rows(k).Signal;
        if ~any(ruleKeys == key)
            ruleKeys(end+1,1) = key; %#ok<AGROW>
            rules(end+1) = struct('Port', rows(k).Index, ...
                'Signal', rows(k).Signal, 'Scalar', isscalar(sample)); %#ok<AGROW>
        end
    end
    cases(c).Rows = rows;
end
labels = harnessScenarioNames(string({cases.Name}));
scenarioData = struct;
for c = 1:numel(cases)
    rows = cases(c).Rows;
    time = unique([0; reshape([rows.Time], [], 1); cases(c).DurationMs / 1000]);
    if numel(time) == 1
        time(end+1,1) = 1;
    end
    scenario = Simulink.SimulationData.Dataset;
    for k = 1:numel(allPorts)
        if k <= numel(busInputs)
            updates = rows([rows.Type] == "I" & [rows.Index] == busInputs(k));
        else
            index = expectedPorts(k-numel(busInputs));
            updates = rows([rows.Type] == "O" & [rows.Index] == index);
        end
        for n = 1:numel(updates)
            updates(n).Signal = validateExcelSignal(updates(n), ground{k});
        end
        try
            values = busTimeseries(ground{k}, buses{k}, designData, allPorts(k).Block, time, updates, "");
        catch failure
            error('BusHarness:TestcaseValue', 'Testcase "%s": %s', ...
                char(cases(c).Name), failure.message);
        end
        scenario = addElement(scenario, values, editorNames{k});
    end
    scenarioData.(char(labels(c))) = scenario;
end
end

function configureOutputVerifies(assessment, ...
        rules, actualPorts, actualSymbols, expectedPorts, expectedSymbols, cases, runnables)
lines = strings(numel(rules),1);
for k = 1:numel(rules)
    rule = rules(k);
    actual = actualSymbols(actualPorts == rule.Port) + "." + rule.Signal;
    expected = expectedSymbols(expectedPorts == rule.Port) + "." + rule.Signal;
    comparison = actual + " == " + expected;
    if ~rule.Scalar
        comparison = "all(reshape(" + comparison + ", [], 1))";
    end
    lines(k) = "verify(" + comparison + ")";
end

% Library templates differ across Simulink releases. Install our own
% top-level step and remove the template steps from this new block.
steps = string(sltest.testsequence.findStep(assessment, 'Name', '.*', 'RegExp', 'on'));
roots = unique(regexprep(steps, '\..*$', ''), 'stable');
roots = roots(strlength(roots) > 0);
stepName = matlab.lang.makeUniqueStrings('VerifyOutputs', cellstr(roots), namelengthmax);
action = char(strjoin(lines, newline));
if isempty(roots)
    sltest.testsequence.addStep(assessment, stepName, 'Action', action);
else
    sltest.testsequence.addStepBefore(assessment, stepName, char(roots(1)), 'Action', action);
    for k = 1:numel(roots)
        sltest.testsequence.deleteStep(assessment, char(roots(k)));
    end
end
period = verifySampleTime(cases, runnables);
sltest.testsequence.setProperty(assessment, 'UpdateMethod', 'Discrete', ...
    'SampleTime', num2str(period, 17));
end

function period = verifySampleTime(cases, runnables)
% Use a common discrete interval for Excel changes and runnable schedules.
rows = vertcat(cases.Rows);
times = [rows.Time];
for k = 1:numel(runnables)
    times = [times, runnables(k).Rate]; %#ok<AGROW>
end
ticks = round(times(times > 0)*1e9);
ticks = unique(ticks(ticks > 0));
if isempty(ticks)
    period = 0.001;
    return
end
step = ticks(1);
for k = 2:numel(ticks)
    step = gcd(step, ticks(k));
end
period = step/1e9;
end

function index = matchExcelBus(row, ports, isBus)
names = reshape(string({ports.Name}), [], 1);
types = reshape(string({ports.Type}), [], 1);
matches = find(isBus & names == row.Bus);
if isempty(matches)
    matches = find(isBus & strtrim(erase(types, "Bus:")) == row.Bus);
end
if numel(matches) ~= 1
    error('BusHarness:ExcelBus', 'Excel row %d (%s): bus "%s" must match exactly one model port.', ...
        row.Row, char(row.Type), char(row.Bus));
end
index = matches(1);
end

function [path, value] = validateExcelSignal(row, bus)
path = row.Signal;
parts = split(path, ".");
if numel(parts) > 1 && parts(1) == row.Bus && ~isfield(bus, char(parts(1)))
    parts(1) = [];
    path = strjoin(parts, ".");
end
value = bus;
for k = 1:numel(parts)
    if ~isstruct(value) || ~isscalar(value) || ~isfield(value, char(parts(k)))
        error('BusHarness:ExcelSignal', 'Excel row %d: "%s" is not an element of bus "%s".', ...
            row.Row, char(row.Signal), char(row.Bus));
    end
    value = value.(char(parts(k)));
end
if isstruct(value)
    error('BusHarness:ExcelSignal', 'Excel row %d must name a leaf element, not a nested bus.', row.Row);
end
end

function [bus, ground] = busGround(port, dictionary, designData)
busName = char(strtrim(extractAfter(port.Type, "Bus:")));
bus = dictionaryBus(designData, string(busName));
scope = dictionary;
if isempty(bus)
    bus = slResolve(busName, port.Block);
    scope = [];
end
ground = Simulink.Bus.createMATLABStruct(busName, [], 1, scope);
end

function data = leafSamples(sample, element, time, updates, path)
if isstruct(updates) && ~isempty(element.Min) && element.Min > 0
    sample(:) = element.Min;
end
if isscalar(element.Dimensions)
    data = repmat(reshape(sample, 1, []), numel(time), 1);
else
    data = repmat(sample, [ones(1, numel(element.Dimensions)), numel(time)]);
end
if isempty(updates)
    return
end
updates = updates([updates.Signal] == path);
for k = 1:numel(updates)
    update = updates(k);
    try
        requested = excelValue(update.Value, sample);
        validateSignalValueRange(requested, sample);
        sample(:) = requested;
    catch failure
        error('BusHarness:ExcelValue', 'Excel row %d: invalid Value for "%s". %s', ...
            update.Row, char(path), failure.message);
    end
    from = find(time == update.Time, 1);
    if isscalar(element.Dimensions)
        data(from:end,:) = repmat(reshape(sample, 1, []), numel(time)-from+1, 1);
    else
        shape = [ones(1, numel(element.Dimensions)), numel(time)-from+1];
        indices = repmat({':'}, 1, numel(element.Dimensions));
        data(indices{:},from:end) = repmat(sample, shape);
    end
end
end

function value = excelValue(raw, sample)
%EXCELVALUE Accept literals and named variables from MATLAB Base Workspace.
% Read only single identifiers; never eval arbitrary Excel expressions.
text = string(excelText(raw));
if isstring(sample)
    % Preserve existing string-valued bus elements; resolve an existing
    % base-workspace string parameter when the user supplies its name.
    value = string(raw);
    if isvarname(char(text)) && evalin('base', sprintf('exist(''%s'',''var'')', char(text))) == 1
        value = resolveBaseValue(text);
        if ~(ischar(value) || isstring(value))
            error('BusHarness:ParameterType', ...
                'Parameter "%s" must contain text for a string signal.', char(text));
        end
        value = string(value);
    end
    return
end
number = str2double(text);
if isenum(sample)
    if isfinite(number) && isreal(number)
        value = feval(class(sample), number);
        return
    end
    [members, names] = enumeration(class(sample));
    match = find(strcmp(names, text));
    if numel(match) == 1
        value = members(match);
        return
    end
elseif islogical(sample) && any(strcmpi(text, ["true", "false"]))
    value = strcmpi(text, "true");
    return
elseif isfinite(number) && isreal(number)
    % Keep numeric literals uncast; validate the destination datatype before
    % assignment. E.g. Boolean=2 and uint8=256 must fail, not saturate.
    value = number;
    return
end
% For anything not recognized as a literal/enum member, interpret the
% Excel cell as a parameter NAME, not a MATLAB expression.
if ~isvarname(char(text))
    error('BusHarness:ExcelValueLiteral', ...
        'Value "%s" is neither a valid literal nor a Base Workspace parameter name.', char(text));
end
value = resolveBaseValue(text);
if isenum(sample)
    if isa(value, class(sample))
        % Already the correct enumeration type.
    elseif isnumeric(value) && isscalar(value) && isfinite(value) && isreal(value)
        value = feval(class(sample), double(value));
    else
        error('BusHarness:ParameterType', ...
            'Parameter "%s" must contain a compatible enum member or numeric value.', char(text));
    end
elseif islogical(sample)
    if ~(isnumeric(value) || islogical(value)) || ~isreal(value) || ...
            any(~isfinite(double(value(:)))) || any(~ismember(double(value(:)), [0, 1]))
        error('BusHarness:ParameterType', ...
            'Parameter "%s" must contain Boolean values (0 or 1).', char(text));
    end
    value = logical(value);
else
    if ~isnumeric(value) && ~islogical(value)
        error('BusHarness:ParameterType', ...
            'Parameter "%s" must contain numeric values for this signal.', char(text));
    end
    if ~isreal(value) || any(~isfinite(double(value(:))))
        error('BusHarness:ParameterType', ...
            'Parameter "%s" must contain finite real values.', char(text));
    end
end
if numel(value) ~= 1 && numel(value) ~= numel(sample)
    error('BusHarness:ParameterSize', ...
        'Parameter "%s" contains %d values, but the signal expects %d.', ...
        char(text), numel(value), numel(sample));
end
end

function validateSignalValueRange(value, sample)
% Reject out-of-range BEFORE assignment (integer/fi casts may saturate).
if isenum(sample)
    if ~isa(value,class(sample))
        error('BusHarness:ValueType','Value must belong to enum %s.',class(sample));
    end
    return
end
if isstring(sample) || ischar(sample), return; end
if ~(isnumeric(value) || islogical(value)) || ...
        ~isreal(value) || any(~isfinite(double(value(:))))
    error('BusHarness:ValueType','Value must be finite real numeric data.');
end
v = double(value(:));
if islogical(sample)
    lo = 0; hi = 1;
elseif isinteger(sample)
    lo = double(intmin(class(sample)));
    hi = double(intmax(class(sample)));
elseif isa(sample,'embedded.fi')
    lo = double(lowerbound(sample));
    hi = double(upperbound(sample));
elseif isa(sample,'single')
    lo = -double(realmax('single')); hi = double(realmax('single'));
elseif isa(sample,'double')
    lo = -realmax('double'); hi = realmax('double');
else
    % Unknown custom numeric types: do not silently cast unchecked data.
    error('BusHarness:ValueType', ...
        'Unsupported signal datatype %s for range validation.',class(sample));
end
if any(v<lo | v>hi)
    bad = v(find(v<lo | v>hi,1));
    error('BusHarness:ValueRange', ...
        'Value %.15g exceeds datatype %s range [%.15g, %.15g].', ...
        bad,class(sample),lo,hi);
end
if (isinteger(sample) || isa(sample,'embedded.fi')) && ...
        ~isa(sample,'embedded.fi') && any(v~=fix(v))
    error('BusHarness:ValueRange', ...
        'Datatype %s requires integer values; received %.15g.',class(sample),v(find(v~=fix(v),1)));
end
end

function value = resolveBaseValue(name)
% Resolve only MATLAB variable names to prevent evaluating Excel formulas.
identifier = char(name);
if evalin('base', sprintf('exist(''%s'',''var'')', identifier)) ~= 1
    error('BusHarness:MissingParameter', ...
        'Parameter "%s" does not exist in MATLAB Base Workspace.', identifier);
end
try
    value = evalin('base', identifier);
    if isa(value, 'Simulink.Parameter')
        value = value.Value;
    end
catch failure
    error('BusHarness:ParameterRead', ...
        'Cannot read parameter "%s" from Base Workspace: %s', identifier, failure.message);
end
if isempty(value)
    error('BusHarness:ParameterEmpty', ...
        'Parameter "%s" is empty in MATLAB Base Workspace.', identifier);
end
end

function sourceY = connectRunnables(harness, modelInports, inputs, runnablePorts, sourceY)
% Normalize a scalar period and [period 0] to the same schedule.
rates = zeros(numel(runnablePorts), 2);
for k = 1:numel(runnablePorts)
    rate = inputs(runnablePorts(k)).Rate;
    rates(k, 1:numel(rate)) = rate;
end
schedules = unique(rates, 'rows', 'stable');
for group = 1:size(schedules, 1)
    members = runnablePorts(all(rates == schedules(group, :), 2));
    generator = add_block('simulink/Ports & Subsystems/Function-Call Generator', ...
        sprintf('%s/Call_Rate_%d', harness, group), ...
        'Position', [65 sourceY 220 sourceY+30]);
    parameters = fieldnames(get_param(generator, 'DialogParameters'));
    rateParameter = parameters(strcmpi(parameters, 'sample_time') | ...
        strcmpi(parameters, 'sampleTime'));
    if isempty(rateParameter)
        error('BusHarness:GeneratorSampleTime', ...
            'Cannot identify the Function-Call Generator sample time parameter.');
    end
    set_param(generator, rateParameter{1}, mat2str(inputs(members(1)).Rate, 17));
    generatorPorts = get_param(generator, 'PortHandles');
    sourceY = splitRunnableCalls(harness, generatorPorts.Outport, ...
        modelInports(members), group, sourceY);
end
end

function nextY = splitRunnableCalls(harness, source, destinations, group, sourceY)
% Each split calls its top branch first. A chain also works on releases
% where a Function-Call Split only provides two outputs.
for branch = 1:numel(destinations)-1
    y = sourceY + 42*(branch-1);
    split = add_block('simulink/Ports & Subsystems/Function-Call Split', ...
        sprintf('%s/Split_Rate_%d_%d', harness, group, branch), ...
        'Position', [275 y 305 y+30]);
    splitPorts = get_param(split, 'PortHandles');
    add_line(harness, source, splitPorts.Inport(1), 'autorouting', 'on');
    add_line(harness, splitPorts.Outport(1), destinations(branch), 'autorouting', 'on');
    source = splitPorts.Outport(2);
end
add_line(harness, source, destinations(end), 'autorouting', 'on');
nextY = sourceY + max(55, 42*(numel(destinations)-1)+15);
end

function [inputs, outputs] = inspectSourceModel(model, designData)
feval(model, [], [], [], 'compile');
finish = onCleanup(@() feval(model, [], [], [], 'term')); %#ok<NASGU>
inputs = inspectPorts(model, 'Inport', designData);
outputs = inspectPorts(model, 'Outport', designData);
end

function ports = inspectPorts(model, direction, designData)
template = struct('Name', "", 'Type', "", 'Block', '', ...
    'Runnable', false, 'Rate', [], 'Adapt', false);
ports = repmat(template, 0, 1);
isInput = strcmp(direction, 'Inport');
blocks = find_system(model, 'SearchDepth', 1, 'BlockType', direction);
for index = 1:numel(blocks)
    block = blocks{index};
    number = str2double(get_param(block, 'Port'));
    if number <= numel(ports) && ~isempty(ports(number).Block)
        continue
    end
    port = template;
    port.Block = block;
    handles = get_param(block, 'PortHandles');
    compiled = get_param(block, 'CompiledPortDataTypes');
    if isInput
        handle = handles.Outport(1);
        raw = string(compiled.Outport{1});
    else
        handle = handles.Inport(1);
        raw = string(compiled.Inport{1});
    end
    parameters = get_param(block, 'ObjectParameters');
    isElement = isfield(parameters, 'IsBusElementPort') && ...
        strcmp(get_param(block, 'IsBusElementPort'), 'on');
    path = string(block);
    port.Name = string(get_param(block, 'Name'));
    if isElement
        port.Name = string(get_param(block, 'PortName'));
        path = string(model) + "/" + port.Name;
    end

    % The explicit runnable setting and compiled function-call type take
    % precedence over bus metadata and name matching.
    port.Runnable = isInput && (raw == "fcn_call" || ...
        (isfield(parameters, 'OutputFunctionCall') && ...
         strcmp(get_param(block, 'OutputFunctionCall'), 'on')));
    if port.Runnable
        port.Type = "fcn_call";
        port.Rate = runnableRate(block);
        ports(number, 1) = port;
        continue
    end

    declared = string(get_param(char(path), 'OutDataTypeStr'));
    compiledBus = any(string(get_param(handle, 'CompiledBusType')) == ...
        ["VIRTUAL_BUS", "NON_VIRTUAL_BUS"]);
    isLeaf = isElement && ~isempty(get_param(block, 'Element'));
    signalName = "";
    hierarchyBus = "";
    if ~isLeaf
        line = get_param(handle, 'Line');
        if line > 0
            signalName = string(get_param(line, 'Name'));
        end
        if compiledBus
            hierarchy = get_param(handle, 'SignalHierarchy');
            if isscalar(hierarchy) && isstruct(hierarchy) && isfield(hierarchy, 'BusObject')
                hierarchyBus = string(hierarchy.BusObject);
                if signalName == "" && isfield(hierarchy, 'SignalName')
                    signalName = string(hierarchy.SignalName);
                end
            end
        end
    end
    existingType = asBusType(declared, block);
    if existingType == "" && ~isLeaf
        existingType = asBusType(raw, block);
        if existingType == ""
            existingType = asBusType(hierarchyBus, block);
        end
    end
    candidates = unique([signalName, port.Name], 'stable');
    for candidate = candidates
        if ~isempty(dictionaryBus(designData, candidate))
            port.Name = candidate;
            port.Type = "Bus: " + candidate;
            break
        end
    end
    if port.Type == "" && existingType ~= ""
        port.Type = existingType;
    end
    if port.Type == ""
        if compiledBus || isLeaf
            error('BusHarness:MissingDictionaryBus', ...
                'Bus port %d (%s) needs a matching Simulink.Bus in the linked SLDD. Names checked: %s.', ...
                number, char(path), char(strjoin(candidates(candidates ~= ""), ", ")));
        end
        port.Type = raw;
    end
    port.Adapt = ~isInput && startsWith(port.Type, "Bus:") && port.Type ~= existingType;
    if existingType ~= "" && port.Adapt
        error('BusHarness:BusTypeMismatch', ...
            'Output "%s" already uses %s, while the dictionary name match gives %s.', ...
            char(path), char(existingType), char(port.Type));
    end
    ports(number, 1) = port;
end
end

function rate = runnableRate(block)
expression = get_param(block, 'SampleTime');
rate = str2double(expression);
if isnan(rate)
    try
        rate = slResolve(expression, block);
    catch failure
        error('BusHarness:RunnableSampleTime', ...
            'Cannot resolve Sample time "%s" on runnable "%s". %s', ...
            expression, block, failure.message);
    end
end
if isa(rate, 'Simulink.Parameter')
    rate = rate.Value;
end
if isequal(rate, -1) || isequal(rate, [-1 0])
    rate = get_param(block, 'CompiledSampleTime');
end
if ~isnumeric(rate) || ~isreal(rate) || ~isvector(rate) || ...
        isempty(rate) || numel(rate) > 2 || any(~isfinite(rate(:))) || rate(1) <= 0
    error('BusHarness:RunnableSampleTime', ...
        ['Runnable "%s" has Sample time "%s" and no positive periodic rate. ' ...
         'Set a discrete sample time on the source runnable Inport.'], block, expression);
end
rate = double(reshape(rate, 1, []));
end

function type = asBusType(candidate, block)
type = "";
candidate = strtrim(candidate);
if startsWith(candidate, "Bus:")
    name = strtrim(extractAfter(candidate, "Bus:"));
    if name ~= ""
        type = "Bus: " + name;
    end
elseif isvarname(candidate) && candidate ~= "auto"
    try
        object = slResolve(char(candidate), block);
        if isa(object, 'Simulink.Bus')
            type = "Bus: " + candidate;
        end
    catch
        % Built-in types and unresolved names are not named bus objects.
    end
end
end

function bus = dictionaryBus(designData, name)
bus = [];
if isempty(designData) || ~isvarname(name) || ~exist(designData, char(name))
    return
end
entries = getEntry(designData, char(name));
if numel(entries) ~= 1
    error('BusHarness:DuplicateDictionaryEntry', ...
        'The linked SLDD and its references contain multiple entries named "%s".', char(name));
end
value = getValue(entries);
if isa(value, 'Simulink.Bus')
    bus = value;
end
end

function values = busTimeseries(groundValues, bus, designData, context, time, updates, prefix)
if nargin == 5
    updates = [];
    prefix = "";
end
if ~isscalar(groundValues)
    error('BusHarness:BusArray', 'Arrays of buses are not supported by this scenario generator.');
end
values = struct;
for k = 1:numel(bus.Elements)
    element = bus.Elements(k);
    sample = groundValues.(element.Name);
    path = string(element.Name);
    if prefix ~= ""
        path = prefix + "." + path;
    end
    if isstruct(sample)
        nestedName = strtrim(erase(string(element.DataType), "Bus:"));
        nestedBus = dictionaryBus(designData, nestedName);
        if isempty(nestedBus)
            nestedBus = slResolve(char(nestedName), context);
        end
        values.(element.Name) = busTimeseries(sample, nestedBus, designData, context, time, updates, path);
    else
        data = leafSamples(sample, element, time, updates, path);
        values.(element.Name) = setinterpmethod(timeseries(data, time), 'zoh');
    end
end
end

function names = connectBusOutputs(harness, assessment, outputPorts, types, isBus, adaptOutput, signalNames)
busPorts = find(isBus);
names = strings(numel(busPorts),1);
for k = 1:numel(busPorts)
    portNumber = busPorts(k);
    baseName = matlab.lang.makeValidName(char(signalNames(portNumber)));
    if isempty(baseName)
        baseName = sprintf('OutBus_%d', portNumber);
    end
    existing = sltest.testsequence.findSymbol(assessment);
    name = matlab.lang.makeUniqueStrings(baseName, existing, namelengthmax);
    before = get_param(assessment, 'PortHandles');
    sltest.testsequence.addSymbol(assessment, name, 'Data', 'Input');
    sltest.testsequence.editSymbol(assessment, name, 'DataType', char(types(portNumber)));
    after = get_param(assessment, 'PortHandles');
    destination = setdiff(after.Inport, before.Inport, 'stable');
    if numel(destination) ~= 1
        error('BusHarness:AssessmentMapping', ...
            'Cannot identify the new Test Assessment input for model output %d.', portNumber);
    end
    source = outputPorts(portNumber);
    if adaptOutput(portNumber)
        position = get_param(source, 'Position');
        conversion = add_block('simulink/Signal Attributes/Signal Conversion', ...
            [harness '/' baseName '_Type'], 'MakeNameUnique', 'on', ...
            'ConversionOutput', 'Nonvirtual bus', 'OutDataTypeStr', char(types(portNumber)), ...
            'Position', [position(1)+45, position(2)-10, position(1)+85, position(2)+10]);
        conversionPorts = get_param(conversion, 'PortHandles');
        add_line(harness, source, conversionPorts.Inport, 'autorouting', 'on');
        source = conversionPorts.Outport;
    end
    add_line(harness, source, destination, 'autorouting', 'on');
    names(k) = string(name);
end
end

function text = excelText(value)
if isempty(value) || (isscalar(value) && ismissing(value))
    text = '';
else
    text = char(strtrim(string(value)));
end
end


function taken = harnessNameTaken(name, folder)
% Only actual harness model files inside the project's input folder reserve
% numeric suffixes. Ignore open block diagrams, MATLAB path copies and
% orphan *_Inputs.mat files from previously deleted harnesses.
taken = isfile(fullfile(folder, [name '.slx'])) || ...
    isfile(fullfile(folder, [name '.mdl']));
end
