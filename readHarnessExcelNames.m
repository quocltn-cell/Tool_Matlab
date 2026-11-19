function [names, entries] = readHarnessExcelNames(files)
%READHARNESSEXCELNAMES Preview ALL sheets without expanding common functions.
% Duplicate names are deliberately retained in the preview. The full
% importer rejects duplicates and reports both source locations in Build Log.
names = strings(0,1);
entries = struct('File', {}, 'Sheet', {}, 'Name', {});
for file = reshape(string(files), 1, [])
    if file == "", continue; end
    try
        sheets = reshape(string(sheetnames(file)),1,[]);
        foundSheet = false;
        for sheet = sheets
            cells = readcell(file, 'Sheet', char(sheet), 'Range', 'A1');
            if isempty(cells), continue; end
            headerCells = string(cellfun(@cellText, cells(1,:), 'UniformOutput', false));
            headers = lower(regexprep(strtrim(headerCells), '\s+', ''));
            ixName = find(headers == "testcase_name", 1);
            if isempty(ixName), continue; end
            foundSheet = true;
            ixTime = find(headers == "time(ms)", 1);
            if isempty(ixTime)
                error('Sheet "%s" is missing Time(ms) column.',char(sheet));
            end
            inCase = false;
            found = 0;
            for r = 2:size(cells, 1)
                name = cellText(cells{r, ixName});
                when = cellText(cells{r, ixTime});
                if strcmpi(when, 'Test label'), continue; end
                if strcmpi(name, 'End'), inCase = false; continue; end
                if name ~= "" && ~inCase
                    names(end+1,1) = name; %#ok<AGROW>
                    entries(end+1) = struct('File',file,'Sheet',sheet,'Name',name); %#ok<AGROW>
                    inCase = true;
                    found = found+1;
                end
            end
            if found == 0
                error('Sheet "%s" has testcase header but no cases.',char(sheet));
            end
        end
        if ~foundSheet
            error('No testcase sheets with a testcase_name header.');
        end
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
