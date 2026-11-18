function viewer = testDataViewer(parent)
%TESTDATAVIEWER Input/Output result inspector embedded in Simulink Testing.
% The viewer is read-only; it does not alter datasets or Test Manager runs.
ink = [0.12 0.19 0.30];
root = uigridlayout(parent,[1 1],'Padding',[8 8 8 8]);
tabs = uitabgroup(root);
inTab = uitab(tabs,'Title','Input');
outTab = uitab(tabs,'Title','Output');
state = struct('Names',strings(0,1),'Selected',1,'ScenarioFile','', ...
    'Results',struct('Name',{},'Status',{},'Signals',{}),'SampleTime',NaN, ...
    'InputError','', 'ExcelInputs',struct('Name',{},'Signals',{}), ...
    'InputChoices',strings(0,1),'CheckedSignals',strings(0,1), ...
    'ExcelOutputs',struct('Name',{},'Signals',{}), ...
    'OutputChoices',strings(0,1),'SelectedOutputCase','');
views = cell(1,2);
for mode = 1:2
    if mode == 1, tab = inTab; else, tab = outTab; end
    main = uigridlayout(tab,[1 2],'ColumnWidth',{260,'1x'},'Padding',[6 6 6 6], ...
        'ColumnSpacing',8);
    left = uipanel(main,'Title','Test Cases');
    if mode == 2
        chooser = uigridlayout(left,[5 1],'RowHeight',{25,26,86,26,'1x'}, ...
            'Padding',[7 8 7 8],'RowSpacing',6);
    else
        chooser = uigridlayout(left,[4 1],'RowHeight',{25,26,26,'1x'}, ...
            'Padding',[7 8 7 8],'RowSpacing',6);
    end
    info = uilabel(chooser,'Text','Run Test to view data','FontColor',ink);
    search = uieditfield(chooser,'text','Placeholder','Search testcase name...', ...
        'ValueChangedFcn',@(~,~) rebuildCases(mode));
    if mode == 2
        summary = uitextarea(chooser,'Editable','off','Value',{'Pass: -';'Fail: -'});
    else
        summary = [];
    end
    uilabel(chooser,'Text','Select one testcase:','FontColor',ink);
    if mode == 1
        cases = uitable(chooser,'Data',table(false(0,1),strings(0,1), ...
            'VariableNames',{'Selected','TestCase'}), ...
            'ColumnName',{'Select','Test Case'},'ColumnEditable',[true false], ...
            'ColumnWidth',{58,'auto'},'RowName',{}, ...
            'CellEditCallback',@(~,evt) selectInputCase(evt));
    else
        cases = uitable(chooser,'Data',table(false(0,1),strings(0,1), ...
            'VariableNames',{'Selected','TestCase'}), ...
            'ColumnName',{'Select','Test Case'},'ColumnEditable',[true false], ...
            'ColumnWidth',{58,'auto'},'RowName',{}, ...
            'CellEditCallback',@(~,evt) selectOutputCase(evt));
    end
    right = uipanel(main,'Title','Signals and Waveforms');
    rightGrid = uigridlayout(right,[5 1],'RowHeight',{29,112,26,22,'1x'}, ...
        'Padding',[8 7 8 7],'RowSpacing',4);
    signalSearch = uieditfield(rightGrid,'text','Placeholder','Filter signals...', ...
        'ValueChangedFcn',@(~,~) render(mode));
    if mode == 1
        signalList = uitable(rightGrid,'Data',table(false(0,1),strings(0,1), ...
            'VariableNames',{'Selected','Signal'}), ...
            'ColumnName',{'Plot','Input Signals (Excel)'}, ...
            'ColumnEditable',[true false],'ColumnWidth',{55,'auto'}, ...
            'RowName',{},'CellEditCallback',@(~,evt) chooseSignal(evt));
    else
        signalList = uitable(rightGrid,'Data',table(false(0,1),strings(0,1), ...
            'VariableNames',{'Selected','Signal'}), ...
            'ColumnName',{'Plot','Output Signals (Excel)'}, ...
            'ColumnEditable',[true false],'ColumnWidth',{55,'auto'}, ...
            'RowName',{},'CellEditCallback',@(~,evt) chooseOutputSignal(evt));
    end
    position = uigridlayout(rightGrid,[1 3], ...
        'ColumnWidth',{120,'1x',95},'Padding',[0 0 0 0], ...
        'ColumnSpacing',8);
    uilabel(position,'Text','Cursor (seconds)');
    cursor = uislider(position,'Limits',[0 1],'Value',0,'MajorTicks',[], ...
        'ValueChangingFcn',@(~,evt) changeCursor(mode,evt.Value), ...
        'ValueChangedFcn',@(~,~) changeCursor(mode,cursor.Value));
    cursorTime = uieditfield(position,'numeric','Value',0, ...
        'Tooltip','Enter a time in seconds and press Enter', ...
        'ValueChangedFcn',@(src,~) changeCursor(mode,src.Value));
    diagnosticLabel = uilabel(rightGrid,'Text','Select a testcase to display its signals.', ...
        'FontColor',ink,'FontSize',11);
    scroll = uigridlayout(rightGrid,[1 1],'Scrollable','on', ...
        'Padding',[4 4 4 4]);
    views{mode} = struct('Info',info,'Search',search,'Cases',cases, ...
        'Summary',summary,'SignalList',signalList, ...
        'SignalSearch',signalSearch,'Cursor',cursor,'CursorTime',cursorTime,'Scroll',scroll, ...
        'Diagnostic',diagnosticLabel, ...
        'Traces',{{}},'Markers',{{}},'Readouts',{{}},'CurrentSignals',[]);
end
viewer.refresh = @refresh;
viewer.setResults = @setResults;
viewer.clear = @clearAll;
viewer.setExcelInputs = @setExcelInputs;

    function clearAll()
        state.Names = strings(0,1);
        state.Results = struct('Name',{},'Status',{},'Signals',{});
        state.ScenarioFile = '';
        state.CheckedSignals = strings(0,1);
        state.InputChoices = strings(0,1);
        state.OutputChoices = strings(0,1);
        state.SelectedOutputCase = '';
        safelyRebuildCases(1); safelyRebuildCases(2);
    end

    function setExcelInputs(files,commonFiles)
        if nargin < 2, commonFiles = {}; end
        try
            state.ExcelInputs = readHarnessExcelInputSignals(files,commonFiles);
            state.ExcelOutputs = readHarnessExcelOutputSignals(files,commonFiles);
        catch err
            state.ExcelInputs = struct('Name',{},'Signals',{});
            state.ExcelOutputs = struct('Name',{},'Signals',{});
            views{1}.Diagnostic.Text = ['Excel input list: ' err.message];
        end
        safelyRebuildCases(1);
        safelyRebuildCases(2);
    end

    function refresh(scenarioFile,names,sampleTime)
        if nargin < 3, sampleTime = NaN; end
        state.ScenarioFile = char(scenarioFile);
        state.Names = unique(string(names(:)),'stable');
        state.SampleTime = double(sampleTime);
        state.Selected = 1;
        state.SelectedOutputCase = '';
        state.OutputChoices = strings(0,1);
        state.InputError = '';
        safelyRebuildCases(1); safelyRebuildCases(2);
    end

    function setResults(testResults, scenarioFile, sampleTime)
        % A result is Name, Status, Signals with individual Name, Time, Data.
        state.Results = testResults;
        if isempty(testResults)
            state.Names = strings(0,1);
        else
            state.Names = reshape(string({testResults.Name}),[],1);
        end
        state.ScenarioFile = char(scenarioFile);
        if nargin >= 3, state.SampleTime = double(sampleTime); end
        state.Selected = 1;
        state.SelectedOutputCase = '';
        state.OutputChoices = strings(0,1);
        state.InputError = '';
        safelyRebuildCases(1); safelyRebuildCases(2);
    end

    function safelyRebuildCases(mode)
        try
            rebuildCases(mode);
        catch e
            v = views{mode};
            v.Diagnostic.Text = ['Testcase list error: ' e.message];
            showMessage(v,['Could not refresh testcase list: ' e.message]);
            warning('SimulinkTesting:DataViewer','Data tab %d: %s',mode,e.message);
        end
    end

    function rebuildCases(mode)
        % Build selection tables from explicit, same-length column vectors.
        % Avoid comparing the testcase list against an empty selection: in
        % several MATLAB releases that produces an empty array, and the
        % uitable rejects the resulting unequal table column heights.
        v = views{mode};
        if mode == 1
            names = reshape(string(state.Names),[],1);
            v.Info.Text = sprintf('%d test case(s) available',numel(names));
            labels = names;
        else
            if isempty(state.Results)
                names = strings(0,1);
                outcomes = strings(0,1);
            else
                names = reshape(string({state.Results.Name}),[],1);
                outcomes = reshape(string({state.Results.Status}),[],1);
            end
            pass = sum(strcmpi(outcomes,'Passed'));
            fail = sum(strcmpi(outcomes,'Failed'));
            v.Info.Text = sprintf('Total: %d | Pass: %d | Fail: %d',numel(names),pass,fail);
            passNames = names(strcmpi(outcomes,'Passed'));
            failNames = names(strcmpi(outcomes,'Failed'));
            v.Summary.Value = cellstr(["PASS CASES (" + string(numel(passNames)) + ")"; ...
                passNames; "FAIL CASES (" + string(numel(failNames)) + ")"; failNames]);
            labels = names + " [" + outcomes + "]";
        end
        searchText = strtrim(string(v.Search.Value));
        if ismissing(searchText) || strlength(searchText)==0
            keep = true(numel(names),1);
        else
            keep = contains(lower(names),lower(searchText));
        end
        names = names(keep);
        labels = labels(keep);
        if mode == 1
            if isempty(names)
                state.InputChoices = "";
                v.Cases.Data = table(false(0,1),strings(0,1), ...
                    'VariableNames',{'Selected','TestCase'});
            else
                selected = string(state.InputChoices);
                if isempty(selected) || ~isscalar(selected) || ~any(strcmp(names,selected))
                    selected = names(1);
                    state.CheckedSignals = strings(0,1);
                end
                state.InputChoices = selected;
                checked = false(numel(names),1);
                checked(find(strcmp(names,selected),1)) = true;
                v.Cases.Data = table(checked,names, ...
                    'VariableNames',{'Selected','TestCase'});
            end
            updateSignalChoices();
        else
            % Output uses the same single-choice checkbox table as Input.
            if isempty(names)
                state.SelectedOutputCase = '';
                state.OutputChoices = strings(0,1);
                v.Cases.Data = table(false(0,1),strings(0,1), ...
                    'VariableNames',{'Selected','TestCase'});
            else
                chosenOutput = string(state.SelectedOutputCase);
                if ~isscalar(chosenOutput) || strlength(chosenOutput)==0 || ...
                        ~any(strcmp(names,chosenOutput))
                    chosenOutput = names(1);
                    state.OutputChoices = strings(0,1);
                end
                state.SelectedOutputCase = char(chosenOutput);
                checked = strcmp(names,chosenOutput);
                v.Cases.Data = table(logical(checked(:)),reshape(labels,[],1), ...
                    'VariableNames',{'Selected','TestCase'});
            end
            updateOutputChoices();
        end
        render(mode);
    end

    function selectOutputCase(evt)
        if evt.Indices(2)~=1, return; end
        v = views{2};
        rows = v.Cases.Data;
        idx = evt.Indices(1);
        if idx<1 || idx>height(rows), return; end
        % Store the raw case name, not the display label containing [Failed].
        raw = string(rows.TestCase(idx));
        raw = regexprep(char(raw),' \[.*\]$','');
        if ~strcmp(raw,state.SelectedOutputCase)
            state.SelectedOutputCase = raw;
            state.OutputChoices = strings(0,1);
        end
        rows.Selected(:) = false;
        rows.Selected(idx) = true;
        v.Cases.Data = rows;
        updateOutputChoices();
        render(2);
    end

    function selectInputCase(evt)
        if evt.Indices(2) ~= 1, return; end
        v = views{1};
        row = evt.Indices(1);
        data = v.Cases.Data;
        if row < 1 || row > height(data), return; end
        % Single selection: clicking a checkbox selects that testcase only.
        newName = string(data.TestCase(row));
        if ~strcmp(char(newName),char(string(state.InputChoices)))
            state.InputChoices = newName;
            state.CheckedSignals = strings(0,1);
        end
        data.Selected(:) = false;
        data.Selected(row) = true;
        v.Cases.Data = data;
        updateSignalChoices();
        render(1);
    end

    function updateSignalChoices()
        v = views{1};
        names = strings(0,1);
        for n = 1:numel(state.ExcelInputs)
            if string(state.ExcelInputs(n).Name) == state.InputChoices
                names = string(state.ExcelInputs(n).Signals(:));
                break
            end
        end
        state.CheckedSignals = intersect(state.CheckedSignals,names,'stable');
        v.SignalList.Data = table(ismember(names,state.CheckedSignals),names, ...
            'VariableNames',{'Selected','Signal'});
    end

    function updateOutputChoices()
        v = views{2};
        names = strings(0,1);
        for n = 1:numel(state.ExcelOutputs)
            if strcmp(string(state.ExcelOutputs(n).Name),string(state.SelectedOutputCase))
                names = reshape(string(state.ExcelOutputs(n).Signals),[],1);
                break
            end
        end
        % If no workbook output rows are found, expose the expected
        % signals from the Signal Editor instead of a permanently empty list.
        if isempty(names) && ~isempty(state.SelectedOutputCase)
            [expected,~] = readScenario(state.ScenarioFile,state.SelectedOutputCase);
            for i=1:numel(expected)
                raw = string(expected(i).Name);
                if contains(lower(raw),'_exp')
                    names(end+1,1) = removeExpectedSuffix(raw); %#ok<AGROW>
                end
            end
            names = unique(names,'stable');
        end
        state.OutputChoices = intersect(state.OutputChoices,names,'stable');
        v.SignalList.Data = table(ismember(names,state.OutputChoices),names, ...
            'VariableNames',{'Selected','Signal'});
    end

    function chooseOutputSignal(evt)
        if evt.Indices(2) ~= 1, return; end
        t = views{2}.SignalList.Data;
        state.OutputChoices = string(t.Signal(logical(t.Selected)));
        render(2);
    end

    function chooseSignal(evt)
        if evt.Indices(2) ~= 1, return; end
        v = views{1};
        t = v.SignalList.Data;
        state.CheckedSignals = string(t.Signal(logical(t.Selected)));
        render(1);
    end

    function render(mode)
        % Never leave the viewer empty after a graphics or data error.
        v = views{mode};
        v.Diagnostic.Text = 'Loading testcase signals...';
        drawnow limitrate;
        try
            renderSignals(mode);
        catch issue
            v = views{mode};
            v.CurrentSignals = [];
            v.Markers = {};
            v.Readouts = {};
            views{mode} = v;
            origin = 'unknown location';
            if ~isempty(issue.stack)
                origin = sprintf('%s (line %d)',issue.stack(1).name,issue.stack(1).line);
            end
            v.Diagnostic.Text = sprintf('Data error [%s]: %s',origin,issue.message);
            showMessage(v,sprintf('Data error [%s]: %s',origin,issue.message));
        end
    end

    function renderSignals(mode)
        v = views{mode};
        delete(v.Scroll.Children);
        v.Traces = {}; v.Markers = {}; v.Readouts = {};
        v.CurrentSignals = [];
        views{mode} = v;
        if (mode == 1 && isempty(v.Cases.Data)) || ...
                (mode == 2 && isempty(v.Cases.Data))
            v.Diagnostic.Text = 'No testcase selected. Run Test first.';
            showMessage(v,'No testcase selected.');
            return
        end
        if mode == 1
            chosen = state.InputChoices;
        else
            chosen = string(state.SelectedOutputCase);
        end
        if mode == 1
            [signals,diagnostic] = readScenario(state.ScenarioFile,chosen);
            state.InputError = diagnostic;
            if ~isempty(signals)
                signals = signals(~contains(lower(string({signals.Name})),"_exp"));
            end
            % Plot ONLY signals explicitly selected from Excel testcase rows.
            if isempty(state.CheckedSignals)
                v.Diagnostic.Text = 'Select input signals (checkboxes) to plot.';
                showMessage(v,'Tick one or more Input Signals to display waveforms.');
                return
            end
            if ~isempty(signals)
                match = false(numel(signals),1);
                for k=1:numel(signals)
                    for j=1:numel(state.CheckedSignals)
                        if signalMatches(signals(k).Name,state.CheckedSignals(j))
                            match(k)=true; break
                        end
                    end
                end
                signals=signals(match);
            end
        else
            idx = find(string({state.Results.Name}) == chosen,1);
            if isempty(idx)
                v.Diagnostic.Text = 'No Run Test result found for selected testcase.';
                showMessage(v,'No saved result for selected testcase.');
                return
            end
            [expected,diagnostic] = readScenario(state.ScenarioFile,chosen);
            if ~isempty(expected)
                expected = expected(contains(lower(string({expected.Name})),"_exp"));
            end
            signals = pairOutputs(state.Results(idx).Signals,expected);
            % Explain missing real Model output instead of presenting Expect
            % alone without stating that no comparison was possible.
            actualSignalNames = strings(0,1);
            if ~isempty(state.Results(idx).Signals)
                actualSignalNames = reshape(string({state.Results(idx).Signals.Name}),[],1);
            end
            outputDiagnostic = "";
            if isfield(state.Results,'Diagnostic')
                outputDiagnostic = string(state.Results(idx).Diagnostic);
            end
            missingModelNames = strings(0,1);
            for pairIndex=1:numel(signals)
                if isempty(signals(pairIndex).ModelTime)
                    missingModelNames(end+1,1) = string(signals(pairIndex).Name); %#ok<AGROW>
                end
            end
            if ~isempty(missingModelNames)
                state.InputError = "Model output not found for: " + ...
                    strjoin(missingModelNames,', ') + ...
                    ". Logged names: " + strjoin(actualSignalNames,', ') + ...
                    ". " + outputDiagnostic;
            else
                state.InputError = outputDiagnostic;
            end
            if isempty(signals) && ~isempty(state.Results(idx).Signals)
                actual = state.Results(idx).Signals;
                for m=1:numel(actual)
                    signals(end+1,1) = struct('Name',string(actual(m).Name), ...
                        'ModelTime',actual(m).Time,'ModelData',actual(m).Data, ...
                        'ExpectTime',[],'ExpectData',[]); %#ok<AGROW>
                end
            end
            if strlength(string(diagnostic))>0
                state.InputError = string(state.InputError) + " | Scenario: " + string(diagnostic);
            end
            if isempty(state.OutputChoices)
                v.Diagnostic.Text = 'Tick one or more Output Signals to plot.';
                showMessage(v,'Select Output Signals (checkboxes) to display waveforms.');
                return
            end
            if ~isempty(signals)
                keepOutput = false(numel(signals),1);
                for i=1:numel(signals)
                    for j=1:numel(state.OutputChoices)
                        if signalMatches(signals(i).Name,state.OutputChoices(j))
                            keepOutput(i)=true; break
                        end
                    end
                end
                signals = signals(keepOutput);
            end
        end
        q = lower(strtrim(string(v.SignalSearch.Value)));
        if strlength(q)>0 && ~isempty(signals)
            signals = signals(contains(lower(string({signals.Name})),q));
        end
        if isempty(signals)
            if mode==1
                msg = 'No input signals for this testcase. ' + string(state.InputError);
            else
                msg = 'No output signals. Check Test Manager output logging and *_Exp bus. ' + string(state.InputError);
            end
            if strlength(q)>0, msg = msg + ' Filter: ' + q; end
            v.Diagnostic.Text = char(msg);
            showMessage(v,char(msg));
            return
        end
        % Layout must explicitly contain one row per plot. Assigning a
        % child to row k in a 1-row grid can fail on some MATLAB releases.
        n = numel(signals);
        v.Scroll.RowHeight = repmat({200},1,n);
        v.Scroll.ColumnWidth = {'1x'};
        v.Scroll.RowSpacing = 7;
        plotted = 0;
        failures = strings(0,1);
        goodSignals = signals([]);
        endTime = 0;
        for k=1:n
            plotStep = 'initializing panel';
            p = [];
            try
                s = signals(k);
                p = uipanel(v.Scroll,'Title',char(string(s.Name)),'FontWeight','bold');
                p.Layout.Row = plotted + 1;
                p.Layout.Column = 1;
                plotStep = 'creating axes';
                % Input and Output share the same axes/grid layout.
                g = uigridlayout(p,[1 1],'RowHeight',{'1x'}, ...
                    'Padding',[7 4 7 3]);
                ax = uiaxes(g);
                ax.NextPlot = 'add';
                ax.XLabel.String = 'Time (s)'; ax.YLabel.String = 'Value';
                ax.XGrid = 'on'; ax.YGrid = 'on';
                ax.GridColor = [0.78 0.81 0.85];
                ax.GridAlpha = 0.45;
                ax.Layer = 'bottom';
                ax.Toolbar.Visible = 'off';
                ax.ButtonDownFcn = @(~,evt) clickAxis(mode,evt);
                plotStep = 'plotting waveform';
                % Draw waveform data first. Optional comparison highlights or
                % cursor labels must NEVER prevent the actual output plot.
                if mode == 1
                    [x,y] = scalarWaveform(s.Time,s.Data);
                    stairs(ax,x,y,'Color',[0.1 0.37 0.9],'LineWidth',1.5);
                    endTime = max(endTime,max(x));
                else
                    hasModel = false; hasExpect = false;
                    if ~isempty(s.ModelTime) && ~isempty(s.ModelData)
                        [x,y] = scalarWaveform(s.ModelTime,s.ModelData);
                        stairs(ax,x,y,'Color',[0.88 0.18 0.17],'LineWidth',1.5);
                        endTime = max(endTime,max(x));
                        hasModel = true;
                    end
                    if ~isempty(s.ExpectTime) && ~isempty(s.ExpectData)
                        [x,y] = scalarWaveform(s.ExpectTime,s.ExpectData);
                        stairs(ax,x,y,'Color',[0.57 0.25 0.75],'LineWidth',1.5);
                        endTime = max(endTime,max(x));
                        hasExpect = true;
                    end
                    if ~hasModel && ~hasExpect
                        error('SimulinkTesting:NoOutputWaveform', ...
                            'Neither Model nor Expect has plottable samples.');
                    end
                    % A failed equality overlay is nonfatal; keep both traces.
                    if hasModel && hasExpect
                        try
                            drawMatching(ax,s);
                        catch overlayError
                            warning('SimulinkTesting:ComparisonOverlay', ...
                                'Green matching overlay skipped for %s: %s', ...
                                char(string(s.Name)),overlayError.message);
                        end
                    end
                end
                plotStep = 'creating cursor';
                yl = ylim(ax);
                if any(~isfinite(yl)) || yl(1)==yl(2), yl = [0 1]; end
                marker = line(ax,[0 0],yl,'Color',[0.15 0.18 0.22], ...
                    'LineWidth',1,'HitTest','off','PickableParts','none');
                % Some MATLAB UIAxes versions reject text() on certain
                % signal types. Degrade gracefully: the waveform remains.
                readout = {[],[]};
                try
                    plotStep = 'creating value labels';
                    if mode == 1
                        readout{1} = cursorValueLabel(ax,[0.10 0.37 0.90],'bottom');
                    else
                        % Same in-axes cursor readouts as Input: Model red,
                        % Expect purple. Place opposite sides of the point.
                        readout{1} = cursorValueLabel(ax,[0.88 0.18 0.17],'bottom');
                        readout{2} = cursorValueLabel(ax,[0.57 0.25 0.75],'top');
                    end
                catch labelError
                    warning('SimulinkTesting:CursorLabel', ...
                        'Cursor label skipped for %s: %s', ...
                        char(string(s.Name)),labelError.message);
                    readout = {[],[]};
                end
                v.Markers{end+1} = marker;
                v.Readouts{end+1} = readout;
                goodSignals(end+1,1) = s; %#ok<AGROW>
                plotted = plotted + 1;
            catch plotError
                if exist('s','var') && isfield(s,'Name')
                    signalName = string(s.Name);
                else
                    signalName = "Signal " + string(k);
                end
                where = "";
                if ~isempty(plotError.stack)
                    where = " [" + string(plotError.stack(1).name) + ...
                        " line " + string(plotError.stack(1).line) + "]";
                end
                failures(end+1,1) = signalName + " (" + plotStep + "): " + ...
                    string(plotError.message) + where; %#ok<AGROW>
                if exist('p','var') && isvalid(p), delete(p); end
                % The next successful signal should use the next free row.
            end
        end
        v.CurrentSignals = goodSignals;
        views{mode} = v;
        if plotted==0
            msg = 'Signals were decoded but none could be plotted.';
            if ~isempty(failures), msg = msg + ' ' + strjoin(failures,' | '); end
            v.Diagnostic.Text = char(msg);
            showMessage(v,char(msg));
            return
        end
        % Input and Output use the SAME scenario-input timeline for the
        % selected testcase. Output must not derive its slider duration from
        % Expect/Model logging (which may start/end at different times).
        [inputStart,inputEnd,hasInputTimeline] = scenarioInputTimeline( ...
            state.ScenarioFile,chosen);
        if hasInputTimeline
            plotStart = inputStart;
            plotEnd = inputEnd;
        else
            % Older projects without input samples: preserve the plotted
            % signal duration rather than inventing scenario time data.
            plotStart = 0;
            plotEnd = max(endTime,1e-9);
        end
        if plotEnd <= plotStart
            plotEnd = plotStart + max(validSampleTime(state.SampleTime),1e-9);
        end
        for axidx=1:numel(v.Markers)
            marker = v.Markers{axidx};
            if ~isempty(marker) && isvalid(marker)
                ax = ancestor(marker,'axes');
                if ~isempty(ax) && isvalid(ax)
                    xlim(ax,[plotStart plotEnd]);
                end
            end
        end
        v.Cursor.Limits = [plotStart plotEnd];
        v.Cursor.Value = plotStart;
        v.CursorTime.Value = plotStart;
        if ~isempty(failures)
            v.Diagnostic.Text = sprintf('%d/%d signal(s) displayed. Plot errors: %s', ...
                plotted,n,char(strjoin(failures,' | ')));
        else
            v.Diagnostic.Text = sprintf('%d signal(s) displayed for %s.', ...
                plotted,char(chosen));
        end
        if mode==2 && strlength(string(state.InputError))>0 && ...
                ~isempty(missingModelNames)
            v.Diagnostic.Text = char("Model signal missing (not a valid comparison). " + string(state.InputError));
        end
        try
            changeCursor(mode,plotStart);
        catch cursorError
            v.Diagnostic.Text = [v.Diagnostic.Text ' | Cursor: ' cursorError.message];
        end
    end

    function showMessage(v,message)
        delete(v.Scroll.Children);
        v.Scroll.RowHeight = {'1x'};
        v.Scroll.ColumnWidth = {'1x'};
        uilabel(v.Scroll,'Text',char(message),'WordWrap','on', ...
            'VerticalAlignment','top');
    end

    function clickAxis(mode,evt)
        try
            t = evt.IntersectionPoint(1);
            changeCursor(mode,t);
        catch
        end
    end

    function changeCursor(mode,t,snapToSample)
        % Both slider and typed time use the fundamental sample period (s).
        % For example, Ts=0.01: 0.02 is a valid tick; 0.023 -> 0.02.
        % For Ts=0.1: 0.02 -> 0.0 (no sample exists at 0.02).
        if nargin < 3, snapToSample = true; end
        snapToSample = true; %#ok<NASGU> % single stepping policy in Data tab
        v = views{mode};
        if ~isscalar(t) || ~isnumeric(t) || ~isfinite(t), return; end
        t = min(max(double(t),v.Cursor.Limits(1)),v.Cursor.Limits(2));
        if snapToSample
            t = alignTimeToSample(t,v.Cursor.Limits,state.SampleTime);
        end
        t = min(max(t,v.Cursor.Limits(1)),v.Cursor.Limits(2));
        v.Cursor.Value = t;
        v.CursorTime.Value = t;
        if isempty(v.CurrentSignals), return; end
        for k = 1:numel(v.Markers)
            if ~isvalid(v.Markers{k}), continue; end
            marker = v.Markers{k};
            marker.XData = [t t];
            s = v.CurrentSignals(k);
            tags = v.Readouts{k};
            if mode == 1
                value = sampleAt(s.Time,s.Data,t);
                moveValueTag(tags{1},t,value,'%.9g');
            else
                actual = sampleAt(s.ModelTime,s.ModelData,t);
                expected = sampleAt(s.ExpectTime,s.ExpectData,t);
                moveValueTag(tags{1},t,actual,'Model: %.9g');
                moveValueTag(tags{2},t,expected,'Expect: %.9g');
            end
        end
    end
end

function [tStart,tEnd,found] = scenarioInputTimeline(file,caseName)
% Use scenario INPUT time samples for both Input and Output of the same
% testcase; Expected output and SDI logs must not change cursor duration.
tStart = 0;
tEnd = 0;
found = false;
try
    [signals,~] = readScenario(file,caseName);
    if isempty(signals), return; end
    names = string({signals.Name});
    signals = signals(~contains(lower(names),"_exp"));
    for k=1:numel(signals)
        times = double(signals(k).Time(:));
        times = times(isfinite(times));
        if isempty(times), continue; end
        if ~found
            tStart = min(times);
            tEnd = max(times);
            found = true;
        else
            tStart = min(tStart,min(times));
            tEnd = max(tEnd,max(times));
        end
    end
catch
    % Keep caller's plotting-data fallback when scenario is unreadable.
end
end

function step = validSampleTime(sampleTime)
step = 0;
if isnumeric(sampleTime) && isscalar(sampleTime) && ...
        isfinite(sampleTime) && sampleTime > 0
    step = double(sampleTime);
end
end

function t = alignTimeToSample(t,limits,sampleTime)
% Snap to the SAME fundamental discrete sample grid for both tabs.
step = validSampleTime(sampleTime);
if step <= 0, return; end
base = double(limits(1));
last = double(limits(2));
nMax = max(0,floor((last-base)/step + 1e-9));
n = min(nMax,max(0,round((double(t)-base)/step)));
t = base + n*step;
end

function updateReadoutLabel(label,caption,value)
if isempty(label) || ~isvalid(label), return; end
if ~isscalar(value) || ~isfinite(value)
    label.Text = [caption ': --'];
else
    label.Text = sprintf('%s: %.9g',caption,double(value));
end
end

function name = removeExpectedSuffix(raw)
name = regexprep(char(string(raw)),'_Exp(?=\.|$)','');
name = string(name);
name = replace(name,'.Exp.','.');
end

function h = cursorValueLabel(ax,color,verticalAlign)
% Create an explicitly scalar text object. Never use empty text/positions:
% on some MATLAB releases those are expanded to 0-element arrays.
h = text(ax,0,0,' ', ...
    'Color',color,'BackgroundColor',[1 1 1], ...
    'Margin',2,'FontSize',10,'FontWeight','bold', ...
    'VerticalAlignment',verticalAlign,'Interpreter','none', ...
    'HitTest','off','PickableParts','none');
end

function [x,y] = scalarWaveform(t,d)
% Normalize numeric, logical and enum values to one scalar per sample.
% Reject matrix/vector-valued leaves instead of passing incompatible
% dimensions into stairs/text graphics (which can trigger cryptic errors).
x = double(t(:));
if isnumeric(d) || islogical(d)
    y = double(d);
elseif isenum(d)
    y = double(d);
else
    error('SimulinkTesting:UnsupportedWaveform', ...
        'Unsupported waveform class: %s',class(d));
end
if ~isvector(y)
    if size(y,1)==numel(x) && size(y,2)==1
        y = y(:,1);
    else
        error('SimulinkTesting:VectorSignal', ...
            'Signal contains %s data rather than scalar samples; select a bus leaf.',mat2str(size(y)));
    end
end
y = y(:);
if numel(x)~=numel(y) || isempty(x)
    error('SimulinkTesting:WaveformSize', ...
        'Time has %d samples but signal has %d.',numel(x),numel(y));
end
valid = isfinite(x) & isfinite(y);
x = x(valid); y = y(valid);
if isempty(x)
    error('SimulinkTesting:EmptyWaveform','No finite time/value samples are available.');
end
[x,idx] = sort(x,'ascend'); y=y(idx);
end

function moveValueTag(tag,t,value,formatStr)
% Display one scalar sample beside the vertical cursor, not below a plot.
if isempty(tag) || ~isvalid(tag), return; end
if ~isscalar(value) || ~isfinite(value)
    tag.String = '';
    return
end
tag.Position = [double(t) double(value) 0];
% Place labels inside the axes when the cursor approaches the right edge.
ax = ancestor(tag,'axes');
if ~isempty(ax) && isvalid(ax)
    span = diff(ax.XLim);
    if span > 0 && t > ax.XLim(1) + 0.82*span
        tag.HorizontalAlignment = 'right';
    else
        tag.HorizontalAlignment = 'left';
    end
end
tag.String = sprintf(formatStr,double(value));
end

function [signals, diagnostic] = readScenario(file,name)
signals = struct('Name',{},'Time',{},'Data',{});
diagnostic = '';
if ~isfile(file)
    diagnostic = ['Scenario MAT file not found: ' char(file)];
    return
end
try
    vars = whos('-file',file);
    available = string({vars.name});
    found = find(strcmp(available,string(name)),1);
    if isempty(found)
        diagnostic = ['Scenario "' char(name) '" not found in MAT file.'];
        return
    end
    mat = load(file,char(name));
    data = mat.(char(name));
    if ~isa(data,'Simulink.SimulationData.Dataset')
        diagnostic = ['Scenario is ' class(data) ', not a Dataset.'];
        return
    end
    % Dataset elements can be raw structs (not Signal objects); defer
    % naming and nested bus traversal to flattenTestSignals.
    signals = flattenTestSignals(data,"");
    if isempty(signals)
        diagnostic = 'Scenario contains no scalar numeric signal leaves.';
    end
catch failure
    diagnostic = failure.message;
end
end

function paired = pairOutputs(actual,expected)
%PAIROUTPUTS Pair verified Signal Editor *_Exp signals with logged outputs.
% Use normalized char paths; never use string == '.' as a character-index
% operation (that triggered the previous extractAfter/graphics-like error).
paired = struct('Name',{},'ModelTime',{},'ModelData',{},'ExpectTime',{},'ExpectData',{});
if isempty(expected), return; end
actualNames = strings(numel(actual),1);
for j=1:numel(actual)
    actualNames(j) = normalizeOutputPath(actual(j).Name);
end
for i=1:numel(expected)
    displayName = removeExpectedSuffix(expected(i).Name);
    target = normalizeOutputPath(displayName);
    matches = find(strcmpi(actualNames,target));
    if isempty(matches)
        % SDI frequently prepends the logged bus, Model, or Outport names.
        % Only match a full suffix path and only if it is unambiguous.
        matches = find(endsWith(actualNames,"."+target,'IgnoreCase',true));
    end
    if isempty(matches)
        % A leaf-only fallback is safe only if ONE actual signal has the leaf.
        tokens = regexp(char(target),'\.','split');
        leaf = string(tokens{end});
        candidates = find(strcmpi(actualNames,leaf) | ...
            endsWith(actualNames,"."+leaf,'IgnoreCase',true));
        if numel(candidates)==1, matches = candidates; end
    end
    if numel(matches)~=1
        t=[]; d=[]; % No unambiguous model output: show Expect only.
    else
        t=actual(matches).Time; d=actual(matches).Data;
    end
    paired(end+1,1) = struct('Name',displayName, ...
        'ModelTime',t,'ModelData',d, ...
        'ExpectTime',expected(i).Time, ...
        'ExpectData',expected(i).Data); %#ok<AGROW>
end
end

function name = normalizeOutputPath(raw)
% Normalize bus hierarchy and SDI path separators; keep full leaf identity.
name = replace(string(raw),"/",".");
name = strrep(name,char(92),".");
name = regexprep(char(name),'\.+','.');
name = string(regexprep(name,'^\.|\.$',''));
end

function drawMatching(ax,s)
if isempty(s.ModelTime) || isempty(s.ExpectTime), return; end
% Strict equality over the recorded discrete samples. Green is NOT a pass
% verdict: Test Assessment might apply different time and type semantics.
t = unique([s.ModelTime(:);s.ExpectTime(:)]);
if numel(t)>100000, return; end
for i=1:numel(t)-1
    a = sampleAt(s.ModelTime,s.ModelData,t(i));
    b = sampleAt(s.ExpectTime,s.ExpectData,t(i));
    if isfinite(a) && isfinite(b) && isequal(a,b)
        line(ax,[t(i) t(i+1)],[a a],'Color',[0.12 0.66 0.30], ...
            'LineWidth',2.4,'HitTest','off');
    end
end
end

function v = sampleAt(t,y,at)
v = NaN;
if isempty(t) || isempty(y), return; end
idx = find(double(t)<=at+1e-10,1,'last');
if ~isempty(idx) && idx<=numel(y), v = double(y(idx)); end
end

function yes = signalMatches(datasetName,excelName)
% Match by bus + leaf path; do not match unrelated leaves sharing a name.
a = lower(replace(string(datasetName),"/","."));
b = lower(replace(string(excelName),"/","."));
yes = a == b || endsWith(a,"."+b);
% Some generated datasets add Input or Signal prefixes; only full path suffix.
end
