function entries = flattenTestSignals(value, name)
%FLATTENTESTSIGNALS Flatten scalar bus leaves to plot-ready time series.
% Handles Signal.Values, struct-of-timeseries, timeseries containing
% structs and numeric arrays, datasets and logged bus SDI values.
if nargin < 2 || strlength(string(name)) == 0, name = "Signal"; end
entries = struct('Name',{},'Time',{},'Data',{});
if isempty(value), return; end
if isa(value,'Simulink.SimulationData.Dataset')
    % addElement(dataset, structOfTimeseries, elementName) returns the raw
    % struct from getElement(). The struct need not have a Name field.
    elementNames = strings(0,1);
    try
        elementNames = string(value.getElementNames());
    catch
        % Older MATLAB releases may not expose getElementNames.
    end
    for k=1:value.numElements
        item=value.getElement(k);
        subname="";
        if numel(elementNames)>=k, subname=string(elementNames(k)); end
        if strlength(subname)==0
            subname=safeSignalName(item);
        end
        if strlength(subname)==0, subname="Signal_"+string(k); end
        entries=[entries; flattenTestSignals(item,joinName(name,subname))]; %#ok<AGROW>
    end
elseif isa(value,'Simulink.SimulationData.Signal')
    subname=safeSignalName(value);
    if strlength(subname)==0, subname=string(name); end
    entries=flattenTestSignals(value.Values,subname);
elseif isa(value,'timeseries')
    t=double(value.Time(:));
    d=value.Data;
    if isempty(t), return; end
    if isnumeric(d) || islogical(d) || isa(d,'enum')
        if isa(d,'enum'), d=double(d); end
        d=double(d);
        if numel(d)==numel(t)
            entries=putEntry(entries,name,t,reshape(d,[],1));
        elseif size(d,1)==numel(t) && ismatrix(d)
            for j=1:size(d,2)
                entries=putEntry(entries,string(name)+"("+string(j)+")",t,d(:,j));
            end
        elseif size(d,ndims(d))==numel(t)
            d=reshape(d,[],numel(t));
            for j=1:size(d,1)
                entries=putEntry(entries,string(name)+"("+string(j)+")",t,d(j,:).');
            end
        end
    elseif isstruct(d)
        % A timeseries may hold bus structs per sample, or a scalar struct
        % whose members are themselves timeseries.
        if isscalar(d)
            fields=fieldnames(d);
            for j=1:numel(fields)
                field=fields{j};
                child=d.(field);
                childName=joinName(name,string(field));
                if isa(child,'timeseries') || isstruct(child)
                    entries=[entries; flattenTestSignals(child,childName)]; %#ok<AGROW>
                elseif (isnumeric(child)||islogical(child)) && numel(child)==numel(t)
                    entries=putEntry(entries,childName,t,double(child(:)));
                end
            end
        else
            fields=fieldnames(d);
            for j=1:numel(fields)
                field=fields{j};
                cells={d.(field)};
                if all(cellfun(@(x)(isnumeric(x)||islogical(x)) && isscalar(x),cells))
                    entries=putEntry(entries,joinName(name,string(field)),t, ...
                        double(cell2mat(cells(:))));
                end
            end
        end
    end
elseif isstruct(value)
    for k=1:numel(value)
        fields=fieldnames(value(k));
        for j=1:numel(fields)
            child=value(k).(fields{j});
            childName=joinName(name,string(fields{j}));
            entries=[entries; flattenTestSignals(child,childName)]; %#ok<AGROW>
        end
    end
elseif istimetable(value)
    t=seconds(value.Properties.RowTimes-value.Properties.RowTimes(1));
    vars=value.Properties.VariableNames;
    for j=1:numel(vars)
        d=value.(vars{j});
        if (isnumeric(d)||islogical(d)) && size(d,1)==numel(t)
            for n=1:size(d,2)
                label=joinName(name,string(vars{j}));
                if size(d,2)>1, label=label+"("+string(n)+")"; end
                entries=putEntry(entries,label,t,double(d(:,n)));
            end
        end
    end
end
end

function entries=putEntry(entries,name,t,data)
if isempty(t) || isempty(data) || numel(t)~=numel(data), return; end
t=double(t(:)); data=double(data(:));
if any(~isfinite(t)), return; end
[t,index]=sort(t,'ascend'); data=data(index);
entries(end+1,1)=struct('Name',string(name),'Time',t,'Data',data);
end

function out=joinName(parent,child)
parent=string(parent); child=string(child);
if parent=="" || parent=="Signal", out=child;
else, out=parent+"."+child; end
end

function n=safeSignalName(item)
% Do not assume Dataset elements expose Name (they can be plain structs).
n="";
try
    if isstruct(item)
        if isscalar(item) && isfield(item,'Name') && ...
                (ischar(item.Name) || isstring(item.Name))
            n=string(item.Name);
        end
    elseif isobject(item) && isprop(item,'Name')
        candidate=item.Name;
        if ischar(candidate) || isstring(candidate), n=string(candidate); end
    end
catch
    n="";
end
if ~isscalar(n), n=""; end
end
