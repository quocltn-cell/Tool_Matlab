function [isFormula, factor, clock] = testcaseTimeFormula(raw)
%TESTCASETIMEFORMULA Parse a restricted Value formula, never evaluate Excel code.
% Supported: = 0.4*CurrentTime and = 0.4*EnableTime (case insensitive).
% CurrentTime uses absolute simulation time [s]; EnableTime starts at 0
% when the corresponding Excel update row takes effect.
text = strtrim(string(raw));
isFormula = false;
factor = [];
clock = "";
if ~isscalar(text) || ismissing(text) || ~startsWith(text, "=")
    return
end
pattern = '^=\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*\*\s*(CurrentTime|EnableTime)\s*$';
parts = regexpi(char(text), pattern, 'tokens', 'once');
if isempty(parts)
    error('BusHarness:InvalidTimeFormula', ...
        'Unsupported Value formula "%s". Use = 0.4*CurrentTime or = 0.4*EnableTime.',char(text));
end
factor = str2double(parts{1});
if ~isfinite(factor) || ~isreal(factor)
    error('BusHarness:InvalidTimeFormula', ...
        'Formula coefficient must be a finite real number: "%s".',char(text));
end
isFormula = true;
clock = string(parts{2});
end
