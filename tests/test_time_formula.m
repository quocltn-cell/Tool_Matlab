function test_time_formula()
%TEST_TIME_FORMULA Run in MATLAB from repository root:
%  addpath(pwd); test_time_formula
[tf,k,clock] = testcaseTimeFormula('= 0.4*CurrentTime');
assert(tf && abs(k-0.4)<eps && strcmpi(clock,'CurrentTime'));
[tf,k,clock] = testcaseTimeFormula(' = -2.5e-1 * EnableTime ');
assert(tf && abs(k+0.25)<eps && strcmpi(clock,'EnableTime'));
[tf,~,~] = testcaseTimeFormula('MotorSpeedParam');
assert(~tf);
[tf,~,~] = testcaseTimeFormula(25);
assert(~tf);
updates = struct('Value', '= 0.4*CurrentTime', 'Type', "I", 'Row', 5);
time = testcaseFormulaTimeline([0;0.025;0.05;0.1],updates,0.01);
assert(any(abs(time-0.025)<1e-12));
assert(any(abs(time-0.07)<1e-12));
assert(abs(0.4*time(end)-0.04)<1e-12);
updates.Value = '= 0.4*EnableTime';
time = testcaseFormulaTimeline([0;0.025;0.05],updates,0.01);
enableValue = 0.4*(time(time>=0.025)-0.025);
assert(abs(enableValue(1))<1e-12);
assert(abs(enableValue(end)-0.01)<1e-12);
caught = false;
try
    testcaseTimeFormula('= sin(CurrentTime)');
catch err
    caught = strcmp(err.identifier,'BusHarness:InvalidTimeFormula');
end
assert(caught,'Unsupported formulas must be rejected.');
updates.Type = "O";
caught = false;
try
    testcaseFormulaTimeline([0;0.1],updates,0.01);
catch err
    caught = strcmp(err.identifier,'BusHarness:TimeFormulaInputOnly');
end
assert(caught,'Output formulas must be rejected.');
fprintf('PASS: formula parser and fixed-step time grid\n');
end
