function report = scan_model_migration_risks(modelOrFile)
%SCAN_MODEL_MIGRATION_RISKS Audit links, SPS blocks, callbacks, and solvers.

[model, closeWhenDone] = loadModel(modelOrFile);
cleanup = onCleanup(@() closeIfNeeded(model, closeWhenDone));

blocks = find_system(model, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'off');
unresolved = repmat(struct('Block', '', 'Status', '', ...
    'BlockType', '', 'ReferenceBlock', '', 'MaskType', ''), 0, 1);
riskyCallbacks = repmat(struct('Block', '', 'Property', '', ...
    'RiskTypes', '', 'CodeSnippet', ''), 0, 1);
removedRuntimeCallbackCount = 0;
referenceSpsBlocks = {};

for k = 1:numel(blocks)
    status = safeGet(blocks{k}, 'LinkStatus');
    if any(strcmpi(status, {'unresolved', 'bad'}))
        unresolved(end + 1) = struct( ... %#ok<AGROW>
            'Block', blocks{k}, ...
            'Status', status, ...
            'BlockType', safeGet(blocks{k}, 'BlockType'), ...
            'ReferenceBlock', safeGet(blocks{k}, 'ReferenceBlock'), ...
            'MaskType', safeGet(blocks{k}, 'MaskType'));
    end

    referenceBlock = safeGet(blocks{k}, 'ReferenceBlock');
    if looksLikeSpsReference(referenceBlock)
        referenceSpsBlocks{end + 1} = blocks{k}; %#ok<AGROW>
    end

    try
        objectParameters = get_param(blocks{k}, 'ObjectParameters');
        callbackNames = fieldnames(objectParameters);
        callbackNames = callbackNames(endsWith(callbackNames, 'Fcn'));
    catch
        callbackNames = {};
    end
    for n = 1:numel(callbackNames)
        code = safeGet(blocks{k}, callbackNames{n});
        if isempty(code) || ~ischar(code)
            continue;
        end
        riskTypes = classifyCallback(code);
        if isempty(riskTypes)
            continue;
        end
        riskyCallbacks(end + 1) = struct( ... %#ok<AGROW>
            'Block', blocks{k}, ...
            'Property', callbackNames{n}, ...
            'RiskTypes', strjoin(riskTypes, ','), ...
            'CodeSnippet', shorten(code));
        if any(ismember(riskTypes, {'sps_rtmsupport', 'powericon'}))
            removedRuntimeCallbackCount = removedRuntimeCallbackCount + 1;
        end
    end
end

spsBlocks = [];
spsToolCount = 0;
spsError = '';
if exist('spsConversionFindBlocks', 'file') ~= 0
    try
        spsBlocks = spsConversionFindBlocks(model);
        spsToolCount = collectionCount(spsBlocks);
    catch ME
        spsError = ME.message;
    end
end
referenceSpsBlocks = unique(referenceSpsBlocks, 'stable');
spsCount = max(spsToolCount, numel(referenceSpsBlocks));

solverConfigurations = find_system(model, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'off', 'MaskType', 'Solver Configuration');
solverConnected = false(size(solverConfigurations));
for k = 1:numel(solverConfigurations)
    solverConnected(k) = hasConnectedPhysicalPort(solverConfigurations{k});
end
powerguiBlocks = find_system(model, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'off', 'RegExp', 'on', 'Name', '(?i)^powergui$');

report = struct();
report.model = model;
report.unresolvedCount = numel(unresolved);
report.unresolved = unresolved;
report.spsCount = spsCount;
report.spsBlocks = spsBlocks;
report.spsToolCount = spsToolCount;
report.referenceSpsBlocks = referenceSpsBlocks;
report.spsScanError = spsError;
report.riskyCallbackCount = numel(riskyCallbacks);
report.removedRuntimeCallbackCount = removedRuntimeCallbackCount;
report.riskyCallbacks = riskyCallbacks;
report.solverConfigurations = solverConfigurations;
report.connectedSolverConfigurations = solverConfigurations(solverConnected);
report.connectedSolverConfigurationCount = sum(solverConnected);
report.powerguiBlocks = powerguiBlocks;
report.nativeReady = report.unresolvedCount == 0 && ...
    report.spsCount == 0 && report.removedRuntimeCallbackCount == 0 && ...
    report.connectedSolverConfigurationCount > 0;

fprintf('Model: %s\n', model);
fprintf('Unresolved links: %d\n', report.unresolvedCount);
fprintf('SPS references: %d\n', report.spsCount);
fprintf('Risky callbacks: %d (removed-runtime: %d)\n', ...
    report.riskyCallbackCount, report.removedRuntimeCallbackCount);
fprintf('Solver Configuration blocks: %d\n', ...
    numel(report.solverConfigurations));
fprintf('Connected Solver Configuration blocks: %d\n', ...
    report.connectedSolverConfigurationCount);
end

function tf = looksLikeSpsReference(referenceBlock)
if isempty(referenceBlock) || ~ischar(referenceBlock)
    tf = false;
    return;
end
name = lower(referenceBlock);
tf = startsWith(name, 'sps') || startsWith(name, 'powerlib/') || ...
    contains(name, '/powergui');
end

function count = collectionCount(value)
if istable(value) || istimetable(value)
    count = height(value);
elseif isempty(value)
    count = 0;
else
    count = numel(value);
end
end

function tf = hasConnectedPhysicalPort(block)
tf = false;
try
    handles = get_param(block, 'PortHandles');
catch
    return;
end
for field = {'LConn', 'RConn'}
    ports = handles.(field{1});
    for k = 1:numel(ports)
        try
            if get_param(ports(k), 'Line') ~= -1
                tf = true;
                return;
            end
        catch
        end
    end
end
end

function [model, closeWhenDone] = loadModel(modelOrFile)
modelOrFile = char(modelOrFile);
if bdIsLoaded(modelOrFile)
    model = modelOrFile;
    closeWhenDone = false;
elseif exist(modelOrFile, 'file')
    handle = load_system(modelOrFile);
    model = get_param(handle, 'Name');
    closeWhenDone = true;
else
    handle = load_system(modelOrFile);
    model = get_param(handle, 'Name');
    closeWhenDone = true;
end
end

function closeIfNeeded(model, closeWhenDone)
if closeWhenDone && bdIsLoaded(model)
    close_system(model, 0);
end
end

function value = safeGet(block, parameter)
try
    value = get_param(block, parameter);
catch
    value = '';
end
end

function risks = classifyCallback(code)
lowerCode = lower(code);
risks = {};
tokens = {'save_system', 'cd(', 'sps_rtmsupport', 'powericon'};
for k = 1:numel(tokens)
    if contains(lowerCode, lower(tokens{k}))
        risks{end + 1} = tokens{k}; %#ok<AGROW>
    end
end
end

function text = shorten(code)
text = regexprep(code, '\s+', ' ');
if numel(text) > 240
    text = [text(1:240) '...'];
end
end
