function names = harnessScenarioNames(testcases)
%HARNESSSCENARIONAMES Convert Excel testcase names to Signal Editor MAT variable names.
names = string(matlab.lang.makeUniqueStrings(matlab.lang.makeValidName( ...
    cellstr(string(testcases(:)))), {}, namelengthmax));
names = names(:);
end
