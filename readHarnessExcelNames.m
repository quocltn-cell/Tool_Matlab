function names = readHarnessExcelNames(files)
%READHARNESSEXCELNAMES Preview testcase names without expanding common functions.
% This lightweight preview is intentionally independent of Test Common Files.
% Full Excel validation remains in readHarnessExcel during Build/Load.
names = strings(0, 1);
for file = reshape(string(files), 1, [])
    if file == ""
        continue
    end
    try
        cells = readcell(file, 'Sheet', 1, 'Range', 'A1');
        if isempty(cells)
            error('No data found on sheet 1.');
        end
        headerCells = string(cellfun(@cellText, cells(1,:), 'UniformOutput', false));
        headers = lower(regexprep(strtrim(headerCells), '\s+', ''));
        ixName = find(headers == "testcase_name", 1);
        ixTime = find(headers == "time(ms)", 1);
        if isempty(ixName) || isempty(ixTime)
            error('Missing testcase_name or Time(ms) column.');
        end
        found = strings(0,1);
        inCase = false;
        for r = 2:size(cells, 1)
            name = cellText(cells{r, ixName});
            when = cellText(cells{r, ixTime});
            if strcmpi(when, 'Test label')
                continue
            end
            if strcmpi(name, 'End')
                inCase = false;
                continue
            end
            if name ~= "" && ~inCase
                found(end+1,1) = name; %#ok<AGROW>
                inCase = true;
            end
        end
        if isempty(found)
            error('Sheet 1 does not contain testcase names.');
        end
        repeated = found(ismember(found, names));
        if numel(unique(found)) < numel(found) || ~isempty(repeated)
            error('Duplicate testcase names across Excel files.');
        end
        names = [names; found]; %#ok<AGROW>
    catch failure
        error('BusHarness:ExcelPreview', 'Excel file "%s": %s', char(file), failure.message);
    end
end
end

function value = cellText(item)
if isempty(item) || (isscalar(item) && ismissing(item))
    value = "";
else
    value = strtrim(string(item));
end
end
