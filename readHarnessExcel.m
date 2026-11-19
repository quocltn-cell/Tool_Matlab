function [cases, merged] = readHarnessExcel(files, commonFiles, selectedSheets)
%READHARNESSEXCEL Read ALL testcase sheets and identify duplicate names.
% selectedSheets is optional; entries are <full-file-path> + newline + <sheet>.
if nargin < 2, commonFiles = {}; end
if nargin < 3, selectedSheets = strings(0,1); end
selectedSheets = string(selectedSheets(:));
commonFiles = reshape(string(commonFiles), 1, []);
commonFiles = commonFiles(commonFiles ~= "");
functions = readCommonFunctions(commonFiles);
cases = struct('Name', {}, 'Rows', {}, 'DurationMs', {}, 'FirstRow', {}, 'LastRow', {});
merged = struct('Source', {}, 'Sheet', {}, 'Cells', {}, 'Cases', {});
locations = strings(0,1);
for file = reshape(string(files), 1, [])
    if file == "", continue; end
    found = false;
    try
        sheets = reshape(string(sheetnames(file)),1,[]);
    catch failure
        error('BusHarness:ExcelImport', 'Excel file "%s": %s', char(file), failure.message);
    end
    for sheet = sheets
        if ~isempty(selectedSheets) && ~any(selectedSheets == file + newline + sheet)
            continue
        end
        try
            cells = readcell(file, 'Sheet', char(sheet), 'Range', 'A1');
            if isempty(cells) || ~any(normalizedHeaders(cells) == "testcase_name")
                % Other workbook sheets may contain documentation or metadata.
                continue
            end
            found = true;
            columns = workbookColumns(cells, "testcase_name");
            cells = expandFunctions(cells, columns, functions, commonFiles);
            imported = readRows(cells, columns);
            for j = 1:numel(imported)
                name = string(imported(j).Name);
                previous = find(strcmpi(string({cases.Name}),name),1);
                if ~isempty(previous)
                    error('BusHarness:DuplicateTestcase', ...
                        'Duplicate testcase "%s": %s and %s (row %d). Rename one testcase.', ...
                        char(name), char(locations(previous)), ...
                        char(file + " / " + sheet), imported(j).FirstRow);
                end
                locations(end+1,1) = file + " / " + sheet; %#ok<AGROW>
            end
            cases = [cases, imported]; %#ok<AGROW>
            if nargout > 1
                merged(end+1) = struct('Source',file,'Sheet',sheet, ...
                    'Cells',{cells},'Cases',{imported}); %#ok<AGROW>
            end
        catch failure
            error('BusHarness:ExcelImport', 'Excel file "%s", sheet "%s": %s', ...
                char(file), char(sheet), failure.message);
        end
    end
    if ~found && isempty(selectedSheets)
        error('BusHarness:ExcelImport', ...
            'Excel file "%s" has no sheet with a testcase_name header.', char(file));
    end
end
end

function functions = readCommonFunctions(files)
functions = struct('Name', {}, 'Key', {}, 'Rows', {}, 'Headers', {});
for file = files
    found = false;
    for sheet = reshape(sheetnames(file), 1, [])
        cells = readcell(file, 'Sheet', sheet, 'Range', 'A1');
        headers = normalizedHeaders(cells);
        if ~any(headers == "functioncommon")
            continue
        end
        found = true;
        try
            columns = workbookColumns(cells, "functioncommon");
            blocks = readRows(cells, columns);
            afterName = columns(2):size(cells, 2);
            for block = blocks
                key = commonFunctionKey(block.Name);
                if isempty(key)
                    error('BusHarness:ExcelFunction', 'Common function name is empty after normalization (row %d).', block.FirstRow);
                end
                if any(strcmp({functions.Key}, key))
                    error('BusHarness:ExcelFunction', 'Duplicate common function "%s".', char(block.Name));
                end
                functions(end+1) = struct('Name', block.Name, 'Key', key, ... %#ok<AGROW>
                    'Rows', {cells(block.FirstRow:block.LastRow-1, afterName)}, ...
                    'Headers', headers(afterName));
            end
        catch failure
            error('BusHarness:ExcelCommon', 'Common file "%s", sheet "%s": %s', ...
                char(file), char(sheet), failure.message);
        end
    end
    if ~found
        error('BusHarness:ExcelCommon', 'Common file "%s" has no sheet with a Function common header in row 1.', char(file));
    end
end
end

function output = expandFunctions(cells, columns, functions, commonFiles)
headers = normalizedHeaders(cells);
parts = cell(size(cells, 1), 1);
parts{1} = cells(1,:);
for row = 2:size(cells, 1)
    original = cells(row,:);
    parts{row} = original;
    if ~strcmpi(excelText(original{columns(3)}), 'Func') || ...
            strcmpi(excelText(original{columns(2)}), 'Test label')
        continue
    end
    name = excelText(original{columns(4)});
    index = find(strcmp({functions.Key}, commonFunctionKey(name)), 1);
    if isempty(index)
        if isempty(commonFiles)
            detail = 'Add the workbook containing this function under Test Common Files.';
        else
            detail = sprintf('Available common functions: %s.', char(strjoin(string({functions.Name}), ', ')));
        end
        error('BusHarness:ExcelFunction', ...
            'Excel row %d: common function "%s" was not found. %s Lookup key (UTF-16): %s.', ...
            row, name, detail, strtrim(sprintf('%04X ', double(commonFunctionKey(name)))));
    end
    common = functions(index);
    inserted = cell(size(common.Rows, 1), size(cells, 2));
    for column = 1:numel(common.Headers)
        header = common.Headers(column);
        if header == ""
            target = columns(2) + column - 1;
            if target <= numel(headers) && headers(target) == ""
                inserted(:, target) = common.Rows(:, column);
            end
            continue
        end
        target = find(headers == header, 1);
        if isempty(target)
            % Include named columns such as Description even when absent from the testcase.
            headers(end+1) = header; %#ok<AGROW>
            target = numel(headers);
            parts{1}{target} = char(header);
        end
        inserted(:, target) = common.Rows(:, column);
    end
    inserted{1, columns(1)} = original{columns(1)};
    parts{row} = inserted;
end
for row = 1:numel(parts)
    if size(parts{row}, 2) < numel(headers)
        parts{row}(:, numel(headers)) = {[]};
    end
end
output = vertcat(parts{:});
end

function key = commonFunctionKey(value)
key = char(value);
% Excel cells can contain nonbreaking spaces and invisible formatting marks.
space = char([160 5760 8192:8202 8232 8233 8239 8287 12288]);
invisible = char([173 1564 6158 8203:8207 8234:8238 8288:8303 65279]);
key(ismember(key, space)) = ' ';
key(ismember(key, invisible)) = [];
key = lower(strtrim(key));
end

function columns = workbookColumns(cells, nameHeader)
required = [nameHeader, "time(ms)", "type", "bus", "signal", "value"];
[present, columns] = ismember(required, normalizedHeaders(cells));
if ~all(present)
    error('BusHarness:ExcelHeader', 'Missing Excel columns: %s.', char(strjoin(required(~present), ', ')));
end
end

function headers = normalizedHeaders(cells)
headers = strings(1,0);
if ~isempty(cells)
    headers = lower(regexprep(string(cellfun(@excelText, cells(1,:), 'UniformOutput', false)), '\s+', ''));
end
end

function cases = readRows(cells, columns)
rowTemplate = struct('Type', "", 'Bus', "", 'Signal', "", 'Value', [], 'Time', 0, 'Row', 0, 'Index', 0);
cases = struct('Name', {}, 'Rows', {}, 'DurationMs', {}, 'FirstRow', {}, 'LastRow', {});
current = 0;
startRow = 0;
elapsed = 0;
for row = 2:size(cells,1)
    fields = cells(row, columns);
    name = string(excelText(fields{1}));
    delta = string(excelText(fields{2}));
    direction = upper(string(excelText(fields{3})));
    if strcmpi(delta, "Test label")
        continue
    end
    if strcmpi(name, "End")
        if current == 0
            error('BusHarness:ExcelTestcase', 'Excel row %d has End without an open testcase.', row);
        end
        if delta ~= "" || direction ~= "" || any(cellfun(@(v) ~isempty(excelText(v)), fields(4:6)))
            error('BusHarness:ExcelTestcase', 'Excel row %d: put End on its own row.', row);
        end
        if isempty(cases(current).Rows)
            error('BusHarness:ExcelTestcase', 'Testcase "%s" (row %d) has no I or O rows.', ...
                char(cases(current).Name), startRow);
        end
        cases(current).DurationMs = elapsed;
        cases(current).LastRow = row;
        current = 0;
        continue
    end
    if name ~= ""
        if current ~= 0
            error('BusHarness:ExcelTestcase', ...
                'Excel row %d: testcase "%s" (row %d) needs End before "%s".', ...
                row, char(cases(current).Name), startRow, char(name));
        end
        if any(strcmp({cases.Name}, name))
            error('BusHarness:ExcelTestcase', 'Excel row %d repeats testcase "%s".', row, char(name));
        end
        current = numel(cases) + 1;
        startRow = row;
        cases(current).Name = name;
        cases(current).FirstRow = row;
        cases(current).Rows = repmat(rowTemplate, 0, 1);
        elapsed = 0;
    end
    if delta == "" && direction == "" && all(cellfun(@(v) isempty(excelText(v)), fields(4:6)))
        continue
    end
    if current == 0
        error('BusHarness:ExcelTestcase', 'Excel row %d has data outside a testcase.', row);
    end
    if delta ~= ""
        delay = str2double(delta);
        if ~isfinite(delay) || ~isreal(delay) || delay < 0 || ~isfinite(elapsed + delay)
            error('BusHarness:ExcelTime', 'Excel row %d requires a finite nonnegative Time(ms).', row);
        end
        elapsed = elapsed + delay;
    end
    bus = string(excelText(fields{4}));
    signal = string(excelText(fields{5}));
    value = excelText(fields{6});
    if direction == "" && bus == "" && signal == "" && isempty(value)
        continue
    end
    if ~any(direction == ["I", "O"]) || bus == "" || signal == "" || isempty(value)
        error('BusHarness:ExcelRow', 'Excel row %d requires Type I/O, Bus, Signal and Value.', row);
    end
    entry = rowTemplate;
    entry.Type = direction;
    entry.Bus = bus;
    entry.Signal = signal;
    entry.Value = fields{6};
    entry.Time = elapsed / 1000;
    entry.Row = row;
    cases(current).Rows(end+1,1) = entry;
end
if current ~= 0
    error('BusHarness:ExcelTestcase', 'Testcase "%s" (row %d) is missing End.', ...
        char(cases(current).Name), startRow);
end
if isempty(cases)
    error('BusHarness:ExcelTestcase', 'Sheet 1 does not contain any testcases.');
end
end

function text = excelText(value)
if isempty(value) || (isscalar(value) && ismissing(value))
    text = '';
else
    text = char(strtrim(string(value)));
end
end
