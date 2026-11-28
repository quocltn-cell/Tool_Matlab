function app = BusHarnessApp()
%BUSHARNESSAPP Open the graphical interface for the Excel-to-harness workflow.
%   Put BusHarnessApp.m and createBusTestHarness.m on the MATLAB path.
%   Open the MATLAB project containing the model and data dictionary first.
%   app = BusHarnessApp() returns the app figure handle.

navy = [0.08 0.16 0.26];
blue = [0.10 0.32 0.60];
paper = [0.96 0.97 0.99];
muted = [0.30 0.36 0.45];
lastInfo = [];
busy = false;
% The latest Test Manager result is valid only for this open project/run.
reportResult = [];
projectRoot = '';
modelPath = '';
excelPaths = {};
excelCases = struct('Name', {}, 'Rows', {}, 'DurationMs', {}, 'FirstRow', {}, 'LastRow', {});
commonPaths = {};
pendingCatalog = struct('Kind',{},'File',{},'Sheet',{},'Name',{});
projectFile = '';
project = emptyProject();
app = uifigure('Name', 'Simulink Testing', ...
    'Position', [110 110 1060 740], 'Color', paper, ...
    'CloseRequestFcn', @closeApp);
layout = uigridlayout(app, [3 1]);
layout.RowHeight = {66, 0, '1x'};
layout.Padding = [18 14 18 14];
layout.RowSpacing = 0;
layout.BackgroundColor = paper;

header = uipanel(layout, 'BackgroundColor', navy, 'BorderType', 'none');
headerGrid = uigridlayout(header, [1 2], 'ColumnWidth', {128, '1x'}, ...
    'Padding', [12 10 16 10], 'ColumnSpacing', 16, ...
    'BackgroundColor', navy);
menuButton = uibutton(headerGrid, 'Text', char("MENU  " + string(char(9662))), ...
    'FontSize', 17, 'FontWeight', 'bold', 'BackgroundColor', [0.16 0.39 0.69], ...
    'FontColor', [1 1 1], 'Tooltip', 'Show project commands', ...
    'ButtonPushedFcn', @showMenu);
uilabel(headerGrid, 'Text', 'Simulink Test Tool', ...
    'FontSize', 21, 'FontWeight', 'bold', 'FontColor', [1 1 1]);

tabs = uitabgroup(layout, 'Visible', 'off');
tabs.Layout.Row = 2;
settingTab = uitab(tabs, 'Title', 'Setting');
testTab = uitab(tabs, 'Title', 'Run Test');
dataTab = uitab(tabs, 'Title', 'Data');
dataViewer = testDataViewer(dataTab);
workspace = uigridlayout(settingTab, [4 1], 'RowHeight', {35, 235, '1x', 42}, ...
    'Padding', [0 10 0 0], 'RowSpacing', 10, 'BackgroundColor', paper);
projectLabel = uilabel(workspace, 'Text', 'No project open', 'FontColor', muted);

uipanelFiles = uipanel(workspace, 'Title', 'Model and Test Data', 'FontWeight', 'bold');
fileGrid = uigridlayout(uipanelFiles, [3 4], 'ColumnWidth', {130, '1x', 102, 102}, ...
    'RowHeight', {26, 90, 90}, 'Padding', [12 7 12 7], 'RowSpacing', 5);
uilabel(fileGrid, 'Text', 'Simulink Model');
modelField = uieditfield(fileGrid, 'text', 'Placeholder', '.slx or .mdl file', ...
    'Editable', 'off');
modelButton = uibutton(fileGrid, 'Text', 'Select Model', 'ButtonPushedFcn', @chooseModel);
openModelButton = uibutton(fileGrid, 'Text', 'Open Model', 'Tooltip', 'Open the selected model in Simulink', ...
    'ButtonPushedFcn', @openModel);
[excelList, openTestCaseButton] = workbookControls(2, 'Test Case Excel Files', 'Test Case', false);
[commonList, openCommonButton] = workbookControls(3, 'Test Common Files', 'Test Common', true);

logSplit = uigridlayout(workspace, [1 2], 'ColumnWidth', {'1x', '1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 10, 'BackgroundColor', paper);
pendingPanel = uipanel(logSplit, 'Title', 'testcase load', ...
    'FontWeight', 'bold');
pendingGrid = uigridlayout(pendingPanel, [2 1], 'RowHeight', {28, '1x'}, ...
    'Padding', [10 6 10 8], 'RowSpacing', 4);
pendingToolbar = uigridlayout(pendingGrid, [1 2], ...
    'ColumnWidth', {'1x', 100}, 'Padding', [0 0 0 0], 'ColumnSpacing', 6);
pendingCount = uilabel(pendingToolbar, 'Text', 'Add an Excel test case file to show available test cases.', ...
    'FontColor', muted);
pendingSelectAll = uibutton(pendingToolbar, 'Text', 'Select All', 'Enable', 'off', ...
    'ButtonPushedFcn', @(~, ~) toggleAllCases('pending'));
pendingList = uitable(pendingGrid, 'Data', emptyTestcaseTable(), ...
    'ColumnName', {'Import', 'Test Case'}, 'ColumnEditable', [true false], ...
    'ColumnWidth', {65, 'auto'}, 'RowName', {}, ...
    'CellEditCallback', @pendingSelectionChanged);

results = uipanel(logSplit, 'Title', 'Build Log' , 'FontWeight', 'bold');
resultsGrid = uigridlayout(results, [1 1], 'Padding', [10 6 10 10]);
buildLogArea = uitextarea(resultsGrid, 'Editable', 'off', ...
    'Value', {'Ready to build a harness.'});

actions = uigridlayout(workspace, [1 5], ...
    'ColumnWidth', {'1x', 126, 131, 194, 125}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 8, 'BackgroundColor', paper);
statusLabel = uilabel(actions, 'Text', 'Ready', 'FontColor', muted);
openButton = uibutton(actions, 'Text', 'Open Harness', ...
    'Tooltip', 'Open the latest harness, or choose an existing harness file', ...
    'ButtonPushedFcn', @openHarness);
refreshExcelButton = uibutton(actions, 'Text', 'Reload Testcase', ...
    'Tooltip', 'Refresh Excel testcases and automatically update compatible scenarios in the Signal Editor MAT', ...
    'ButtonPushedFcn', @reloadExcelPreview);
reloadButton = uibutton(actions, 'Text', 'Load Testcase to Harness', 'Enable', 'off', ...
    'Tooltip', 'Rebuild the harness when testcase signals, datatypes or bus interfaces change', ...
    'ButtonPushedFcn', @loadTestcaseToHarness);
buildButton = uibutton(actions, 'Text', 'Build Harness', 'BackgroundColor', blue, ...
    'FontColor', [1 1 1], 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) processHarness(false));

welcome = uigridlayout(layout, [3 5], 'RowHeight', {'1x', 44, '1x'}, ...
    'ColumnWidth', {'1x', 166, 32, 174, '1x'}, 'ColumnSpacing', 0, ...
    'Padding', [0 0 0 0], 'BackgroundColor', paper);
welcome.Layout.Row = 3;
newWelcome = uibutton(welcome, 'Text', 'New Project', 'FontSize', 21, ...
    'FontWeight', 'bold', 'FontColor', navy, 'BackgroundColor', paper, ...
    'ButtonPushedFcn', @(button, event) runWelcomeAction(button, event, @newProject));
newWelcome.Layout.Row = 2;
newWelcome.Layout.Column = 2;
separator = uilabel(welcome, 'Text', 'or', 'HorizontalAlignment', 'center', ...
    'FontSize', 18, 'FontColor', muted);
separator.Layout.Row = 2;
separator.Layout.Column = 3;
openWelcome = uibutton(welcome, 'Text', 'Open Project', 'FontSize', 21, ...
    'FontWeight', 'bold', 'FontColor', navy, 'BackgroundColor', paper, ...
    'ButtonPushedFcn', @(button, event) runWelcomeAction(button, event, @openProject));
openWelcome.Layout.Row = 2;
openWelcome.Layout.Column = 4;
testLayout = uigridlayout(testTab, [3 2], ...
    'RowHeight', {30, '1x', '1x'}, 'ColumnWidth', {'3x', '2x'}, ...
    'Padding', [12 12 12 12], 'RowSpacing', 10, 'BackgroundColor', paper);
testActions = uigridlayout(testLayout, [1 4], ...
    'ColumnWidth', {94, 94, 0, '1x'}, 'Padding', [0 0 0 0]);
testActions.Layout.Row = 1;
testActions.Layout.Column = [1 2];
runTestButton = uibutton(testActions, 'Text', 'Run Test', 'Enable', 'off', ...
    'BackgroundColor', blue, 'FontColor', [1 1 1], 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @runSelectedTests);
buildTestButton = uibutton(testActions, 'Text', 'Build Test', 'Enable', 'off', ...
    'ButtonPushedFcn', @buildTest);
% Hidden until the first completed Run Test in the current project.
genReportButton = uibutton(testActions, 'Text', 'Gen Report', 'Visible', 'off', ...
    'Enable', 'off', 'ButtonPushedFcn', @openReportDialog, ...
    'Tooltip', 'Configure and export the latest Test Manager results to project/output');
testcases = uipanel(testLayout, 'Title', 'Imported Test Cases', 'FontWeight', 'bold');
testcases.Layout.Row = [2 3];
testcases.Layout.Column = 1;
testcaseGrid = uigridlayout(testcases, [2 1], 'RowHeight', {28, '1x'}, ...
    'Padding', [10 6 10 10], 'RowSpacing', 5);
testcaseToolbar = uigridlayout(testcaseGrid, [1 2], ...
    'ColumnWidth', {'1x', 100}, 'Padding', [0 0 0 0], 'ColumnSpacing', 6);
testcaseCount = uilabel(testcaseToolbar, 'Text', 'Select an Excel file to import test cases.', ...
    'FontColor', muted);
testcaseSelectAll = uibutton(testcaseToolbar, 'Text', 'Select All', 'Enable', 'off', ...
    'ButtonPushedFcn', @(~, ~) toggleAllCases('imported'));
% Keep logical checkbox data for Run Test and scenario mapping.
% Visible scrollable rows have a real Open Harness button per testcase.
testcaseList = uitable(testcaseGrid, 'Data', emptyTestcaseTable(), ...
    'ColumnName', {'Select', 'Test Case'}, 'ColumnEditable', [true false], ...
    'ColumnWidth', {54, 'auto'}, 'RowName', {}, 'Visible', 'off');
testcaseList.Layout.Row = 2;
testcaseRows = uigridlayout(testcaseGrid,[1 3], ...
    'ColumnWidth',{35,'1x',118}, 'RowHeight',{30}, ...
    'Padding',[2 2 2 2], 'RowSpacing',3,'ColumnSpacing',5, ...
    'Scrollable','on');
testcaseRows.Layout.Row = 2;

runSettings = uipanel(testLayout, 'Title', 'Test Settings', 'FontWeight', 'bold');
runSettings.Layout.Row = 2;
runSettings.Layout.Column = 2;
runOptions = uigridlayout(runSettings, [4 1], 'RowHeight', {22, 26, 22, 0}, ...
    'Padding', [8 6 8 6], 'RowSpacing', 4, 'Scrollable', 'on');
fastRestart = uicheckbox(runOptions, 'Text', 'Fast Restart mode', ...
    'ValueChangedFcn', @onFastRestartChanged);
simulationOptions = uigridlayout(runOptions, [1 2], 'ColumnWidth', {112, '1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6);
uilabel(simulationOptions, 'Text', 'Simulation Mode');
simulationMode = uidropdown(simulationOptions, 'Items', ...
    {'Normal', 'Accelerator', 'Rapid Accelerator', ...
    'Software-in-the-Loop (SIL)', 'Processor-in-the-Loop (PIL)'}, 'Value', 'Normal');
coverageEnabled = uicheckbox(runOptions, 'Text', 'Enable Coverage', ...
    'ValueChangedFcn', @(~, ~) updateCoverageVisibility());
metricGrid = uigridlayout(runOptions, [5 2], 'RowHeight', {20, 20, 20, 20, 20}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 2, 'ColumnSpacing', 5, 'Visible', 'off');
metricLabels = {'Decision', 'Condition', 'MCDC', 'Lookup table', 'Signal range', ...
    'Signal size', 'Objectives and constraints', 'Integer overflow', 'Relational boundary'};
metricCodes = 'dcmtrzoib';
metricOptions = gobjects(1, numel(metricLabels));
for k = 1:numel(metricLabels)
    metricOptions(k) = uicheckbox(metricGrid, 'Text', metricLabels{k}, 'Value', k == 1);
end

testLog = uipanel(testLayout, 'Title', 'Run Log', 'FontWeight', 'bold');
testLog.Layout.Row = 3;
testLog.Layout.Column = 2;
testLogLayout = uigridlayout(testLog, [1 1], 'Padding', [10 6 10 10]);
testMessages = uitextarea(testLogLayout, 'Editable', 'off');

% Create the menu panels after the main layout so they appear above it.
menuPanel = uipanel(app, 'Visible', 'off', 'BorderType', 'none');
projectButton = uibutton(menuPanel, 'Text', ['Project  ' char(9656)], ...
    'BackgroundColor', paper, 'FontColor', navy, 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @showProjectMenu);
projectPanel = uipanel(app, 'Visible', 'off', 'BorderType', 'none');
projectGrid = uigridlayout(projectPanel, [4 1], 'RowHeight', {30, 30, 30, 30}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 0, 'BackgroundColor', paper);
addProjectCommand('New Project', @newProject, 'on');
addProjectCommand('Open Project', @openProject, 'on');
saveProjectItem = addProjectCommand('Save Project', @saveProject, 'off');
closeProjectItem = addProjectCommand('Close Project', @closeProject, 'off');
app.WindowButtonMotionFcn = @hoverProjectMenu;
app.WindowButtonDownFcn = @dismissOutsideMenu;
app.SizeChangedFcn = @(~, ~) hideMenu();
updateProjectView();

    function updateProjectView()
        if isempty(projectRoot)
            tabs.Visible = 'off';
            tabs.SelectedTab = settingTab;
            layout.RowHeight = {66, 0, '1x'};
            welcome.Visible = 'on';
        else
            welcome.Visible = 'off';
            layout.RowHeight = {66, '1x', 0};
            tabs.Visible = 'on';
        end
    end

    function runWelcomeAction(button, event, action)
        button.FontColor = blue;
        button.BackgroundColor = [0.86 0.91 0.98];
        restore = onCleanup(@() resetWelcomeButton(button)); %#ok<NASGU>
        drawnow nocallbacks;
        action(button, event);
    end

    function resetWelcomeButton(button)
        if isvalid(button)
            button.FontColor = navy;
            button.BackgroundColor = paper;
        end
    end

    function showMenu(~, ~)
        if strcmp(menuPanel.Visible, 'on')
            hideMenu();
            return
        end
        position = getpixelposition(menuButton, true);
        menuHeight = 34;
        menuPanel.Position = [position(1), position(2) - menuHeight, position(3), menuHeight];
        projectButton.Position = [1, 1, position(3), menuHeight];
        menuPanel.Visible = 'on';
    end

    function showProjectMenu(~, ~)
        if strcmp(menuPanel.Visible, 'on')
            bounds = menuPanel.Position;
            projectPanel.Position = [bounds(1) + bounds(3), bounds(2) + bounds(4) - 120, 145, 120];
            projectPanel.Visible = 'on';
        end
    end

    function hoverProjectMenu(~, ~)
        if strcmp(menuPanel.Visible, 'on') && pointerInside(menuPanel.Position)
            showProjectMenu([], []);
        end
    end

    function dismissOutsideMenu(~, ~)
        if strcmp(menuPanel.Visible, 'on') && ...
                ~pointerInside(getpixelposition(menuButton, true)) && ...
                ~pointerInside(menuPanel.Position) && ...
                ~(strcmp(projectPanel.Visible, 'on') && pointerInside(projectPanel.Position))
            hideMenu();
        end
    end

    function inside = pointerInside(bounds)
        point = reshape(app.CurrentPoint, 1, []);
        inside = all(point >= bounds(1:2) & point <= bounds(1:2) + bounds(3:4));
    end

    function hideMenu()
        menuPanel.Visible = 'off';
        projectPanel.Visible = 'off';
    end

    function button = addProjectCommand(label, action, enabled)
        button = uibutton(projectGrid, 'Text', label, 'Enable', enabled, ...
            'BackgroundColor', paper, 'FontColor', navy, ...
            'ButtonPushedFcn', @(source, event) runProjectCommand(source, event, action));
    end

    function runProjectCommand(source, event, action)
        hideMenu();
        action(source, event);
    end

    function newProject(~, ~)
        [name, root] = uiputfile({'*.prj', 'Simulink Testing project (*.prj)'}, ...
            'New Project', fullfile(pwd, 'project.prj'));
        if isequal(name, 0)
            return
        end
        [~, stem, extension] = fileparts(name);
        if isempty(extension)
            name = [name '.prj'];
            extension = '.prj';
        end
        if isempty(stem) || any(strcmp(stem, {'.','..'})) || ~strcmpi(extension, '.prj')
            uialert(app, 'Enter a project filename ending in .prj.', 'New Project');
            return
        end
        root = fullfile(root, stem);
        file = fullfile(root, name);
        try
            if isfolder(root) || isfile(root)
                error('BusHarnessApp:ProjectExists', ...
                    'The project folder already exists. Choose another project name or location.');
            end
            if ~saveSelection()
                return
            end
            makeFolder(fullfile(root, 'input'));
            makeFolder(fullfile(root, 'output'));
            data = emptyProject();
            writeProject(file, data);
            showProject(root, data, file);

        catch failure
            uialert(app, failure.message, 'Could Not Create Project');
        end
    end

    function openProject(~, ~)
        [name, root] = uigetfile({'*.prj;project.json', 'Simulink Testing projects (*.prj, project.json)'}, ...
            'Open Project', pwd);
        if isequal(name, 0)
            return
        end
        loadProject(root, name);
    end

    function loadProject(root, name)
        try
            if ~saveSelection()
                return
            end
            if strcmpi(name, 'project.json')
                existingProjects = projectFiles(root);
                if numel(existingProjects) > 1
                    error('BusHarnessApp:ProjectSelection', ...
                        'This folder contains multiple .prj files. Select one using Open Project.');
                end
                name = 'project.json';
                if ~isempty(existingProjects)
                    name = existingProjects(1).name;
                end
            end
            [~, ~, extension] = fileparts(name);
            if ~strcmpi(extension, '.prj') && ~strcmpi(name, 'project.json')
                error('BusHarnessApp:ProjectFormat', 'Select a .prj file or project.json.');
            end
            file = fullfile(root, name);
            data = readProject(file);
            if strcmpi(name, 'project.json')
                file = fullfile(root, 'project.prj');
                writeProject(file, data);
            end
            makeFolder(fullfile(root, 'input'));
            makeFolder(fullfile(root, 'output'));
            showProject(root, data, file);
        catch failure
            uialert(app, failure.message, 'Could Not Open Project');
        end
    end

    function closeProject(~, ~)
        if busy || isempty(projectRoot)
            return
        end
        choice = uiconfirm(app, 'Save the current project before closing?', 'Close Project', ...
            'Options', {'Save', 'Don''t Save', 'Cancel'}, 'DefaultOption', 1, 'CancelOption', 3);
        switch choice
            case 'Save'
                if ~saveSelection(true)
                    return
                end
            case 'Don''t Save'
                % Close without writing the project file again.
            otherwise
                return
        end
        showProject('', emptyProject(), '');
    end

    function showProject(root, data, file)
        projectRoot = root;
        projectFile = file;
        project = data;
        lastInfo = [];
        reportResult = [];
        testcaseList.Data = emptyTestcaseTable();
        renderRunTestcaseRows();
        pendingList.Data = emptyTestcaseTable();
        testMessages.Value = {''};
        fastRestart.Value = false;
        simulationMode.Value = 'Normal';
        coverageEnabled.Value = false;
        for k = 1:numel(metricOptions)
            metricOptions(k).Value = k == 1;
        end
        updateCoverageVisibility();
        modelPath = data.ModelFile;
        modelField.Value = fileLabel(modelPath);
        setExcelFiles(cellfun(@(path) testcasePath(root, path), ...
            data.TestCaseFiles, 'UniformOutput', false), false);
        setExcelFiles(data.CommonFiles, true);
        statusLabel.Text = 'Ready';
        buildLogArea.Value = {'Ready to build a harness.'};
        projectLabel.Text = 'No project open';
        if ~isempty(root)
            [~, projectName] = fileparts(projectFile);
            projectLabel.Text = ['Project: ' projectName];

        end
        updateProjectView();
        setBusy(false);
        readTestcaseNames();
    end

    function saveProject(~, ~)
        if ~busy && ~isempty(projectRoot) && saveSelection(true)
            statusLabel.Text = 'Project saved';

        end
    end

    function ok = saveSelection(forceWrite)
        if nargin == 0
            forceWrite = false;
        end
        ok = true;
        if isempty(projectRoot)
            return
        end
        data = project;
        try
            data.ModelFile = modelPath;
            data.TestCaseFiles = excelPaths;
            data.CommonFiles = commonPaths;
            if forceWrite || ~isequal(data, project) || ~isfile(projectFile)
                writeProject(projectFile, data);
                project = data;
            end
        catch failure
            ok = false;
            uialert(app, sprintf('%s\n\nProject file: %s', failure.message, projectFile), ...
                'Could Not Save Project');
        end
    end

    function folder = harnessPickerFolder()
        folder = pwd;
        if ~isempty(projectRoot)
            folder = fullfile(projectRoot, 'input');
        end
    end

    function chooseModel(~, ~)
        [name, folder] = uigetfile({'*.slx;*.mdl', 'Model Simulink (*.slx, *.mdl)'}, ...
            'Select Model', pwd);
        if ~isequal(name, 0)
            modelPath = fullfile(folder, name);
            modelField.Value = name;
            saveSelection();
        end
    end

    function [list, openFile] = workbookControls(row, label, actionLabel, isCommon)
        heading = uilabel(fileGrid, 'Text', label);
        heading.Layout.Row = row;
        heading.Layout.Column = 1;
        list = uilistbox(fileGrid, 'Items', {}, 'Multiselect', 'on');
        list.Layout.Row = row;
        list.Layout.Column = 2;
        controls = uigridlayout(fileGrid, [2 2], 'RowHeight', {35, 32}, ...
            'Padding', [0 0 0 0], 'RowSpacing', 5);
        controls.Layout.Row = row;
        controls.Layout.Column = [3 4];
        uiimage(controls, 'ImageSource', roundActionIcon([0.07 0.49 0.25], true, controls.BackgroundColor), ...
            'Tooltip', ['Add ' label], 'ImageClickedFcn', @(~, ~) chooseExcel(label, isCommon));
        uiimage(controls, 'ImageSource', roundActionIcon([0.73 0.13 0.18], false, controls.BackgroundColor), ...
            'Tooltip', 'Remove selected files', 'ImageClickedFcn', @(~, ~) removeExcel(isCommon));
        openFile = uibutton(controls, 'Text', ['Open ' actionLabel], ...
            'ButtonPushedFcn', @(~, ~) openWorkbook(isCommon));
        openFile.Layout.Row = 2;
        openFile.Layout.Column = [1 2];
    end

    function [list, paths] = workbookList(isCommon)
        if isCommon
            list = commonList;
            paths = commonPaths;
        else
            list = excelList;
            paths = excelPaths;
        end
    end

    function chooseExcel(label, isCommon)
        if busy
            return
        end
        [names, folder] = uigetfile({'*.xlsx;*.xls;*.xlsm', 'Excel files'}, ...
            ['Select ' label], pwd, 'MultiSelect', 'on');
        if isequal(names, 0)
            return
        end
        [~, paths] = workbookList(isCommon);
        added = cellstr(fullfile(string(folder), string(names)));
        updateExcelFiles(unique([paths(:); added(:)], 'stable'), isCommon);
    end

    function removeExcel(isCommon)
        if busy
            return
        end
        [list, paths] = workbookList(isCommon);
        selected = list.Value;
        if ~isempty(selected)
            paths(selected) = [];
            updateExcelFiles(paths, isCommon);
        end
    end

    function updateExcelFiles(files, isCommon)
        [list, previous] = workbookList(isCommon);
        selection = list.Value;
        setExcelFiles(files, isCommon);
        if ~saveSelection()
            setExcelFiles(previous, isCommon);
            list.Value = selection;
        end
        readTestcaseNames();
    end

    function setExcelFiles(files, isCommon)
        [list, ~] = workbookList(isCommon);
        files = reshape(files, 1, []);
        if isCommon
            commonPaths = files;
        else
            excelPaths = files;
        end
        list.Value = {};
        list.ItemsData = [];
        list.Items = cellfun(@fileLabel, files, 'UniformOutput', false);
        list.ItemsData = 1:numel(files);
        list.Value = {};
    end

    function openModel(~, ~)
        try
            file = modelPath;
            requireFile(file, [".slx", ".mdl"], 'model');
            open_system(char(file));
        catch failure
            uialert(app, failure.message, 'Could Not Open Model');
        end
    end

    function openWorkbook(isCommon)
        try
            [list, paths] = workbookList(isCommon);
            selected = list.Value;
            if numel(selected) ~= 1
                error('BusHarnessApp:ExcelSelection', 'Select one Excel file in the list to open.');
            end
            file = paths{selected(1)};
            requireFile(file, [".xlsx", ".xls", ".xlsm"], 'Excel');
            if ispc
                winopen(char(file));
            else
                open(char(file));
            end
        catch failure
            uialert(app, failure.message, 'Could Not Open Excel File');
        end
    end

    function imported = importedScenarioNames()
        imported = strings(0,1);
        if isempty(projectRoot) || isempty(project.ScenarioFile)
            return
        end
        file = fullfile(projectRoot, project.ScenarioFile);
        if ~isfile(file)
            return
        end
        try
            variables = whos('-file', file);
            imported = reshape(string({variables(strcmp({variables.class}, ...
                'Simulink.SimulationData.Dataset')).name}), [], 1);
        catch failure
            % Keep incidental preview warnings out of Build Log.
        end
    end

    function [caseCount, previewError] = readTestcaseNames()
        caseCount = 0;
        previewError = "";
        dataViewer.setExcelInputs(excelPaths,commonPaths);
        previousRun = testcaseList.Data;
        selectedRun = previousRun.TestCase(previousRun.Selected);
        previousPending = pendingList.Data;
        previousCatalog = pendingCatalog;
        pendingCatalog = struct('Kind',{},'File',{},'Sheet',{},'Name',{});
        if isempty(excelPaths)
            testcaseList.Data = emptyTestcaseTable();
            renderRunTestcaseRows();
            pendingList.Data = emptyTestcaseTable();
            testcaseCount.Text = 'Select an Excel file to import test cases.';
            pendingCount.Text = 'No Excel test cases loaded.';
            refreshSelectAllButtons();
            return
        end
        try
            [names, entries] = readHarnessExcelNames(excelPaths);
            caseCount = numel(names);
            imported = importedScenarioNames();
            alreadyLoaded = ismember(harnessScenarioNames(names), imported);
            current = unique(names(alreadyLoaded),'stable');
            testcaseList.Data = table(ismember(current, selectedRun), current, ...
                'VariableNames', {'Selected', 'TestCase'});
            renderRunTestcaseRows();
            visible = strings(0,1);
            checked = false(0,1);
            % Display a hierarchical list: File -> Sheet -> Testcase.
            for file = reshape(string(excelPaths),1,[])
                if ~any(string({entries.File}) == file), continue; end
                [~,base,ext] = fileparts(file);
                [visible,checked] = addPendingRow('File',file,"","", "[FILE] " + string(base)+string(ext), visible,checked,previousCatalog,previousPending);
                sheets = unique(string({entries(string({entries.File}) == file).Sheet}),'stable');
                for sheet = reshape(sheets,1,[])
                    [visible,checked] = addPendingRow('Sheet',file,sheet,"", "    [SHEET] " + sheet, visible,checked,previousCatalog,previousPending);
                    for entry = entries
                        if entry.File ~= file || entry.Sheet ~= sheet, continue; end
                        [visible,checked] = addPendingRow('Case',file,sheet,entry.Name, "        " + entry.Name, visible,checked,previousCatalog,previousPending);
                    end
                end
            end
            % Parents are checked iff all descendant cases are checked.
            for j = numel(pendingCatalog):-1:1
                if ~strcmp(pendingCatalog(j).Kind,'Case')
                    children = childIndexes(j);
                    checked(j) = ~isempty(children) && all(checked(children));
                end
            end
            pendingList.Data = table(checked, visible, ...
                'VariableNames',{'Selected','TestCase'});
            testcaseCount.Text = sprintf('%d imported test case(s)', numel(current));
            duplicateNames = unique(names(arrayfun(@(j) nnz(strcmpi(names,names(j)))>1, 1:numel(names))));
            if isempty(duplicateNames)
                pendingCount.Text = sprintf('%d Excel test cases in %d workbook(s); select file/sheet/case.', ...
                    numel(names), numel(excelPaths));
            else
                pendingCount.Text = sprintf('%d cases; DUPLICATE names: %s. Build Log will show details.', ...
                    numel(names), char(strjoin(duplicateNames,', ')));
            end
            refreshSelectAllButtons();
        catch failure
            previewError = string(failure.message);
            pendingList.Data = emptyTestcaseTable();
            testcaseList.Data = emptyTestcaseTable();
            renderRunTestcaseRows();
            pendingCount.Text = ['Excel preview failed: ' failure.message];
            testcaseCount.Text = 'Could not preview Excel test cases.';
            refreshSelectAllButtons();
        end

    end

    function reloadExcelPreview(~, ~)
        % A lightweight Excel refresh automatically updates existing MAT
        % scenarios. Do not change the harness or create new scenarios here.
        if busy, return; end
        try
            if isempty(excelPaths)
                error('BusHarnessApp:ExcelSelection', ...
                    'Add at least one testcase Excel file before reloading.');
            end
            [count, failureText] = readTestcaseNames();
            if strlength(failureText) > 0
                error('BusHarnessApp:ExcelPreview', '%s', char(failureText));
            end
            harnessFile = string(savedHarnessFile());
            if harnessFile == "" || ~isfile(harnessFile)
                buildLogArea.Value = {'Reload Testcase Successful'; ...
                    sprintf('Excel testcase(s) displayed: %d',count); ...
                    'No harness exists yet: MAT unchanged. Use Build Harness first.'};
                statusLabel.Text = 'Excel testcase list refreshed';
                return
            end
            % Auto-update all existing scenarios irrespective of checkbox
            % state. Checkbox selections are for full harness operations.
            processHarness(true, true);
        catch failure
            buildLogArea.Value = {'Reload Testcase Failed'; ...
                ['Error: ' failure.message]};
            statusLabel.Text = 'Reload Testcase failed';
        end
    end

    function loadTestcaseToHarness(~, ~)
        % Structural changes require a deliberate harness rebuild. This
        % invalidates initialized Fast Restart and previous Test Manager
        % iterations; never do so through the lightweight Reload button.
        if busy, return; end
        choice = uiconfirm(app, ...
            ['Load Testcase to Harness rebuilds the harness from ALL Excel testcases. ' ...
             'This may invalidate Fast Restart compiled state. ' ...
             'After rebuilding, use Build Test to update Test Manager iterations. Continue?'], ...
            'Rebuild Harness from Testcases', ...
            'Options',{'Rebuild','Cancel'},'DefaultOption','Cancel', ...
            'CancelOption','Cancel');
        if strcmp(choice,'Rebuild')
            processHarness(false, true);
        end
    end

    function [visible,checked] = addPendingRow(kind,file,sheet,name,label, ...
            visible,checked,previousCatalog,previousPending)
        idx = numel(pendingCatalog)+1;
        pendingCatalog(idx) = struct('Kind',kind,'File',file, ...
            'Sheet',sheet,'Name',name);
        visible(end+1,1) = label;
        checked(end+1,1) = true;
        if ~strcmp(kind,'Case'), return; end
        for old = 1:numel(previousCatalog)
            if strcmp(previousCatalog(old).Kind,'Case') && ...
                    previousCatalog(old).File == file && ...
                    previousCatalog(old).Sheet == sheet && ...
                    previousCatalog(old).Name == name && ...
                    old <= height(previousPending)
                checked(idx) = previousPending.Selected(old);
                break
            end
        end
    end

    function ids = childIndexes(index)
        ids = zeros(0,1);
        if isempty(pendingCatalog) || index > numel(pendingCatalog), return; end
        parent = pendingCatalog(index);
        for j = 1:numel(pendingCatalog)
            x = pendingCatalog(j);
            if ~strcmp(x.Kind,'Case') || x.File ~= parent.File, continue; end
            if strcmp(parent.Kind,'File') || ...
                    (strcmp(parent.Kind,'Sheet') && x.Sheet == parent.Sheet)
                ids(end+1,1) = j; %#ok<AGROW>
            end
        end
    end

    function pendingSelectionChanged(~,event)
        if busy, return; end
        rows = pendingList.Data;
        if isempty(rows) || isempty(event.Indices), return; end
        idx = event.Indices(1);
        if idx > numel(pendingCatalog), return; end
        if ~strcmp(pendingCatalog(idx).Kind,'Case')
            children = childIndexes(idx);
            rows.Selected(children) = logical(event.NewData);
        end
        for j = numel(pendingCatalog):-1:1
            if ~strcmp(pendingCatalog(j).Kind,'Case')
                children = childIndexes(j);
                rows.Selected(j) = ~isempty(children) && all(rows.Selected(children));
            end
        end
        pendingList.Data = rows;
        refreshSelectAllButtons();
    end

    function toggleAllCases(whichList)
        % Toggle only the checkbox column, without changing testcase names.
        if busy
            return
        end
        if strcmp(whichList, 'pending')
            tbl = pendingList;
        else
            tbl = testcaseList;
        end
        rows = tbl.Data;
        if isempty(rows) || height(rows) == 0
            return
        end
        newValue = ~all(rows.Selected);
        rows.Selected(:) = newValue;
        tbl.Data = rows;
        if strcmp(whichList, 'imported')
            renderRunTestcaseRows();
        end
        refreshSelectAllButtons();
    end

    function renderRunTestcaseRows()
        % Keep a real button beside each imported scenario.
        if ~isvalid(testcaseRows), return; end
        delete(testcaseRows.Children);
        rows = testcaseList.Data;
        count = height(rows);
        testcaseRows.RowHeight = repmat({30},1,max(1,count));
        if count == 0
            emptyLabel = uilabel(testcaseRows,'Text','No imported testcases.', ...
                'FontColor',muted);
            emptyLabel.Layout.Row = 1; emptyLabel.Layout.Column = [1 3];
            return
        end
        for idx = 1:count
            tick = uicheckbox(testcaseRows,'Text','', ...
                'Value',logical(rows.Selected(idx)), ...
                'Enable',matlab.lang.OnOffSwitchState(~busy), ...
                'ValueChangedFcn',@(src,~) onRunCaseChecked(idx,src.Value));
            tick.Layout.Row = idx; tick.Layout.Column = 1;
            nameLabel = uilabel(testcaseRows,'Text',char(rows.TestCase(idx)), ...
                'Tooltip',char(rows.TestCase(idx)));
            nameLabel.Layout.Row = idx; nameLabel.Layout.Column = 2;
            openCase = uibutton(testcaseRows,'Text','Open Harness', ...
                'Enable',matlab.lang.OnOffSwitchState(~busy), ...
                'Tooltip','Open harness with this testcase active in Signal Editor', ...
                'ButtonPushedFcn',@(~,~) openHarnessForTestcase(rows.TestCase(idx)));
            openCase.Layout.Row = idx; openCase.Layout.Column = 3;
        end
    end

    function onRunCaseChecked(idx,value)
        if busy, return; end
        rows = testcaseList.Data;
        if idx < 1 || idx > height(rows), return; end
        rows.Selected(idx) = logical(value);
        testcaseList.Data = rows;
        refreshSelectAllButtons();
    end

    function refreshSelectAllButtons()
        % Keep both controls in sync with individual checkbox edits.
        updateSelectAllButton(pendingSelectAll, pendingList.Data);
        updateSelectAllButton(testcaseSelectAll, testcaseList.Data);
    end

    function updateSelectAllButton(btn, rows)
        if isempty(rows) || height(rows) == 0
            btn.Text = 'Select All';
            btn.Enable = 'off';
        else
            if all(rows.Selected)
                btn.Text = 'Deselect All';
            else
                btn.Text = 'Select All';
            end
            btn.Enable = matlab.lang.OnOffSwitchState(~busy);
        end
    end

    function appendLog(lines)
        lines = string(lines);
        buildLogArea.Value = [string(buildLogArea.Value(:)); lines(:)];
    end

    function processHarness(reload, updateAll)
        if nargin < 2
            updateAll = false;
        end
        if busy
            return
        end
        % Reset Build Log for each button press; no paths/version/debug text.
        if reload
            operation = "Reload Testcase";
        elseif updateAll
            operation = "Load Testcase to Harness";
        else
            operation = "Build Harness";
        end
        selected = strings(0,1);
        try
            rows = pendingList.Data;
            if numel(pendingCatalog) == height(rows)
                mask = rows.Selected & strcmp({pendingCatalog.Kind}', 'Case');
                selected = string({pendingCatalog(mask).Name})';
            end
        catch
        end
        if reload && updateAll
            % Update all existing MAT scenarios, but never add scenarios or
            % silently modify the interface through the fast reload path.
            currentMatNames = importedScenarioNames();
            try
                [excelNames, ~] = readHarnessExcelNames(excelPaths);
                excelNames = reshape(string(excelNames),[],1);
                availableNames = harnessScenarioNames(excelNames);
                selected = excelNames(ismember(availableNames,currentMatNames));
            catch failure
                buildLogArea.Value = {'Reload Testcase Failed'; ...
                    ['Error: ' failure.message]};
                statusLabel.Text = 'Reload Testcase failed';
                return
            end
        elseif ~reload && updateAll
            % A structural rebuild must preserve every Excel testcase;
            % never discard unchecked scenarios during reconstruction.
            try
                [selected, ~] = readHarnessExcelNames(excelPaths);
                selected = reshape(string(selected),[],1);
            catch failure
                buildLogArea.Value = {'Load Testcase to Harness Failed'; ...
                    ['Error: ' failure.message]};
                statusLabel.Text = 'Load Testcase to Harness failed';
                return
            end
        end
        total = numel(selected);
        buildLogArea.Value = {char(operation + " in progress...")};
        drawnow;
        setBusy(true);
        cleanup = onCleanup(@() setBusy(false)); %#ok<NASGU>
        try
            if ~saveSelection()
                error('BusHarnessApp:SaveSelection', 'Could not save the project selection.');
            end
            model = string(modelPath);
            excel = string(excelPaths);
            requireFile(model, [".slx", ".mdl"], 'model');
            if isempty(excel)
                error('BusHarnessApp:ExcelSelection', 'Add at least one testcase Excel file.');
            end
            for f = [reshape(excel,1,[]), reshape(string(commonPaths),1,[])]
                requireFile(f, [".xlsx", ".xls", ".xlsm"], 'Excel');
            end
            if total == 0
                error('BusHarnessApp:ImportSelection', 'No compatible existing testcase is available for this operation. Build Harness or use Load Testcase to Harness.');
            end
            if isempty(which('createBusTestHarness'))
                error('BusHarnessApp:ToolMissing', 'createBusTestHarness.m is not on the MATLAB path.');
            end
            outputFolder = pwd;
            if ~isempty(projectRoot)
                outputFolder = fullfile(projectRoot, 'input');
                if ~isfolder(outputFolder)
                    makeFolder(outputFolder);
                end
            end
            % Load to Harness updates the existing Signal Editor MAT file; Build Harness
            % rebuilds the ONLY generated harness for the selected model.
            existingHarness = string(savedHarnessFile());
            if reload && (existingHarness == "" || ~isfile(existingHarness))
                error('BusHarnessApp:MissingHarness', ...
                    'No existing harness found. Use Build Harness first.');
            end
            [allCases, merged] = readHarnessExcel(excel, commonPaths);
            allNames = reshape(string({allCases.Name}),[],1);
            if ~all(ismember(selected,allNames))
                error('BusHarnessApp:ImportSelection', ...
                    'The Excel testcase list has changed. Refresh the selection.');
            end
            % Keep one predictable merged workbook for the whole project.
            % Each source sheet remains a separate worksheet in this file.
            mergedFile = writeMergedWorkbook(merged, selected, outputFolder, excel);
            mergedPaths = string(mergedFile);
            if reload
                info = createBusTestHarness(model, "", mergedPaths, outputFolder, "", existingHarness);
            else
                info = buildSingleHarness(model, mergedPaths, outputFolder);
            end
            % Remove only files generated by the previous merge naming
            % scheme, and only after the harness/MAT operation succeeds.
            removeLegacyMergedWorkbooks(merged, outputFolder, mergedFile);
            lastInfo = info;
            if ~isempty(projectRoot)
                [~, stem, extension] = fileparts(info.HarnessFile);
                project.HarnessName = info.Harness;
                [~, harnessFolder] = fileparts(fileparts(info.HarnessFile));
                project.HarnessFile = [harnessFolder '/' stem extension];
                project.ToolVersion = char(info.ToolVersion);
                if ~isempty(info.ScenarioFile)
                    [~, stem, extension] = fileparts(info.ScenarioFile);
                    project.ScenarioFile = [harnessFolder '/' stem extension];
                else
                    project.ScenarioFile = '';
                end
                writeProject(projectFile, project);
            end
            if reload
                buildLogArea.Value = {'Reload Testcase Successful'; ...
                    sprintf('MAT scenarios updated: %d', total); ...
                    'Harness model: unchanged'; ...
                    'Fast Restart setting: unchanged'; ...
                    ['SimulationStatus at reload: ' char(info.SimulationStatusAtReload)]; ...
                    'MAT values verified on disk. Signal Editor runtime cache not verified.'; ...
                    'Check the next Run Test output to confirm the updated Value is used.'};
                [excelNames, ~] = readHarnessExcelNames(excelPaths);
                addedExcel = reshape(string(excelNames),[],1);
                addedExcel = addedExcel(~ismember(addedExcel,selected));
                if ~isempty(addedExcel)
                    buildLogArea.Value = [buildLogArea.Value; ...
                        {sprintf('%d new Excel testcase(s) not imported into MAT. Use Load Testcase to Harness.',numel(addedExcel))}];
                end
            elseif updateAll
                buildLogArea.Value = {'Load Testcase to Harness Successful'; ...
                    sprintf('Harness rebuilt with %d testcase(s)',total); ...
                    'Use Build Test to refresh Test Manager iterations.'};
            else
                buildLogArea.Value = {'Build Harness Successful'; ...
                    char(sprintf('Testcase import successful: %d', total)); ...
                    'Testcase import fail: 0'};
            end
            statusLabel.Text = char(operation + " successful");
            if reload && isfield(info,'AddedScenarios') && ~isempty(info.AddedScenarios)
                % New MAT scenarios need corresponding Test Manager iterations.
                % Do not silently run old iterations with an updated MAT list.
                buildLogArea.Value = [buildLogArea.Value; ...
                    {'New scenario added. Use Build Test to update iterations.'}];
            end
            readTestcaseNames();
            % Test results/plots refer to the previous MAT data and become
            % stale after either a MAT update or a full harness rebuild.
            dataViewer.clear();
            reportResult = [];
            updateReportButton();
        catch failure
            % Current implementation imports the selected testcases as one
            % atomic batch. On failure it does not claim partial successes.
            if reload
                buildLogArea.Value = {'Reload Testcase Failed'; ...
                    'MAT update successful: 0'; ...
                    char(sprintf('MAT update fail: %d', total)); ...
                    ['Error: ' failure.message]};
            else
                buildLogArea.Value = {char(operation + " Failed"); ...
                    'Testcase import successful: 0'; ...
                    char(sprintf('Testcase import fail: %d', total)); ...
                    ['Error: ' failure.message]};
            end
            statusLabel.Text = char(operation + " failed");
        end
    end

    function buildTest(~, ~)
        if busy
            return
        end
        setBusy(true);
        cleanup = onCleanup(@() setBusy(false)); %#ok<NASGU>
        stage = 'reading Signal Editor scenarios';
        tempFolder = '';
        backupFolder = '';
        originalFiles = {};
        backupFiles = {};
        destination = '';
        newInstalled = false;
        try
            [harness, model, active, scenarios] = testHarnessScenarios(savedHarnessFile());
            scenarios = strtrim(string(scenarios(:)));
            if isempty(scenarios) || any(ismissing(scenarios)) || any(strlength(scenarios) == 0)
                error('BusHarnessApp:EmptyTestName', ...
                    'Signal Editor contains an empty scenario name.');
            end
            keys = lower(scenarios);
            [~, ~, group] = unique(keys, 'stable');
            counts = accumarray(group, 1);
            duplicateNames = scenarios(ismember(group, find(counts > 1)));
            if ~isempty(duplicateNames)
                error('BusHarnessApp:DuplicateIterationName', ...
                    'Duplicate Signal Editor scenario names: %s', ...
                    strjoin(cellstr(unique(duplicateNames, 'stable')), ', '));
            end
            if ~any(scenarios == string(active))
                error('BusHarnessApp:ActiveScenario', ...
                    'The active Signal Editor scenario is not in the available scenarios.');
            end
            folder = fullfile(projectRoot, 'output');
            if ~isfolder(folder)
                makeFolder(folder);
            end
            destination = fullfile(folder, [model '_Tests.mldatx']);
            % A project owns one MLDATX in output, never a numbered copy.
            existing = dir(fullfile(folder, '*.mldatx'));
            existing = existing(~[existing.isdir]);
            originalFiles = fullfile(folder, {existing.name});
            if ~isempty(originalFiles)
                choice = uiconfirm(app, ...
                    sprintf(['This project already contains %d Test Manager file(s).\n' ...
                    'Build Test will replace them with one file:\n%s\n\n' ...
                    'Replace the existing test file(s)?'], ...
                    numel(originalFiles), [model '_Tests.mldatx']), ...
                    'Replace Test Manager File', ...
                    'Options', {'Replace', 'Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
                if ~strcmp(choice, 'Replace')
                    testMessages.Value = {'Build Test Cancelled'; ...
                        'Existing Test Manager file was not changed.'};
                    return
                end
            end
            testMessages.Value = {'Building Test Manager file...'};
            drawnow;
            % Build outside the project so a failed build cannot damage the
            % existing MLDATX and output/ never accumulates _2/_3 copies.
            tempFolder = tempname;
            [ok, message] = mkdir(tempFolder);
            if ~ok
                error('BusHarnessApp:TemporaryFolder', ...
                    'Cannot create a temporary Build Test folder: %s', message);
            end
            temporaryFile = fullfile(tempFolder, [model '_Tests.mldatx']);
            stage = 'creating temporary Test Manager file';
            tf = sltest.testmanager.TestFile(temporaryFile);
            stage = 'removing default Test Manager suite';
            initialSuites = getTestSuites(tf);
            for k = numel(initialSuites):-1:1
                remove(initialSuites(k));
            end
            stage = 'creating test suite';
            suite = createTestSuite(tf, [model '_TestSuite']);
            stage = 'creating simulation test case';
            tc = createTestCase(suite, 'simulation', model);
            stage = 'configuring test case';
            setProperty(tc, 'Model', harness, 'SimulationMode', 'Normal', ...
                'UseSignalEditorScenarios', true, 'SignalEditorScenario', char(active));
            for k = 1:numel(scenarios)
                scenario = scenarios(k);
                stage = ['adding iteration "' char(scenario) '"'];
                iteration = sltestiteration;
                setTestParam(iteration, 'SignalEditorScenario', char(scenario));
                addIteration(tc, iteration, char(scenario));
            end
            stage = 'saving temporary Test Manager file';
            saveToFile(tf);
            % Close the temporary Test Manager handle after saving. This
            % prevents MATLAB from keeping the temporary pathname active.
            close(tf);
            if ~isfile(temporaryFile)
                error('BusHarnessApp:MissingTestFile', ...
                    'The temporary Test Manager file was not saved.');
            end
            stage = 'replacing existing Test Manager file';
            backupFolder = tempname;
            [ok, message] = mkdir(backupFolder);
            if ~ok
                error('BusHarnessApp:BackupFolder', ...
                    'Cannot create the backup folder: %s', message);
            end
            % Close only the project-owned Test Manager files. Do not clear
            % unrelated Test Manager files from the MATLAB session.
            for k = 1:numel(originalFiles)
                oldTest = sltest.testmanager.TestFile(originalFiles{k});
                close(oldTest);
            end
            for k = 1:numel(originalFiles)
                [~, name, ext] = fileparts(originalFiles{k});
                backup = fullfile(backupFolder, [name ext]);
                [ok, message] = movefile(originalFiles{k}, backup);
                if ~ok
                    error('BusHarnessApp:BackupTestFile', ...
                        'Cannot back up %s: %s', originalFiles{k}, message);
                end
                backupFiles{end+1} = backup; %#ok<AGROW>
            end
            [ok, message] = movefile(temporaryFile, destination);
            if ~ok
                error('BusHarnessApp:InstallTestFile', ...
                    'Cannot install the new Test Manager file: %s', message);
            end
            newInstalled = true;
            stage = 'saving project Test Manager path';
            data = project;
            data.TestManagerFile = ['output/' model '_Tests.mldatx'];
            writeProject(projectFile, data);
            project = data;
            % The previous test results belong to the replaced MLDATX.
            reportResult = [];
            updateReportButton();
            % Old test files are deleted only after both build and project
            % metadata update succeed. Everything else is left untouched.
            if isfolder(backupFolder)
                % Backup cleanup is best effort: a successful project save
                % must not be rolled back because a temp folder is locked.
                try
                    rmdir(backupFolder, 's');
                    backupFolder = '';
                catch
                end
            end
            testMessages.Value = { ...
                'Build Test Successful'; ...
                sprintf('Test iterations created: %d', numel(scenarios))};
        catch failure
            % Restore the exact previous MLDATX files if replacement or
            % project-metadata saving fails. Do not silently lose backups.
            restorationErrors = {};
            if newInstalled && isfile(destination)
                try
                    delete(destination);
                catch rollbackError
                    restorationErrors{end+1} = rollbackError.message; %#ok<AGROW>
                end
            end
            for k = 1:numel(backupFiles)
                if isfile(backupFiles{k})
                    [ok, message] = movefile(backupFiles{k}, originalFiles{k});
                    if ~ok
                        restorationErrors{end+1} = message; %#ok<AGROW>
                    end
                end
            end
            if ~isempty(backupFolder) && isfolder(backupFolder) && isempty(restorationErrors)
                rmdir(backupFolder, 's');
            end
            lines = {'Build Test Failed'; ['Step: ' stage]; ['Error: ' failure.message]};
            if ~isempty(restorationErrors)
                lines{end+1} = ['Restore warning: ' strjoin(restorationErrors, '; ')];
                lines{end+1} = ['Backup folder: ' backupFolder];
            end
            testMessages.Value = lines;
        end
        if ~isempty(tempFolder) && isfolder(tempFolder)
            try
                rmdir(tempFolder, 's');
            catch
                % Do not change the Build Test result because of temp cleanup.
            end
        end
    end

    function runSelectedTests(~, ~)
        if busy
            return
        end
        rows = testcaseList.Data;
        if ~any(rows.Selected)
            uialert(app, 'Tick at least one test case.', 'Run Test');
            return
        end
        setBusy(true);
        cleanup = onCleanup(@() setBusy(false)); %#ok<NASGU>
        reportResult = [];
        updateReportButton();
        testMessages.Value = {'Preparing selected iterations...'};
        drawnow;
        try
            [harness, model, ~, scenarios] = testHarnessScenarios(savedHarnessFile());
            names = harnessScenarioNames(rows.TestCase);
            selected = names(rows.Selected);
            if ~isequal(sort(names), sort(scenarios))
                error('BusHarnessApp:TestScenarios', ...
                    'The imported test list differs from Signal Editor. Refresh Excel or rebuild the harness.');
            end
            file = fullfile(projectRoot, project.TestManagerFile);
            requireFile(file, ".mldatx", 'Test Manager file');
            tf = sltest.testmanager.TestFile(file);
            suite = getTestSuiteByName(tf, [model '_TestSuite']);
            if isempty(suite)
                error('BusHarnessApp:TestSuite', 'The test suite is missing. Use Build Test.');
            end
            tc = getTestCaseByName(suite, model);
            if isempty(tc) || ~strcmp(getProperty(tc, 'Model'), harness)
                error('BusHarnessApp:TestModel', 'The test file targets a different harness. Use Build Test.');
            end
            iterations = getIterations(tc);
            iterationNames = strings(numel(iterations), 1);
            for k = 1:numel(iterations)
                iterationNames(k) = string(iterations(k).Name);
            end
            if ~isequal(sort(iterationNames), sort(scenarios))
                error('BusHarnessApp:TestIterations', 'The scenario list changed. Use Build Test to update the iterations.');
            end
            % Validate that the MAT linked to Signal Editor actually has
            % every selected scenario before running. Scenario changes are
            % applied by Test Manager iterations; this preflight does not
            % claim compilation reuse across independent run(tc) calls.
            verifyHarnessMatBeforeRun(savedHarnessFile(), selected);
            if logical(fastRestart.Value)
                appendTestLog("Smart Fast Restart: MAT scenarios verified; " + ...
                    "compiled-state reuse is controlled by Simulink Test Manager.");
            end
            % Log model output ports for the Data/Output inspector.
            try
                enableHarnessOutputLogging(harness);
            catch loggingFailure
                appendTestLog("Output logging warning: " + string(loggingFailure.message));
            end
            % Ensure Test Manager does not disable model-marked signal logging.
            % Without this, getOutputRuns may legitimately contain no model data.
            try
                setProperty(tc,'SignalLogging',true);
            catch loggingSettingError
                appendTestLog("Model signal logging setting warning: " + ...
                    string(loggingSettingError.message));
            end
            % Explicitly request Model Under Test output ports in Test Manager,
            % not only line-level SignalLogging in the harness.
            try
                configureOutputLoggingForTest(tc,harness);
            catch outputConfigureError
                appendTestLog("Output capture configuration warning: " + ...
                    string(outputConfigureError.message));
            end
            applyRunSettings(tf, tc, harness);
            wasEnabled = false(size(iterations));
            for k = 1:numel(iterations)
                wasEnabled(k) = logical(iterations(k).Enabled);
            end
            restore = onCleanup(@() enableIterations(iterations, wasEnabled)); %#ok<NASGU>
            enableIterations(iterations, ismember(iterationNames, selected));
            % Keep one progress row and update it as iteration results arrive.
            % run(tc) is synchronous: actual simulation completes before MATLAB
            % can report individual iteration outcomes through this UI.
            totalCount = numel(selected);
            appendTestLog("Running: 0/" + string(totalCount));
            progressRow = numel(testMessages.Value);
            drawnow;
            result = run(tc);
            latestReportResult = result;
            if isa(result, 'sltest.testmanager.ResultSet')
                result = getTestCaseResults(result);
            end
            passedCount = 0;
            failedCount = 0;
            incompleteCount = 0;
            disabledCount = 0;
            unknownCount = 0;
            processedCount = 0;
            for k = 1:numel(result)
                details = getIterationResults(result(k));
                for j = 1:numel(details)
                    % TestIterationResult.Name is supported across releases.
                    iterationLabel = string(details(j).Name);
                    if strlength(strtrim(iterationLabel)) == 0
                        iterationLabel = "Iteration " + string(j);
                    end
                    iterationStatus = iterationOutcomeText(details(j).Outcome);
                    appendTestLog(iterationLabel + ": " + iterationStatus);
                    switch lower(strtrim(iterationStatus))
                        case "passed"
                            passedCount = passedCount + 1;
                        case "failed"
                            failedCount = failedCount + 1;
                        case "incomplete"
                            incompleteCount = incompleteCount + 1;
                        case "disabled"
                            disabledCount = disabledCount + 1;
                        otherwise
                            unknownCount = unknownCount + 1;
                    end
                    if iterationStatus == "Failed"
                        try
                            errorLines = string(details(j).ErrorMessages);
                            errorLines = errorLines(strlength(strtrim(errorLines)) > 0);
                            for m = 1:numel(errorLines)
                                appendTestLog("  Error: " + errorLines(m));
                            end
                        catch
                            % Optional diagnostic property varies by release.
                        end
                    end
                    processedCount = processedCount + 1;
                    % The count represents results processed, not live
                    % simulation progress (run(tc) is a blocking call).
                    updateTestLogLine(progressRow, "Running: " + ...
                        string(min(processedCount, totalCount)) + "/" + string(totalCount));
                    drawnow;
                end
            end
            if processedCount < totalCount
                incompleteCount = incompleteCount + (totalCount - processedCount);
                appendTestLog("Warning: Missing results for " + ...
                    string(totalCount - processedCount) + " selected iteration(s).");
            end
            summary = "Test Result: " + string(passedCount) + " Pass | " + ...
                string(failedCount) + " Fail";
            if incompleteCount > 0
                summary = summary + " | " + string(incompleteCount) + " Incomplete";
            end
            if disabledCount > 0
                summary = summary + " | " + string(disabledCount) + " Disabled";
            end
            if unknownCount > 0
                summary = summary + " | " + string(unknownCount) + " Unknown";
            end
            appendTestLog(summary);
            % Only completed runs have reportable Test Manager results.
            if processedCount > 0
                reportResult = latestReportResult;
            end
            updateReportButton();
            % Populate the Data inspector from actual iteration results.
            try
                recorded = collectDataResults(result, selected);
                scenarioPath = fullfile(projectRoot,project.ScenarioFile);
                % Prefer the MAT actually attached to the Signal Editor.
                try
                    [~,harnessName] = fileparts(harness);
                    linkedFile = get_param([harnessName '/Signal Editor'],'Filename');
                    if isfile(linkedFile), scenarioPath = linkedFile; end
                catch
                end
                % Keep all selected testcases visible even on MATLAB releases
                % which do not expose per-iteration SDI output runs.
                existing = string({recorded.Name});
                for selectedName = reshape(string(selected),1,[])
                    if ~any(existing == selectedName)
                        recorded(end+1,1) = struct('Name',char(selectedName), ...
                            'Status','Unknown', ...
                            'Signals',struct('Name',{},'Time',{},'Data',{}), ...
                            'Diagnostic','No Test Manager iteration result for this testcase.'); %#ok<AGROW>
                    end
                end
                for recordedIndex=1:numel(recorded)
                    if isempty(recorded(recordedIndex).Signals)
                        appendTestLog("Output Model missing [" + ...
                            string(recorded(recordedIndex).Name) + "]: " + ...
                            string(recorded(recordedIndex).Diagnostic));
                    end
                end
                dataViewer.setResults(recorded, scenarioPath, modelSampleTime(harness));
            catch dataFailure
                appendTestLog("Data viewer: " + string(dataFailure.message));
            end
        catch failure
            appendTestLog("Run Test failed: " + string(failure.message));
        end
    end

    function updateReportButton()
        % Do not show the action until this project has completed a run.
        available = ~isempty(reportResult) && ~isempty(projectRoot);
        genReportButton.Visible = matlab.lang.OnOffSwitchState(available);
        genReportButton.Enable = matlab.lang.OnOffSwitchState(available && ~busy);
        if available
            testActions.ColumnWidth = {94, 94, 110, '1x'};
        else
            testActions.ColumnWidth = {94, 94, 0, '1x'};
        end
    end

    function openReportDialog(~, ~)
        if busy || isempty(reportResult) || isempty(projectRoot)
            return
        end
        % The native Test Manager Report dialog is not exposed by a
        % documented public MATLAB API. This dialog uses the supported
        % sltest.testmanager.report() API with equivalent common options.
        dlg = uifigure('Name', 'Generate Test Report', ...
            'Position', [280 180 500 510], 'Resize', 'off', ...
            'WindowStyle', 'modal');
        grid = uigridlayout(dlg, [11 2], ...
            'RowHeight', {30,30,30,30,30,30,30,30,30,'1x',38}, ...
            'ColumnWidth', {173,'1x'}, 'RowSpacing', 7, ...
            'Padding', [16 13 16 14]);
        uilabel(grid, 'Text', 'File format');
        format = uidropdown(grid, 'Items', {'PDF (.pdf)', 'Word (.docx)', 'HTML archive (.zip)'}, ...
            'Value', 'PDF (.pdf)');
        uilabel(grid, 'Text', 'Include test results');
        included = uidropdown(grid, 'Items', {'All results', 'Passed only', 'Failed only'}, ...
            'Value', 'All results');
        uilabel(grid, 'Text', 'Report title');
        titleField = uieditfield(grid, 'text', 'Value', 'Simulink Test Results');
        uilabel(grid, 'Text', 'Author');
        authorField = uieditfield(grid, 'text', 'Value', '');
        uilabel(grid, 'Text', 'Simulation signal plots');
        signalPlots = uicheckbox(grid, 'Text', 'Include', 'Value', false);
        uilabel(grid, 'Text', 'Comparison signal plots');
        comparisonPlots = uicheckbox(grid, 'Text', 'Include', 'Value', true);
        uilabel(grid, 'Text', 'Error messages');
        errorMessages = uicheckbox(grid, 'Text', 'Include', 'Value', true);
        uilabel(grid, 'Text', 'Coverage results');
        coverageResults = uicheckbox(grid, 'Text', 'Include (if recorded)', 'Value', false);
        uilabel(grid, 'Text', 'Open after generating');
        launchReport = uicheckbox(grid, 'Text', 'Yes', 'Value', true);
        note = uilabel(grid, 'Text', ['Output folder: ' fullfile(projectRoot, 'output')], ...
            'WordWrap', 'on', 'FontColor', muted);
        note.Layout.Row = 10;
        note.Layout.Column = [1 2];
        buttons = uigridlayout(grid, [1 3], ...
            'ColumnWidth', {'1x',110,110}, 'Padding', [0 0 0 0]);
        buttons.Layout.Row = 11;
        buttons.Layout.Column = [1 2];
        uibutton(buttons, 'Text', 'Open Test Manager', ...
            'ButtonPushedFcn', @(~,~) sltest.testmanager.view);
        uibutton(buttons, 'Text', 'Cancel', ...
            'ButtonPushedFcn', @(~,~) delete(dlg));
        uibutton(buttons, 'Text', 'Generate', 'BackgroundColor', blue, ...
            'FontColor', [1 1 1], 'ButtonPushedFcn', @generateReport);

        function generateReport(~, ~)
            if busy || isempty(reportResult) || ~isvalid(dlg)
                return
            end
            formats = {'.pdf', '.docx', '.zip'};
            formatNames = {'PDF (.pdf)', 'Word (.docx)', 'HTML archive (.zip)'};
            ext = formats{strcmp(format.Value, formatNames)};
            resultLabels = {'All results','Passed only','Failed only'};
            idx = find(strcmp(included.Value, resultLabels), 1, 'first') - 1;
            [~, projectName] = fileparts(projectFile);
            if isempty(projectName)
                projectName = 'SimulinkTest';
            end
            destinationFolder = fullfile(projectRoot, 'output');
            if ~isfolder(destinationFolder)
                mkdir(destinationFolder);
            end
            filePath = fullfile(destinationFolder, [projectName '_TestReport' ext]);
            if isfile(filePath)
                choice = uiconfirm(dlg, ...
                    sprintf('This report already exists:\n%s\n\nReplace it?', filePath), ...
                    'Replace Report', 'Options', {'Replace','Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
                if ~strcmp(choice, 'Replace')
                    return
                end
            end
            setBusy(true);
            restoreBusy = onCleanup(@() setBusy(false)); %#ok<NASGU>
            try
                sltest.testmanager.report(reportResult, filePath, ...
                    'IncludeTestResults', idx, ...
                    'Title', char(titleField.Value), ...
                    'Author', char(authorField.Value), ...
                    'IncludeSimulationSignalPlots', logical(signalPlots.Value), ...
                    'IncludeComparisonSignalPlots', logical(comparisonPlots.Value), ...
                    'IncludeErrorMessages', logical(errorMessages.Value), ...
                    'IncludeCoverageResult', logical(coverageResults.Value), ...
                    'LaunchReport', logical(launchReport.Value));
                if ~isfile(filePath)
                    error('BusHarnessApp:MissingReport', ...
                        'Test Manager did not produce the expected report file.');
                end
                appendTestLog("Gen Report Successful: " + string(filePath));
                delete(dlg);
            catch reportError
                appendTestLog("Gen Report Failed: " + string(reportError.message));
                uialert(dlg, reportError.message, 'Gen Report Failed');
            end
        end
    end

    function name = iterationOutcomeText(outcome)
        % TestIterationResult.Outcome can be numeric (0..3).
        % Translate it to a readable status without affecting test execution.
        if isnumeric(outcome)
            switch double(outcome)
                case 0
                    name = "Disabled";
                case 1
                    name = "Incomplete";
                case 2
                    name = "Passed";
                case 3
                    name = "Failed";
                otherwise
                    name = "Unknown (" + string(outcome) + ")";
            end
        else
            name = string(outcome);
        end
    end

    function updateCoverageVisibility()
        if coverageEnabled.Value
            metricGrid.Visible = 'on';
            runOptions.RowHeight = {22, 26, 22, 108};
        else
            metricGrid.Visible = 'off';
            runOptions.RowHeight = {22, 26, 22, 0};
        end
    end

    function onFastRestartChanged(~, ~)
        % Sync both the loaded harness model and Test Manager immediately.
        % If a harness/test file has not been built yet, Run Test will apply
        % the selected value once the files are available.
        if busy
            return
        end
        requested = logical(fastRestart.Value);
        harnessFile = savedHarnessFile();
        if isempty(harnessFile) || ~isfile(harnessFile)
            return
        end
        previous = ~requested;
        modelName = '';
        try
            [modelName, previous] = setHarnessFastRestart(harnessFile, requested);
            applyFastRestartToTestManager(requested, modelName);
        catch err
            % If the Test Manager setting fails, restore the harness and
            % checkbox rather than leaving two different restart modes.
            if ~isempty(modelName)
                try
                    set_param(modelName, 'FastRestart', fastRestartText(previous));
                catch
                end
            end
            fastRestart.Value = previous;
            uialert(app, sprintf('Cannot synchronize Fast Restart: %s', err.message), ...
                'Fast Restart');
        end
    end

    function applyFastRestartToTestManager(enabled, harnessName)
        if isempty(projectRoot) || isempty(project.TestManagerFile)
            return
        end
        testFile = fullfile(projectRoot, project.TestManagerFile);
        if ~isfile(testFile)
            return
        end
        tfSync = sltest.testmanager.TestFile(testFile);
        [~, modelName] = fileparts(char(modelPath));
        suiteSync = getTestSuiteByName(tfSync, [modelName '_TestSuite']);
        if isempty(suiteSync)
            error('BusHarnessApp:FastRestartSuite', ...
                'Test Manager suite was not found; use Build Test.');
        end
        tcSync = getTestCaseByName(suiteSync, modelName);
        if isempty(tcSync) || ~strcmp(char(string(getProperty(tcSync, 'Model'))), harnessName)
            error('BusHarnessApp:FastRestartCase', ...
                'Test Manager case targets a different harness; use Build Test.');
        end
        setProperty(tcSync, 'FastRestart', logical(enabled));
        saveToFile(tfSync);
    end

    function applyRunSettings(tf, tc, harness)
        recordCoverage = coverageEnabled.Value;
        metrics = metricCodes([metricOptions.Value]);
        if recordCoverage && isempty(metrics)
            error('BusHarnessApp:CoverageMetrics', 'Select at least one coverage metric.');
        end
        % Apply to the actual harness as well as the iteration test case.
        % The output logging setup runs before this step, so it can still
        % modify the model before enabling Fast Restart.
        setHarnessFastRestart(savedHarnessFile(), logical(fastRestart.Value));
        setProperty(tc, 'FastRestart', fastRestart.Value, 'SimulationMode', simulationMode.Value);
        coverage = getCoverageSettings(tf);
        if recordCoverage
            coverage.MetricSettings = string(metrics);
        end
        coverage.RecordCoverage = recordCoverage;
        coverage.MdlRefCoverage = recordCoverage;
        % Save settings before restricting the enabled iterations for this run.
        saveToFile(tf);
        appendTestLog("Simulation: " + string(simulationMode.Value) + ...
            " | Fast Restart: " + string(fastRestart.Value) + ...
            " | Coverage: " + string(recordCoverage));
    end

    function appendTestLog(line)
        testMessages.Value = [string(testMessages.Value(:)); string(line)];
    end

    function updateTestLogLine(rowIndex, line)
        % Keep Run Test text local; do not overwrite the Setting Build Log handle.
        logLines = string(testMessages.Value(:));
        if rowIndex >= 1 && rowIndex <= numel(logLines)
            logLines(rowIndex) = string(line);
            testMessages.Value = logLines;
        end
    end

    function setBusy(value)
        busy = value;
        enabled = matlab.lang.OnOffSwitchState(~value);
        modelField.Enable = enabled;
        excelList.Enable = enabled;
        commonList.Enable = enabled;
        hasHarness = isfile(savedHarnessFile());
        reloadButton.Enable = matlab.lang.OnOffSwitchState(~value && hasHarness);
        buildTestButton.Enable = matlab.lang.OnOffSwitchState(~value && hasHarness);
        hasTestFile = ~isempty(project.TestManagerFile) && ...
            isfile(fullfile(projectRoot, project.TestManagerFile));
        runTestButton.Enable = matlab.lang.OnOffSwitchState(~value && hasHarness && hasTestFile);
        updateReportButton();
        if value
            testcaseSelectAll.Enable = 'off';
            pendingSelectAll.Enable = 'off';
            testcaseList.Enable = 'off';
            renderRunTestcaseRows();
            pendingList.Enable = 'off';
        else
            testcaseList.Enable = 'on';
            renderRunTestcaseRows();
            pendingList.Enable = 'on';
            refreshSelectAllButtons();
        end
        fastRestart.Enable = enabled;
        simulationMode.Enable = enabled;
        coverageEnabled.Enable = enabled;
        set(metricOptions, 'Enable', enabled);
        set([modelButton, openModelButton, openTestCaseButton, openCommonButton, buildButton, refreshExcelButton], 'Enable', enabled);
        openButton.Enable = enabled;
        menuButton.Enable = enabled;
        projectActionsEnabled = matlab.lang.OnOffSwitchState(~value && ~isempty(projectRoot));
        saveProjectItem.Enable = projectActionsEnabled;
        closeProjectItem.Enable = projectActionsEnabled;
    end

    function file = savedHarnessFile()
        file = '';
        if ~isempty(projectRoot) && ~isempty(project.HarnessFile)
            candidate = fullfile(projectRoot, project.HarnessFile);
            if isfile(candidate)
                file = candidate;
                return
            end
        end
        if ~isempty(lastInfo) && isfile(lastInfo.HarnessFile)
            file = char(lastInfo.HarnessFile);
            return
        end
        if isempty(modelPath)
            return
        end
        [~, modelName] = fileparts(modelPath);
        folder = pwd;
        if ~isempty(projectRoot)
            folder = fullfile(projectRoot, 'input');
        end
        % Older project files may not store HarnessFile. Recover exactly
        % the expected harness, but never arbitrarily choose Harness_3.
        if ~isempty(project.HarnessName)
            candidate = fullfile(folder, [char(project.HarnessName) '.slx']);
        else
            candidate = fullfile(folder, [modelName '_Harness.slx']);
        end
        if isfile(candidate)
            file = candidate;
        end
    end

    function openHarnessForTestcase(testcaseName)
        % Activate the corresponding MAT dataset, not the first scenario.
        if busy, return; end
        try
            harnessFile = savedHarnessFile();
            if isempty(harnessFile) || ~isfile(harnessFile)
                error('BusHarnessApp:HarnessNotBuilt', ...
                    'Build Harness before opening a testcase for debugging.');
            end
            [harness, ~, ~, scenarios] = testHarnessScenarios(harnessFile);
            rows = testcaseList.Data;
            scenarioNames = harnessScenarioNames(rows.TestCase);
            match = find(rows.TestCase == string(testcaseName));
            if numel(match) ~= 1
                error('BusHarnessApp:DebugCase', ...
                    'Testcase "%s" is not uniquely present in the imported list.', ...
                    char(testcaseName));
            end
            scenario = scenarioNames(match);
            if ~ismember(scenario,scenarios)
                error('BusHarnessApp:DebugScenario', ...
                    ['Scenario "%s" is missing from the Signal Editor MAT. ' ...
                     'Reload Testcase or rebuild the Harness.'],char(scenario));
            end
            simState = string(get_param(harness,'SimulationStatus'));
            if ~ismember(lower(simState),["stopped","initialized","compiled"])
                error('BusHarnessApp:HarnessActive', ...
                    'Cannot change Signal Editor scenario while simulation is %s.', ...
                    char(simState));
            end
            editor = [char(harness) '/Signal Editor'];
            % ActiveScenario can be changed between Fast Restart runs.
            % Set it on the top-level harness, never the referenced model.
            set_param(editor,'ActiveScenario',char(scenario));
            if ~strcmp(string(get_param(editor,'ActiveScenario')),scenario)
                error('BusHarnessApp:ScenarioSelection', ...
                    'Signal Editor did not activate "%s".',char(scenario));
            end
            open_system(char(harness));
            open_system(editor);
            appendTestLog("Debug harness opened: " + string(testcaseName) + ...
                " | Signal Editor scenario: " + scenario);
        catch failure
            uialert(app,failure.message,'Could Not Open Testcase Harness');
        end
    end

    function openHarness(~, ~)
        try
            file = savedHarnessFile();
            if isempty(file)
                [name, folder] = uigetfile( ...
                    {'*.slx;*.mdl', 'Simulink Models (*.slx, *.mdl)'}, 'Open Harness', harnessPickerFolder());
                if isequal(name, 0)
                    return
                end
                file = fullfile(folder, name);
            end
            open_system(file);
        catch failure
            uialert(app, failure.message, 'Could Not Open Harness');
        end
    end

    function closeApp(~, ~)
        if ~busy && saveSelection()
            delete(app);
        end
    end
end

function info = buildSingleHarness(modelFile, excelPaths, inputFolder)
%BUILDSINGLEHARNESS Keep only <Model>_Harness for the selected source model.
% Protect old .slx/.mdl and matching Signal Editor .mat files until the
% replacement was successfully generated. Do not touch unrelated models.
[~, modelName] = fileparts(char(modelFile));
base = [modelName '_Harness'];
files = [dir(fullfile(inputFolder, [base '*.slx'])); ...
         dir(fullfile(inputFolder, [base '*.mdl']))];
oldModels = strings(0,1);
for k = 1:numel(files)
    [~, stem] = fileparts(files(k).name);
    if strcmp(stem,base) || ~isempty(regexp(stem, ...
            ['^' regexptranslate('escape',base) '_[0-9]+$'],'once'))
        oldModels(end+1,1) = string(stem); %#ok<AGROW>
    end
end
% Include loaded stale harnesses even if the .slx was already deleted.
loaded = find_system('type','block_diagram');
for k = 1:numel(loaded)
    name = char(loaded{k});
    if strcmp(name,base) || ~isempty(regexp(name, ...
            ['^' regexptranslate('escape',base) '_[0-9]+$'],'once'))
        oldModels(end+1,1) = string(name); %#ok<AGROW>
    end
end
oldModels = unique(oldModels,'stable');
for k = 1:numel(oldModels)
    name = char(oldModels(k));
    if ~bdIsLoaded(name)
        continue
    end
    if ~strcmp(get_param(name,'SimulationStatus'),'stopped')
        error('BusHarness:RunningHarness', ...
            'Stop simulation of harness "%s" before Build Harness.',name);
    end
    if strcmp(get_param(name,'Dirty'),'on')
        error('BusHarness:UnsavedHarness', ...
            'Harness "%s" has unsaved changes. Save or discard them before Build Harness.',name);
    end
    close_system(name,0);
end
% Collect only files belonging to generated harnesses, including orphan
% *_Inputs.mat files. Never delete a source model or unrelated project data.
filesToMove = strings(0,1);
for k = 1:numel(oldModels)
    stem = char(oldModels(k));
    for ext = {'.slx','.mdl','_Inputs.mat'}
        file = fullfile(inputFolder,[stem ext{1}]);
        if isfile(file)
            filesToMove(end+1,1) = string(file); %#ok<AGROW>
        end
    end
end
% Also clean up orphan numbered MATs whose SLX was manually deleted.
matFiles = dir(fullfile(inputFolder,[base '*_Inputs.mat']));
for k = 1:numel(matFiles)
    matName = matFiles(k).name;
    stem = extractBefore(string(matName),'_Inputs.mat');
    if stem == base || ~isempty(regexp(char(stem), ...
            ['^' regexptranslate('escape',base) '_[0-9]+$'],'once'))
        filesToMove(end+1,1) = string(fullfile(inputFolder,matName)); %#ok<AGROW>
    end
end
filesToMove = unique(filesToMove,'stable');
backupFolder = tempname(inputFolder);
if ~mkdir(backupFolder)
    error('BusHarness:Backup','Unable to create temporary harness backup folder.');
end
moved = strings(0,1);
buildStarted = false;
try
    for k = 1:numel(filesToMove)
        [~,n,e] = fileparts(char(filesToMove(k)));
        [ok,msg] = movefile(char(filesToMove(k)),fullfile(backupFolder,[n e]));
        if ~ok
            error('BusHarness:Backup','Cannot temporarily archive old harness: %s',msg);
        end
        moved(end+1,1) = filesToMove(k); %#ok<AGROW>
    end
    % Force the stable base name. Unlike auto-numbering, a collision is an error.
    buildStarted = true;
    info = createBusTestHarness(modelFile,string(base),excelPaths,string(inputFolder),"","");
catch failure
    % Remove any partial new model and MAT so the original can be restored.
    if buildStarted && bdIsLoaded(base)
        try
            close_system(base,0);
        catch
        end
    end
    if buildStarted
        for ext = {'.slx','_Inputs.mat'}
            candidate = fullfile(inputFolder,[base ext{1}]);
            if isfile(candidate)
                delete(candidate);
            end
        end
    end
    restorationErrors = strings(0,1);
    for k = 1:numel(moved)
        [~,n,e] = fileparts(char(moved(k)));
        [ok,msg] = movefile(fullfile(backupFolder,[n e]),char(moved(k)));
        if ~ok
            restorationErrors(end+1,1) = string(msg); %#ok<AGROW>
        end
    end
    if isempty(restorationErrors)
        if isfolder(backupFolder), rmdir(backupFolder,'s'); end
    else
        failure = addCause(failure,MException('BusHarness:Restore', ...
            'Could not restore an old harness. Backup remains in %s: %s', ...
            backupFolder,strjoin(restorationErrors,'; ')));
    end
    rethrow(failure);
end
% Delete backups only AFTER the new harness was saved successfully.
if isfolder(backupFolder)
    rmdir(backupFolder,'s');
end
end

function [harness, model, active, scenarios] = testHarnessScenarios(file)
requireFile(file, [".slx", ".mdl"], 'harness');
[found, attributes] = fileattrib(file);
if ~found
    error('BusHarnessApp:TestHarness', 'Cannot resolve the harness path.');
end
file = attributes.Name;
[~, harness] = fileparts(file);
if bdIsLoaded(harness) && ~strcmpi(get_param(harness, 'FileName'), file)
    error('BusHarnessApp:TestHarness', 'Close the other loaded model named "%s" first.', harness);
end
load_system(file);
editor = [harness '/Signal Editor'];
cut = [harness '/Model Under Test'];
if getSimulinkBlockHandle(editor) < 0 || getSimulinkBlockHandle(cut) < 0
    error('BusHarnessApp:TestHarness', 'The harness requires Signal Editor and Model Under Test blocks.');
end
model = get_param(cut, 'ModelName');
active = get_param(editor, 'ActiveScenario');
matFile = get_param(editor, 'Filename');
if ~isfile(matFile)
    matFile = fullfile(fileparts(file), matFile);
end
requireFile(matFile, ".mat", 'Signal Editor data file');
variables = whos('-file', char(matFile));
datasets = strcmp({variables.class}, 'Simulink.SimulationData.Dataset');
scenarios = reshape(string({variables(datasets).name}), [], 1);
if isempty(scenarios) || ~any(scenarios == string(active))
    error('BusHarnessApp:TestScenarios', 'The Signal Editor has no valid active scenario.');
end
end

function enableIterations(iterations, enabled)
for k = 1:numel(iterations)
    iterations(k).Enabled = enabled(k);
end
end

function data = emptyTestcaseTable()
data = table(false(0, 1), strings(0, 1), 'VariableNames', {'Selected', 'TestCase'});
end

function cells = filterWorkbookCases(cells, cases, chosen)
% Retain header and only complete testcase blocks, preserving original rows.
keep = false(size(cells,1),1);
keep(1) = true;
for k = find(chosen(:).')
    keep(cases(k).FirstRow:cases(k).LastRow) = true;
end
cells = cells(keep,:);
end

function file = writeMergedWorkbook(workbooks, selectedNames, folder, sourceFiles)
%WRITEMERGEDWORKBOOK One fixed multi-sheet Excel file per project.
% Never append numeric suffixes on successive Build/Reload operations.
file = fullfile(folder, 'Testcases_Merged.xlsx');
if any(strcmpi(string(sourceFiles(:)), string(file)))
    error('BusHarnessApp:MergedWorkbook', ...
        'Do not add the generated Testcases_Merged.xlsx as a testcase source.');
end
staged = [tempname(folder) '.xlsx'];
cleanup = onCleanup(@() removeTemp(staged)); %#ok<NASGU>
writtenSheets = 0;
for k = 1:numel(workbooks)
    group = workbooks(k);
    if isempty(group.Cases)
        continue
    end
    chosen = ismember(string({group.Cases.Name}), selectedNames);
    if ~any(chosen)
        continue
    end
    cells = filterWorkbookCases(group.Cells, group.Cases, chosen);
    % The prefix is stable and unique even when source sheets have the same
    % name, contain invalid Excel characters or exceed 31 characters.
    cleanName = regexprep(char(group.Sheet), '[^a-zA-Z0-9_-]', '_');
    cleanName = cleanName(1:min(numel(cleanName), 25));
    if isempty(cleanName)
        cleanName = 'Sheet';
    end
    sheetName = sprintf('S%03d_%s', k, cleanName);
    % readcell represents empty spreadsheet cells as missing values.
    blank = cellfun(@(value) isempty(value) || ...
        (isscalar(value) && ismissing(value)), cells);
    cells(blank) = {''};
    try
        writecell(cells, staged, 'Sheet', sheetName, 'Range', 'A1');
    catch failure
        error('BusHarnessApp:MergedWorkbook', ...
            'Could not write source sheet "%s" into merged workbook: %s', ...
            char(group.Sheet), failure.message);
    end
    writtenSheets = writtenSheets + 1;
end
if writtenSheets == 0
    error('BusHarnessApp:MergedWorkbook', ...
        'No selected testcase sheet is available for merge.');
end
% Replace only once all worksheets have been written successfully.
[ok, message] = movefile(staged, file, 'f');
if ~ok
    error('BusHarnessApp:MergedWorkbook', ...
        'Cannot replace the merged workbook "%s". Close it in Excel and retry. %s', ...
        file, message);
end
end

function removeLegacyMergedWorkbooks(workbooks, folder, currentFile)
% Remove only known legacy generated names of these exact source sheets.
% Never delete arbitrary Excel files in the project Input directory.
for k = 1:numel(workbooks)
    [~, sourceName] = fileparts(char(workbooks(k).Source));
    sheetName = regexprep(char(workbooks(k).Sheet), '[^a-zA-Z0-9_-]', '_');
    prefix = [sourceName '_' sheetName '_Merged'];
    files = dir(fullfile(folder, [prefix '*.xlsx']));
    for j = 1:numel(files)
        candidate = files(j).name;
        if files(j).isdir || ~isempty(regexpi(candidate, '^~\$', 'once'))
            continue
        end
        if isempty(regexp(candidate, ['^' regexptranslate('escape',prefix) ...
                '(?:_[0-9]+)?\.xlsx$'], 'once'))
            continue
        end
        oldFile = fullfile(folder, candidate);
        if strcmpi(oldFile, currentFile)
            continue
        end
        try
            delete(oldFile);
        catch failure
            warning('BusHarnessApp:MergeCleanup', ...
                'Could not remove old generated merge file "%s": %s', ...
                oldFile, failure.message);
        end
    end
end
end

function requireFile(file, extensions, label)
[~, ~, extension] = fileparts(file);
if ~isfile(file) || ~any(strcmpi(extension, extensions))
    error('BusHarnessApp:InvalidFile', 'Select a valid %s file.', label);
end
end

function data = emptyProject()
data = struct('SchemaVersion', 2, 'ModelFile', '', 'TestCaseFiles', {{}}, 'CommonFiles', {{}}, ...
    'HarnessName', '', 'HarnessFile', '', 'ScenarioFile', '', 'TestManagerFile', '', 'ToolVersion', '');
end

function data = readProject(file)
data = jsondecode(fileread(file));
template = emptyProject();
if isstruct(data) && isscalar(data) && isfield(data, 'SchemaVersion') && ...
        isequal(data.SchemaVersion, 1) && isfield(data, 'TestCaseFile') && ischar(data.TestCaseFile)
    legacy = data.TestCaseFile;
    data = rmfield(data, 'TestCaseFile');
    data.SchemaVersion = 2;
    data.TestCaseFiles = {};
    if ~isempty(legacy)
        data.TestCaseFiles = {legacy};
    end
end
if isstruct(data) && isscalar(data) && ~isfield(data, 'CommonFiles')
    data.CommonFiles = {};
end
if isstruct(data) && isscalar(data) && ~isfield(data, 'TestManagerFile')
    data.TestManagerFile = '';
end
if ~isstruct(data) || ~isscalar(data) || ...
        ~all(isfield(data, fieldnames(template))) || ~isequal(data.SchemaVersion, 2)
    error('BusHarnessApp:ProjectFormat', 'Unsupported Simulink Testing project format.');
end
fields = setdiff(fieldnames(template), {'SchemaVersion','TestCaseFiles','CommonFiles'});
for k = 1:numel(fields)
    value = data.(fields{k});
    if ~ischar(value) || (~isempty(value) && ~isrow(value))
        error('BusHarnessApp:ProjectFormat', 'Invalid project field: %s.', fields{k});
    end
end
if isempty(data.TestCaseFiles)
    data.TestCaseFiles = {};
elseif ~iscellstr(data.TestCaseFiles)
    error('BusHarnessApp:ProjectFormat', 'TestCaseFiles must contain Excel paths.');
end
data.TestCaseFiles = reshape(data.TestCaseFiles, 1, []);
for k = 1:numel(data.TestCaseFiles)
    value = data.TestCaseFiles{k};
    if ~isAbsolutePath(value) && (isempty(regexp(value, '^((input|testcases)/)[^/\\:]+$', 'once')) || ...
            any(endsWith(value, {'/.','/..'})))
        error('BusHarnessApp:ProjectFormat', 'Invalid testcase path: %s.', value);
    end
end
if isempty(data.CommonFiles)
    data.CommonFiles = {};
elseif ~iscellstr(data.CommonFiles) || ~all(cellfun(@isAbsolutePath, data.CommonFiles(:)))
    error('BusHarnessApp:ProjectFormat', 'CommonFiles must contain absolute Excel paths.');
end
data.CommonFiles = reshape(data.CommonFiles, 1, []);
paths = {'HarnessFile','ScenarioFile','TestManagerFile'};
prefixes = {'(input|harness)','(input|harness)','output'};
for k = 1:numel(paths)
    value = data.(paths{k});
    pattern = ['^' prefixes{k} '/[^/\\:]+$'];
    if ~isempty(value) && (isempty(regexp(value, pattern, 'once')) || ...
            any(endsWith(value, {'/.','/..'})))
        error('BusHarnessApp:ProjectFormat', 'Invalid project-relative path: %s.', value);
    end
end
end

function files = projectFiles(root)
files = dir(root);
files = files(~[files.isdir] & endsWith({files.name}, '.prj', 'IgnoreCase', true));
end

function writeProject(destination, data)
folder = fileparts(destination);
if ~isfolder(folder)
    parent = fileparts(folder);
    if isempty(parent) || ~isfolder(parent)
        error('BusHarnessApp:ProjectFolder', ...
            'The project location is unavailable. Check that the drive or network folder is connected.');
    end
    makeFolder(folder);
end
temp = [tempname(folder) '.tmp'];
cleanup = onCleanup(@() removeTemp(temp)); %#ok<NASGU>
[file, message] = fopen(temp, 'w', 'n', 'UTF-8');
if file == -1
    error('BusHarnessApp:ProjectWrite', '%s', message);
end
closeFile = onCleanup(@() fclose(file));
fprintf(file, '%s\n', jsonencode(data));
[message, code] = ferror(file);
if code ~= 0
    error('BusHarnessApp:ProjectWrite', 'Could not write the temporary project file: %s', message);
end
clear closeFile
[ok, message] = movefile(temp, destination, 'f');
if ~ok
    error('BusHarnessApp:ProjectWrite', '%s', message);
end
end

function removeTemp(file)
if isfile(file)
    delete(file);
end
end

function makeFolder(folder)
[ok, message] = mkdir(folder);
if ~ok
    error('BusHarnessApp:ProjectFolder', '%s', message);
end
end

function file = testcasePath(root, storedPath)
file = storedPath;
if ~isempty(file) && ~isAbsolutePath(file)
    file = fullfile(root, file);
end
end

function result = isAbsolutePath(file)
result = ~isempty(regexp(file, '^(?:[A-Za-z]:[\\/]|/|\\\\)', 'once'));
end

function icon = roundActionIcon(color, isPlus, background)
[x,y] = meshgrid(-17:17);
circle = max(0, min(1, 16.5 - hypot(x,y)));
mark = abs(x) <= 7 & abs(y) <= 1;
if isPlus
    mark = mark | (abs(y) <= 7 & abs(x) <= 1);
end
icon = zeros(35,35,3);
for channel = 1:3
    layer = background(channel) + (color(channel) - background(channel))*circle;
    layer(mark) = 1;
    icon(:,:,channel) = layer;
end
end

function label = fileLabel(path)
[~, stem, extension] = fileparts(path);
label = [stem extension];
end

function sample = modelSampleTime(harness)
% Read the exact fundamental step used by the harness, in seconds.
% For legacy harnesses with FixedStep=auto, fall back to the referenced
% model without inventing a step. New harnesses always store numeric step.
sample = NaN;
try
    [~,name] = fileparts(char(harness));
    if isfile(harness), load_system(char(harness)); end
    if ~bdIsLoaded(name), return; end
    if ~strcmp(get_param(name,'SolverType'),'Fixed-step'), return; end
    value = get_param(name,'FixedStep');
    step = str2double(value);
    if isfinite(step) && step > 0
        sample = step;
        return
    end
    modelBlock = find_system(name,'SearchDepth',1,'BlockType','ModelReference');
    if ~isempty(modelBlock)
        source = string(get_param(modelBlock{1},'ModelName'));
        sample = resolveHarnessSampleTime(source);
    end
catch
    % Unknown step means the viewer must not use a fabricated sample time.
end
end

function records = collectDataResults(results, selected)
% Keep explicit per-iteration logging diagnostics. Never silently turn a
% missing Model signal into a valid zero-valued waveform.
records = struct('Name',{},'Status',{},'Signals',{},'Diagnostic',{});
for k=1:numel(results)
    iterations = getIterationResults(results(k));
    for j=1:numel(iterations)
        item = iterations(j);
        if ~any(string(item.Name) == string(selected)), continue; end
        signals = struct('Name',{},'Time',{},'Data',{});
        diagnostics = strings(0,1);
        try
            runs = getOutputRuns(item);
            if isempty(runs)
                diagnostics(end+1) = "getOutputRuns returned no simulation runs. " + ...
                    "Check logging of Model Under Test output lines.";
            end
            for r=1:numel(runs)
                try
                    [captured,runDiagnostic] = collectSdiModelSignals(runs(r));
                    signals = [signals;captured]; %#ok<AGROW>
                    if strlength(string(runDiagnostic))>0
                        diagnostics(end+1) = string(runDiagnostic); %#ok<AGROW>
                    end
                catch signalError
                    diagnostics(end+1) = "SDI run " + string(r) + ...
                        ": " + string(signalError.message); %#ok<AGROW>
                end
            end
        catch outputError
            diagnostics(end+1) = "Cannot obtain Test Manager output runs: " + ...
                string(outputError.message);
        end
        if isempty(signals)
            diagnostics(end+1) = "No recorded Model output signals. " + ...
                "Run Test again with output logging enabled.";
        else
            captured = reshape(string({signals.Name}),1,[]);
            diagnostics(end+1) = "Logged Model signals: " + strjoin(captured,', ');
        end
        records(end+1,1) = struct('Name',char(string(item.Name)), ...
            'Status',char(iterationStatusForData(item.Outcome)), ...
            'Signals',signals, ...
            'Diagnostic',char(strjoin(diagnostics,' | '))); %#ok<AGROW>
    end
end
end

function label = iterationStatusForData(value)
if isnumeric(value)
    names = ["Disabled","Incomplete","Passed","Failed"];
    idx = double(value)+1;
    if idx>=1 && idx<=4, label=names(idx); else, label="Unknown"; end
else
    label=string(value);
end
end

function enableHarnessOutputLogging(harness)
% Enable logging of Model Under Test output lines, not assessment expects.
[~,name] = fileparts(char(harness));
if isfile(harness), load_system(char(harness)); end
block = [name '/Model Under Test'];
ports = get_param(block,'PortHandles');
set_param(name,'SignalLogging','on');
for k=1:numel(ports.Outport)
    lineHandle = get_param(ports.Outport(k),'Line');
    if lineHandle > 0
        set_param(lineHandle,'DataLogging','on');
    end
end
save_system(name);
end

function configureOutputLoggingForTest(tc,harness)
% Record model output ports in Test Manager Simulation Outputs. Avoid
% duplicate LoggedSignalSet objects on subsequent Run Test clicks.
[~,name] = fileparts(char(harness));
block = [name '/Model Under Test'];
ports = get_param(block,'PortHandles');
if isempty(ports.Outport), return; end
try
    sets = getLoggedSignalSets(tc);
catch
    sets = [];
end
setName = 'DataViewer_ModelOutputs';
chosen = [];
for j=1:numel(sets)
    try
        if strcmp(char(string(sets(j).Name)),setName)
            chosen = sets(j); break
        end
    catch
    end
end
if isempty(chosen)
    chosen = addLoggedSignalSet(tc,'Name',setName);
end
try
    old = getLoggedSignals(chosen);
catch
    old = [];
end
for k=1:numel(ports.Outport)
    exists = false;
    for q=1:numel(old)
        try
            pathText = char(string(old(q).BlockPath));
            if contains(pathText,block) && double(old(q).PortIndex)==k
                exists=true; break
            end
        catch
        end
    end
    if ~exists
        addLoggedSignal(chosen,block,k);
    end
end
end

function [name, previous] = setHarnessFastRestart(file, enabled)
%SETHARNESSFASTRESTART Set Fast Restart on the harness top-level model.
if ~isfile(file)
    error('BusHarnessApp:FastRestartHarness', 'Harness file does not exist. Build Harness first.');
end
[~, name] = fileparts(char(file));
if bdIsLoaded(name)
    loadedFile = get_param(name, 'FileName');
    if ~strcmpi(char(string(loadedFile)), char(string(file)))
        error('BusHarnessApp:FastRestartHarness', ...
            'Another model named "%s" is loaded. Close that model first.', name);
    end
else
    load_system(file);
end
previous = strcmpi(get_param(name, 'FastRestart'), 'on');
requested = fastRestartText(enabled);
if previous ~= logical(enabled)
    set_param(name, 'FastRestart', requested);
end
end

function value = fastRestartText(enabled)
if enabled
    value = 'on';
else
    value = 'off';
end
end

function verifyHarnessMatBeforeRun(harnessFile, selected)
%VERIFYHARNESSMATBEFORERUN Guard against stale MAT link or missing scenarios.
if ~isfile(harnessFile)
    error('BusHarnessApp:MissingHarness', 'Harness file is missing.');
end
[folder, harness] = fileparts(char(harnessFile));
load_system(char(harnessFile));
editor = [harness '/Signal Editor'];
linked = string(get_param(editor, 'Filename'));
if ~isfile(linked)
    linked = string(fullfile(folder, char(linked)));
end
if ~isfile(linked)
    error('BusHarnessApp:MissingScenarioMAT', ...
        'Signal Editor MAT file is not accessible. Use Load Testcase to Harness.');
end
variables = whos('-file', char(linked));
matNames = string({variables(strcmp({variables.class}, ...
    'Simulink.SimulationData.Dataset')).name});
missing = reshape(string(selected),[],1);
missing = missing(~ismember(missing,matNames));
if ~isempty(missing)
    error('BusHarnessApp:MissingScenario', ...
        'Selected scenario(s) missing in current Signal Editor MAT: %s. Reload or Build Test.', ...
        strjoin(cellstr(missing),', '));
end
end
