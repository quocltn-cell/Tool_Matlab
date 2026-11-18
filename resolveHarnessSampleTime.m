function period = resolveHarnessSampleTime(model)
%RESOLVEHARNESSSAMPLETIME Fundamental fixed-step size of a source model (s).
% Numeric FixedStep is authoritative. If it is 'auto', ask Simulink for the
% compiled step or derive a common base tick from discrete sample periods.
% Never replace a missing value with an arbitrary cursor increment.
model = char(string(model));
if ~bdIsLoaded(model), load_system(model); end
if ~strcmp(get_param(model,'SolverType'),'Fixed-step')
    error('BusHarness:SolverType', ...
        'Referenced model "%s" is not Fixed-step. A discrete fixed-step harness cannot copy a variable-step size.',model);
end
raw = char(get_param(model,'FixedStep'));
period = str2double(raw);
if ~(isfinite(period) && period > 0)
    try
        resolved = slResolve(raw,model);
        if isnumeric(resolved) && isscalar(resolved)
            period = double(resolved);
        end
    catch
    end
end
if isfinite(period) && period > 0, return; end
% For 'auto' the value is only known after model compilation.
try
    set_param(model,'SimulationCommand','update');
    period = str2double(num2str(get_param(model,'CompiledStepSize')));
catch
    period = NaN;
end
if isfinite(period) && period > 0, return; end
try
    samples = Simulink.BlockDiagram.getSampleTimes(model);
    rates = [];
    for k=1:numel(samples)
        value = samples(k).SampleTime;
        if isnumeric(value) && ~isempty(value)
            value = double(value(1));
            if isfinite(value) && value > 0
                rates(end+1) = value; %#ok<AGROW>
            end
        end
    end
    if ~isempty(rates)
        % Greatest common divisor of periodic rates, expressed in ns.
        ticks = round(rates * 1e9);
        if all(ticks > 0) && all(abs(ticks/1e9-rates)<1e-9)
            common = ticks(1);
            for k=2:numel(ticks), common = gcd(common,ticks(k)); end
            period = double(common)/1e9;
        end
    end
catch
end
if ~(isscalar(period) && isfinite(period) && period > 0)
    error('BusHarness:SampleTime', ...
        ['Cannot resolve fundamental sample time of referenced model "%s". ' ...
         'Set an explicit numeric Fixed-step size in its Solver configuration, then rebuild the harness.'],model);
end
end
