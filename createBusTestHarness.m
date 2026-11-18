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

toolVersion = "1.2.52";
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

model = get_param(load_system(char(model)), 'Name');
if existingHarness ~= ""
    info = reloadSignalEditor(model, existingHarness, cases, excelFile, toolVersion);
    return
end
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
if bdIsLoaded(harness) && (~strcmpi(get_param(harness, 'FileName'), harnessFile) || ...
        strcmp(get_param(harness, 'Dirty'), 'on') || ...
        ~strcmp(get_param(harness, 'SimulationStatus'), 'stopped'))
    error('BusHarness:Reload', 'Save harness changes and stop simulation before reloading.');
end
load_system(harnessFile);
cut = [harness '/Model Under Test'];
editor = [harness '/Signal Editor'];
if getSimulinkBlockHandle(cut) < 0 || getSimulinkBlockHandle(editor) < 0 || ...
        ~strcmp(get_param(cut, 'ModelName'), model)
    error('BusHarness:Reload', 'The harness must have a Signal Editor and reference the selected model.');
end

dictionary = [];
designData = [];
dictionaryName = get_param(model, 'DataDictionary');
if ~isempty(dictionaryName)
    dictionary = Simulink.data.dictionary.open(dictionaryName);
    designData = getSection(dictionary, 'Design Data');
end
[inputs, outputs] = inspectSourceModel(model, designData);
busInputs = find(startsWith(string({inputs.Type}), "Bus:"));
[scenarioData, labels, editorNames] = buildExcelScenarios(cases, inputs, outputs, ...
    busInputs, dictionary, designData);

oldScenario = get_param(editor, 'ActiveScenario');
matFile = fullfile(folder, [harness '_Inputs.mat']);
if ~isfile(matFile)
    error('BusHarness:Reload', 'The harness Signal Editor MAT file is missing: %s', matFile);
end
previous = load(matFile, oldScenario);
if ~isfield(previous, oldScenario)
    error('BusHarness:Reload', 'The saved Signal Editor scenario "%s" is missing.', oldScenario);
end
existingNames = string(getElementNames(previous.(oldScenario)));
if ~isequal(existingNames(:), string(editorNames(:)))
    error('BusHarness:Reload', ...
        'The Excel files change the Signal Editor bus interface. Use Build Harness for this change.');
end
% Upsert selected Excel test cases by Signal Editor scenario name.
% Keep every unselected existing scenario untouched. A selected existing
% scenario is replaced with new Excel data; a selected new scenario is added.
% Preserve the original scenario ordering and append only new names.
previousVariables = whos('-file', matFile);
previousScenarioNames = reshape(string({previousVariables(strcmp({previousVariables.class}, ...
    'Simulink.SimulationData.Dataset')).name}), [], 1);
selectedScenarioNames = labels(:);
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

staged = [tempname(folder) '.mat'];
cleanup = onCleanup(@() removeReloadBackup(staged)); %#ok<NASGU>
save(staged, '-struct', 'scenarioData');
matBackup = [tempname(folder) '.mat'];
harnessBackup = [tempname(folder) '.slx'];
backupReloadFile(matFile, matBackup);
try
    backupReloadFile(harnessFile, harnessBackup);
catch failure
    removeReloadBackup(matBackup);
    rethrow(failure);
end
wasOpen = strcmp(get_param(harness, 'Open'), 'on');
try
    % Apply a different filename first so the block refreshes the scenario list.
    set_param(editor, 'Filename', staged);
    backupReloadFile(staged, matFile);
    set_param(editor, 'Filename', matFile);
    set_param(editor, 'ActiveScenario', active);
    save_system(harness);
catch failure
    try
        close_system(harness, 0);
        backupReloadFile(matBackup, matFile);
        backupReloadFile(harnessBackup, harnessFile);
        removeReloadBackup(matBackup);
        removeReloadBackup(harnessBackup);
        if wasOpen
            open_system(harnessFile);
        end
    catch restoreFailure
        failure = addCause(failure, restoreFailure);
    end
    rethrow(failure);
end
removeReloadBackup(matBackup);
removeReloadBackup(harnessBackup);
info = struct('ToolVersion', toolVersion, 'Harness', harness, 'HarnessFile', harnessFile, ...
    'ScenarioFile', matFile, 'SignalEditor', editor, 'ExcelFile', excelFile, ...
    'Scenarios', labels, 'ExpectedOutputs', []);
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
        values = busTimeseries(ground{k}, buses{k}, designData, allPorts(k).Block, time, updates, "");
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
        sample(:) = excelValue(update.Value, sample);
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
if isstring(sample)
    value = string(raw);
    return
end
text = string(excelText(raw));
value = str2double(text);
if isenum(sample)
    if isfinite(value) && isreal(value)
        value = feval(class(sample), value);
    else
        [members, names] = enumeration(class(sample));
        match = find(strcmp(names, text));
        if numel(match) ~= 1
            error('BusHarness:ExcelEnum', 'Expected an enumeration member name or numeric value.');
        end
        value = members(match);
    end
elseif islogical(sample) && any(strcmpi(text, ["true", "false", "0", "1"]))
    value = strcmpi(text, "true") || text == "1";
elseif ~isfinite(value) || ~isreal(value) || islogical(sample)
    error('BusHarness:ExcelNumber', 'Expected a finite real number or a Boolean for a logical element.');
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
