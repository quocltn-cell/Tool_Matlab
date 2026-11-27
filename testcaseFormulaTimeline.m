function time = testcaseFormulaTimeline(baseTime, updates, fixedStep)
%TESTCASEFORMULATIMELINE Add fixed-step samples only when an input has formula.
% Keeps all original event times (seconds) including non-grid steps.
time = unique(double(baseTime(:)));
if isempty(time)
    time = [0; 1];
end
hasFormula = false;
for k = 1:numel(updates)
    [formula, ~, ~] = testcaseTimeFormula(updates(k).Value);
    if formula
        if updates(k).Type ~= "I"
            error('BusHarness:TimeFormulaInputOnly', ...
                'Excel row %d: CurrentTime/EnableTime formulas are supported only for input (I) signals.',updates(k).Row);
        end
        hasFormula = true;
    end
end
if ~hasFormula
    return
end
if ~isscalar(fixedStep) || ~isnumeric(fixedStep) || ...
        ~isfinite(fixedStep) || fixedStep <= 0
    error('BusHarness:TimeFormulaSampleTime', ...
        'Cannot determine a positive numeric harness fixed step for Value formulas.');
end
endTime = max(time);
count = floor(endTime / fixedStep + 1e-10);
if count > 250000
    error('BusHarness:TimeFormulaSamples', ...
        ['Formula needs more than 250000 timeline samples. ' ...
         'Reduce testcase duration or choose a larger model fixed step.']);
end
grid = (0:count)' * fixedStep;
time = unique([time; grid]);
end
