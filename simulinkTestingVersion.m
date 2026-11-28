function version = simulinkTestingVersion()
%SIMULINKTESTINGVERSION Current SemVer version of Simulink Testing.
% VERSION is the single source of truth. Keep this file beside VERSION.
root = fileparts(mfilename('fullpath'));
version = strtrim(string(fileread(fullfile(root, 'VERSION'))));
if ~isscalar(version) || isempty(regexp(char(version), ...
        '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$', 'once'))
    error('SimulinkTesting:InvalidVersion', ...
        'VERSION must contain a valid semantic version, e.g. 1.3.0.');
end
end
