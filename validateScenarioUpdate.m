function summary = validateScenarioUpdate(matFile, updates)
%VALIDATESCENARIOUPDATE Validate MAT-only scenario updates for Fast Restart.
%   The compatibility check intentionally ignores Time and number of time
%   samples. It compares scenario port names/order and the class and
%   per-sample dimensions of every nested signal. It does not guarantee that
%   Simulink Test Manager retains a compiled snapshot across separate runs.
arguments
    matFile (1,1) string
    updates (1,1) struct
end
if ~isfile(matFile)
    error('SimulinkTesting:MissingMAT','Signal Editor MAT file is missing: %s',matFile);
end
vars = whos('-file',char(matFile));
datasetMask = strcmp({vars.class}, 'Simulink.SimulationData.Dataset');
existing = string({vars(datasetMask).name});
existing = existing(:);
if isempty(existing)
    error('SimulinkTesting:NoScenarios','MAT file contains no Signal Editor Dataset scenarios.');
end
changed = string(fieldnames(updates));
changed = changed(:);
reference = load(matFile,char(existing(1)));
referenceScenario = reference.(char(existing(1)));
for k=1:numel(changed)
    name = char(changed(k));
    if ~isa(updates.(name),'Simulink.SimulationData.Dataset')
        error('SimulinkTesting:InvalidScenario','Scenario "%s" is not a Dataset.',name);
    end
    if ismember(changed(k),existing)
        before = load(matFile,name);
        baseline = before.(name);
    else
        baseline = referenceScenario;
    end
    compareDataset(baseline,updates.(name),name);
end
summary = struct('Compatible',true,'Existing',existing, ...
    'Added',changed(~ismember(changed,existing)), ...
    'Updated',changed(ismember(changed,existing)));
end

function compareDataset(a,b,scenarioName)
na = string(getElementNames(a));
nb = string(getElementNames(b));
if ~isequal(na(:),nb(:))
    error('SimulinkTesting:InterfaceChanged', ...
        'Scenario "%s": Signal Editor port names/order changed. Use Build Harness.',scenarioName);
end
for i=1:numel(na)
    x=getElement(a,i); y=getElement(b,i);
    if isobject(x) && isprop(x,'Values') && isobject(y) && isprop(y,'Values')
        compareValue(x.Values,y.Values,scenarioName+" / "+na(i));
    else
        compareValue(x,y,scenarioName+" / "+na(i));
    end
end
end

function compareValue(a,b,path)
if ~strcmp(class(a),class(b))
    fail(path,'signal datatype changed');
end
if isa(a,'timeseries')
    da=a.Data; db=b.Data;
    if ~strcmp(class(da),class(db))
        fail(path,'sample datatype changed');
    end
    sa=size(da); sb=size(db);
    % Leading dimension is the time axis; number of samples may change.
    if isempty(sa),sa=1;end
    if isempty(sb),sb=1;end
    sa(1)=[]; sb(1)=[];
    if ~isequal(sa,sb)
        fail(path,'sample dimensions changed');
    end
elseif isstruct(a)
    fa=sort(string(fieldnames(a))); fb=sort(string(fieldnames(b)));
    if ~isequal(fa,fb) || ~isequal(size(a),size(b))
        fail(path,'bus fields or structure dimensions changed');
    end
    for k=1:numel(a)
        for n=1:numel(fa)
            key=char(fa(n));
            compareValue(a(k).(key),b(k).(key),path+"."+fa(n));
        end
    end
elseif isobject(a) && isprop(a,'Values') && isprop(b,'Values')
    compareValue(a.Values,b.Values,path);
else
    if ~isequal(size(a),size(b))
        fail(path,'signal dimensions changed');
    end
end
end

function fail(path,reason)
error('SimulinkTesting:InterfaceChanged', ...
    'MAT update is not Fast Restart compatible at "%s": %s. Use Build Harness.',path,reason);
end
