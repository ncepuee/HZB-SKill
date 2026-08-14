function report = validate_migrated_model(modelFile, varargin)
%VALIDATE_MIGRATED_MODEL Run structural, compile, and short-simulation gates.

parser = inputParser;
addParameter(parser, 'ExpectedMode', 'native', ...
    @(x) any(strcmpi(char(x), {'native', 'legacy'})));
addParameter(parser, 'UpdateModel', true, @islogical);
addParameter(parser, 'ConfigureReleaseCache', true, @islogical);
addParameter(parser, 'SimulationStopTime', 0.02, ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
parse(parser, varargin{:});

if parser.Results.ConfigureReleaseCache
    resolvedFile = which(char(modelFile));
    if isempty(resolvedFile)
        resolvedFile = char(modelFile);
    end
    modelFolder = fileparts(resolvedFile);
    if isempty(modelFolder)
        modelFolder = pwd;
    end
    configure_release_filegen(modelFolder);
end

handle = load_system(modelFile);
model = get_param(handle, 'Name');
cleanup = onCleanup(@() closeIfLoaded(model));
risk = scan_model_migration_risks(model);

expectedMode = lower(char(parser.Results.ExpectedMode));
structurePassed = risk.unresolvedCount == 0;
if strcmp(expectedMode, 'native')
    structurePassed = structurePassed && risk.spsCount == 0 && ...
        risk.removedRuntimeCallbackCount == 0 && ...
        risk.connectedSolverConfigurationCount > 0;
end

updateAttempted = parser.Results.UpdateModel;
updatePassed = ~updateAttempted;
updateError = '';
if updateAttempted
    try
        set_param(model, 'SimulationCommand', 'update');
        updatePassed = true;
    catch ME
        updateError = getReport(ME, 'extended', 'hyperlinks', 'off');
    end
end

stopTime = parser.Results.SimulationStopTime;
simulationAttempted = ~isempty(stopTime);
simulationPassed = ~simulationAttempted;
simulationError = '';
if simulationAttempted && updatePassed
    originalReturnSetting = get_param(model, 'ReturnWorkspaceOutputs');
    try
        set_param(model, 'ReturnWorkspaceOutputs', 'off');
        sim(model, 'StopTime', num2str(stopTime, 17));
        simulationPassed = true;
    catch ME
        simulationError = getReport(ME, 'extended', 'hyperlinks', 'off');
    end
    set_param(model, 'ReturnWorkspaceOutputs', originalReturnSetting);
end

report = struct();
report.modelFile = char(modelFile);
report.model = model;
report.expectedMode = expectedMode;
report.risk = risk;
report.structurePassed = structurePassed;
report.updateAttempted = updateAttempted;
report.updatePassed = updatePassed;
report.updateError = updateError;
report.simulationAttempted = simulationAttempted;
report.simulationStopTime = stopTime;
report.simulationPassed = simulationPassed;
report.simulationError = simulationError;
report.passed = structurePassed && updatePassed && simulationPassed;
report.summary = sprintf(['mode=%s, unresolved=%d, SPS=%d, ' ...
    'callbacks=%d, update=%d, simulation=%d, passed=%d'], ...
    expectedMode, risk.unresolvedCount, risk.spsCount, ...
    risk.removedRuntimeCallbackCount, updatePassed, ...
    simulationPassed, report.passed);

fprintf('%s\n', report.summary);
if ~updatePassed
    fprintf(2, 'Update failed:\n%s\n', updateError);
end
if ~simulationPassed
    fprintf(2, 'Simulation failed:\n%s\n', simulationError);
end
end

function closeIfLoaded(model)
if bdIsLoaded(model)
    close_system(model, 0);
end
end
