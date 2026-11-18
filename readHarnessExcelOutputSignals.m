function catalog = readHarnessExcelOutputSignals(files, commonFiles)
%READHARNESSEXCELINPUTSIGNALS Output signals explicitly verified by Excel cases.
% Does not require importing cases into Signal Editor or resolving functions.
% If common workbooks are available, use expanded cases for full coverage.
catalog = struct('Name',{},'Signals',{});
if nargin < 2, commonFiles = {}; end
try
    cases = readHarnessExcel(files,commonFiles);
    for k = 1:numel(cases)
        rows = cases(k).Rows;
        selected = strcmpi(string({rows.Type}),"O");
        sigs = strings(0,1);
        for r = find(selected)
            sigs(end+1,1) = string(rows(r).Bus)+"."+string(rows(r).Signal); %#ok<AGROW>
        end
        catalog(end+1) = struct('Name',string(cases(k).Name), ...
            'Signals',unique(sigs,'stable')); %#ok<AGROW>
    end
    return
catch
    % Fallback: preview direct I rows even if some common functions are absent.
end
for file = reshape(string(files),1,[])
    if file == "" || ~isfile(file), continue; end
    cells = readcell(file,'Sheet',1,'Range','A1');
    if isempty(cells), continue; end
    headers = strings(1,size(cells,2));
    for c=1:size(cells,2)
        headers(c)=lower(regexprep(strtrim(textCell(cells{1,c})),'\s+',''));
    end
    need = ["testcase_name","time(ms)","type","bus","signal"];
    [ok,ix] = ismember(need,headers);
    if ~all(ok), continue; end
    active = 0;
    for r=2:size(cells,1)
        name = textCell(cells{r,ix(1)});
        tm = textCell(cells{r,ix(2)});
        if strcmpi(tm,'Test label'), continue; end
        if strcmpi(name,'End'), active=0; continue; end
        if name ~= ""
            active=numel(catalog)+1;
            catalog(active)=struct('Name',name,'Signals',strings(0,1)); %#ok<AGROW>
        end
        if active==0, continue; end
        direction=textCell(cells{r,ix(3)});
        bus=textCell(cells{r,ix(4)});
        signal=textCell(cells{r,ix(5)});
        if strcmpi(direction,'O') && bus~="" && signal~=""
            catalog(active).Signals(end+1,1)=bus+"."+signal;
        end
    end
end
for k=1:numel(catalog)
    catalog(k).Signals=unique(catalog(k).Signals,'stable');
end
end
function s=textCell(v)
s="";
if isempty(v), return; end
try
    s=strtrim(string(v));
    if ismissing(s), s=""; end
catch
end
end
