function [signals,diagnostic] = collectSdiModelSignals(runObj)
%COLLECTSDIMODELSIGNALS Return plottable SDI leaves, including bus children.
% Input is one Simulink.sdi.Run from TestIterationResult.getOutputRuns.
signals = struct('Name',{},'Time',{},'Data',{});
messages = strings(0,1);
try
    entries = getAllSignals(runObj);
catch err
    messages(end+1,1) = "getAllSignals failed: " + string(err.message);
    try
        n = double(runObj.SignalCount);
        entries = [];
        for k=1:n
            entries = [entries;getSignalByIndex(runObj,k)]; %#ok<AGROW>
        end
    catch nested
        diagnostic = strjoin([messages;"getSignalByIndex failed: " + string(nested.message)],' | ');
        return
    end
end
for k=1:numel(entries)
    try
        pieces = flattenSdiSignal(entries(k),"",0);
        signals = [signals;pieces]; %#ok<AGROW>
    catch err
        messages(end+1,1) = "SDI element " + string(k) + ...
            " (" + string(err.identifier) + "): " + string(err.message); %#ok<AGROW>
    end
end
if isempty(signals)
    messages(end+1,1) = "SDI returned no plottable scalar signals";
end
diagnostic = char(strjoin(messages,' | '));
end

function output = flattenSdiSignal(sig,parent,depth)
output = struct('Name',{},'Time',{},'Data',{});
if depth>20, return; end
name = "";
try, name = string(sig.Name); catch, end
if numel(name)~=1 || strlength(name)==0, name="Signal"; end
if strlength(parent)>0
    % Avoid duplicated paths if the child already carries the full path.
    if ~startsWith(lower(name),lower(parent)+".")
        name = parent + "." + name;
    end
end
try
    value = sig.Values;
    if ~isempty(value)
        output = flattenTestSignals(value,name);
    end
catch
    % Bus root can lack Values; its Children are still plottable.
end
try
    children = sig.Children;
    for k=1:numel(children)
        output = [output;flattenSdiSignal(children(k),name,depth+1)]; %#ok<AGROW>
    end
catch
end
end
