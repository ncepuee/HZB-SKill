function report = simulink_connection_guard(action, modelRef, baselineFile, options)
%SIMULINK_CONNECTION_GUARD Detect unintended Simulink wiring changes.
%   Use "baseline" before editing, "check" before saving, and "audit"
%   for a standalone structural check. The function never saves the model.

if nargin < 3, baselineFile = ''; end
if nargin < 4 || isempty(options), options = struct(); end
options = apply_defaults(options);
action = lower(string(action));
[model, modelFile, closeWhenDone] = resolve_model(modelRef);
cleanup = onCleanup(@() close_if_needed(model, closeWhenDone)); %#ok<NASGU>

if action == "baseline"
    if isempty(baselineFile)
        error('simulink_connection_guard:MissingBaselineFile', ...
            'baselineFile is required for the baseline action.');
    end
    if strcmp(get_param(model, 'Dirty'), 'on') && ~options.AllowDirtyBaseline
        error('simulink_connection_guard:DirtyModel', ...
            ['The model has unsaved changes. Resolve them before creating ' ...
             'a connection baseline, or explicitly set AllowDirtyBaseline=true.']);
    end
    compileIssue = try_update_model(model, options.CompileModel);
    baseline = make_snapshot(model, modelFile); %#ok<NASGU>
    baseline.CompileIssue = compileIssue;
    baselineFolder = fileparts(char(baselineFile));
    if ~isempty(baselineFolder) && ~isfolder(baselineFolder), mkdir(baselineFolder); end
    save(char(baselineFile), 'baseline', '-v7');
    backupFile = '';
    if options.CreateBackup && ~isempty(modelFile) && isfile(modelFile)
        [folder, name, ext] = fileparts(char(baselineFile));
        backupFile = fullfile(folder, [name '_model_backup' ext_for_model(modelFile, ext)]);
        copyfile(modelFile, backupFile, 'f');
    end
    report = struct('Action', 'baseline', 'Passed', true, ...
        'Model', model, 'BaselineFile', char(baselineFile), ...
        'BackupFile', backupFile, 'Snapshot', baseline);
    fprintf('CONNECTION_BASELINE_OK model=%s lines=%d ports=%d blocks=%d\n', ...
        model, numel(baseline.Lines), numel(baseline.Ports), numel(baseline.Blocks));
    return
end

compileIssue = try_update_model(model, options.CompileModel);
current = make_snapshot(model, modelFile);
audit = audit_snapshot(model, current);

if action == "audit"
    violations = audit.ExternalPIDIssues;
    if options.RequireCompilePass && ~isempty(compileIssue)
        violations{end+1,1} = ['MODEL_UPDATE_FAILED: ' compileIssue];
    end
    report = build_audit_report(model, current, audit, violations, compileIssue);
    finish_report(report, options);
    return
end

if action ~= "check"
    error('simulink_connection_guard:InvalidAction', ...
        'Action must be baseline, check, or audit.');
end
if isempty(baselineFile) || ~isfile(baselineFile)
    error('simulink_connection_guard:BaselineNotFound', ...
        'Baseline file not found: %s', char(baselineFile));
end
loaded = load(char(baselineFile), 'baseline');
baseline = loaded.baseline;
report = compare_snapshots(model, baseline, current, audit, options);
if options.RequireCompilePass && ~isempty(compileIssue)
    report.Violations{end+1,1} = ['MODEL_UPDATE_FAILED: ' compileIssue];
end
report.Passed = isempty(report.Violations);
finish_report(report, options);
end

function options = apply_defaults(options)
defaults = struct( ...
    'ModifiedScopes', {{}}, ...
    'AllowedRemovedLines', {{}}, ...
    'AllowedAddedLines', {{}}, ...
    'AllowedDisconnectedPorts', {{}}, ...
    'AllowDirtyBaseline', false, ...
    'CreateBackup', true, ...
    'CompileModel', true, ...
    'RequireCompilePass', true, ...
    'ThrowOnFailure', true);
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(options, names{i}), options.(names{i}) = defaults.(names{i}); end
end
options.ModifiedScopes = cellstr(string(options.ModifiedScopes));
options.AllowedRemovedLines = cellstr(string(options.AllowedRemovedLines));
options.AllowedAddedLines = cellstr(string(options.AllowedAddedLines));
options.AllowedDisconnectedPorts = cellstr(string(options.AllowedDisconnectedPorts));
end

function [model, modelFile, closeWhenDone] = resolve_model(modelRef)
ref = char(modelRef);
if isfile(ref)
    modelFile = char(java.io.File(ref).getCanonicalPath());
    [folder, model] = fileparts(modelFile);
    if ~contains(path, folder), addpath(folder); end
else
    [~, candidate, ext] = fileparts(ref);
    if isempty(ext), candidate = ref; end
    model = candidate;
    modelFile = which(ref);
    if isempty(modelFile) && bdIsLoaded(model), modelFile = get_param(model, 'FileName'); end
end
wasLoaded = bdIsLoaded(model);
if ~wasLoaded
    if ~isempty(modelFile), load_system(modelFile); else, load_system(model); end
end
closeWhenDone = ~wasLoaded;
if isempty(modelFile), modelFile = get_param(model, 'FileName'); end
end

function issue = try_update_model(model, enabled)
issue = '';
if ~enabled, return; end
try
    set_param(model, 'SimulationCommand', 'update');
catch ME
    issue = ME.message;
end
end

function snapshot = make_snapshot(model, modelFile)
snapshot = struct();
snapshot.Version = 1;
snapshot.ModelFile = modelFile;
snapshot.Created = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
snapshot.Blocks = snapshot_blocks(model);
snapshot.Lines = snapshot_lines(model);
snapshot.Ports = snapshot_ports(model);
end

function blocks = snapshot_blocks(model)
paths = find_blocks_all_variants(model);
blocks = repmat(struct('Path','','BlockType','','Commented','', ...
    'Ports',[],'MaskType','','GotoTag','','TagVisibility','', ...
    'ControllerParametersSource','','ExternalReset',''), numel(paths), 1);
for i = 1:numel(paths)
    blocks(i).Path = relative_path(paths{i}, model);
    blocks(i).BlockType = safe_param(paths{i}, 'BlockType');
    blocks(i).Commented = safe_param(paths{i}, 'Commented');
    blocks(i).Ports = safe_param(paths{i}, 'Ports');
    blocks(i).MaskType = safe_param(paths{i}, 'MaskType');
    blocks(i).GotoTag = safe_param(paths{i}, 'GotoTag');
    blocks(i).TagVisibility = safe_param(paths{i}, 'TagVisibility');
    blocks(i).ControllerParametersSource = ...
        safe_param(paths{i}, 'ControllerParametersSource');
    blocks(i).ExternalReset = safe_param(paths{i}, 'ExternalReset');
end
[~, order] = sort({blocks.Path});
blocks = blocks(order);
end

function lines = snapshot_lines(model)
try
    handles = find_system(model, 'FindAll', 'on', ...
        'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'MatchFilter', @Simulink.match.allVariants, 'Type', 'Line');
catch
    handles = find_system(model, 'FindAll', 'on', ...
        'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'Line');
end
lines = {};
for i = 1:numel(handles)
    try
        sourcePort = get_param(handles(i), 'SrcPortHandle');
        destinationPorts = get_param(handles(i), 'DstPortHandle');
    catch
        continue
    end
    if isempty(sourcePort) || sourcePort < 0 || isempty(destinationPorts)
        continue
    end
    for j = 1:numel(destinationPorts)
        if destinationPorts(j) < 0, continue; end
        try
            sourceBlock = get_param(sourcePort, 'Parent');
            destinationBlock = get_param(destinationPorts(j), 'Parent');
            lines{end+1,1} = sprintf('%s.%s%d -> %s.%s%d', ... %#ok<AGROW>
                relative_path(sourceBlock, model), get_param(sourcePort, 'PortType'), ...
                get_param(sourcePort, 'PortNumber'), ...
                relative_path(destinationBlock, model), ...
                get_param(destinationPorts(j), 'PortType'), ...
                get_param(destinationPorts(j), 'PortNumber'));
        catch
        end
    end
end
lines = sort(unique(lines));
end

function ports = snapshot_ports(model)
blocks = find_blocks_all_variants(model);
ports = repmat(struct('Key','','BlockPath','','Kind','','Number',0, ...
    'Connected',false), 0, 1);
kinds = {'Inport','Enable','Trigger','Ifaction','Reset','LConn','RConn'};
for i = 1:numel(blocks)
    try, handles = get_param(blocks{i}, 'PortHandles'); catch, continue; end
    for k = 1:numel(kinds)
        if ~isfield(handles, kinds{k}), continue; end
        values = handles.(kinds{k});
        for n = 1:numel(values)
            if values(n) < 0, continue; end
            item = struct();
            item.BlockPath = relative_path(blocks{i}, model);
            item.Kind = kinds{k};
            item.Number = n;
            item.Key = sprintf('%s|%s|%d', item.BlockPath, item.Kind, n);
            try, line = get_param(values(n), 'Line'); item.Connected = any(line >= 0); ...
            catch, item.Connected = false; end
            ports(end+1,1) = item; %#ok<AGROW>
        end
    end
end
[~, order] = sort({ports.Key});
ports = ports(order);
end

function audit = audit_snapshot(model, snapshot)
audit = struct('DanglingLines', {{}}, 'ExternalPIDIssues', {{}}, ...
    'UnconnectedInputWarnings', {{}});
% Audit active line trees. Inactive Variant internals are protected by the
% baseline diff and external-PID checks, but their branch objects can look
% dangling when inspected outside the active compiled configuration.
try
    handles = find_system(model, 'FindAll', 'on', ...
        'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'MatchFilter', @Simulink.match.allVariants, 'Type', 'Line');
catch
    handles = find_system(model, 'FindAll', 'on', ...
        'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'Line');
end
for i = 1:numel(handles)
    try
        source = get_param(handles(i), 'SrcPortHandle');
        destination = get_param(handles(i), 'DstPortHandle');
        parent = get_param(handles(i), 'LineParent');
        children = get_param(handles(i), 'LineChildren');
        hasSource = (~isempty(source) && source >= 0) || ...
            (~isempty(parent) && parent >= 0);
        hasDestination = (~isempty(destination) && any(destination >= 0)) || ...
            (~isempty(children) && any(children >= 0));
        if ~hasSource || ~hasDestination
            audit.DanglingLines{end+1,1} = sprintf('DANGLING_LINE handle=%g', handles(i));
        end
    catch ME
        audit.DanglingLines{end+1,1} = ['DANGLING_LINE_READ_FAILED: ' ME.message];
    end
end

blocks = find_blocks_all_variants(model);
for i = 1:numel(blocks)
    if strcmpi(safe_param(blocks{i}, 'ControllerParametersSource'), 'external')
        try, handles = get_param(blocks{i}, 'PortHandles'); catch, continue; end
        for p = 1:numel(handles.Inport)
            if get_param(handles.Inport(p), 'Line') < 0
                audit.ExternalPIDIssues{end+1,1} = sprintf( ... %#ok<AGROW>
                    'UNCONNECTED_EXTERNAL_PID_PORT %s port%d', ...
                    relative_path(blocks{i}, model), p);
            end
        end
    end
end
end

function report = compare_snapshots(model, baseline, current, audit, options)
report = struct();
report.Action = 'check';
report.Model = model;
report.Passed = false;
report.Violations = {};
report.Warnings = [audit.UnconnectedInputWarnings; audit.DanglingLines];
report.DanglingLines = audit.DanglingLines;
report.ExternalPIDIssues = audit.ExternalPIDIssues;
report.UnexpectedRemovedLines = {};
report.UnexpectedAddedLines = {};
report.NewlyDisconnectedPorts = {};
report.ChangedBlockStates = {};

removed = setdiff(baseline.Lines, current.Lines, 'stable');
added = setdiff(current.Lines, baseline.Lines, 'stable');
for i = 1:numel(removed)
    if matches_any(removed{i}, options.AllowedRemovedLines), continue; end
    if ~touches_modified_scope(removed{i}, options.ModifiedScopes)
        report.UnexpectedRemovedLines{end+1,1} = removed{i}; %#ok<AGROW>
    end
end
for i = 1:numel(added)
    if matches_any(added{i}, options.AllowedAddedLines), continue; end
    if ~touches_modified_scope(added{i}, options.ModifiedScopes)
        report.UnexpectedAddedLines{end+1,1} = added{i}; %#ok<AGROW>
    end
end

basePortMap = struct_map(baseline.Ports, 'Key');
currentPortMap = struct_map(current.Ports, 'Key');
keys = basePortMap.keys;
for i = 1:numel(keys)
    key = keys{i}; basePort = basePortMap(key);
    if ~basePort.Connected, continue; end
    if ~isKey(currentPortMap, key) || ~currentPortMap(key).Connected
        if ~matches_any(key, options.AllowedDisconnectedPorts)
            report.NewlyDisconnectedPorts{end+1,1} = key; %#ok<AGROW>
        end
    end
end

baseBlockMap = struct_map(baseline.Blocks, 'Path');
currentBlockMap = struct_map(current.Blocks, 'Path');
allPaths = union(baseBlockMap.keys, currentBlockMap.keys);
for i = 1:numel(allPaths)
    blockPath = allPaths{i};
    if path_in_scopes(blockPath, options.ModifiedScopes), continue; end
    if ~isKey(baseBlockMap, blockPath)
        report.ChangedBlockStates{end+1,1} = ['ADDED_BLOCK ' blockPath]; %#ok<AGROW>
    elseif ~isKey(currentBlockMap, blockPath)
        report.ChangedBlockStates{end+1,1} = ['REMOVED_BLOCK ' blockPath]; %#ok<AGROW>
    elseif ~isequaln(baseBlockMap(blockPath), currentBlockMap(blockPath))
        report.ChangedBlockStates{end+1,1} = ['CHANGED_BLOCK_STATE ' blockPath]; %#ok<AGROW>
    end
end

report.Violations = [report.UnexpectedRemovedLines; ...
    report.UnexpectedAddedLines; report.NewlyDisconnectedPorts; ...
    report.ChangedBlockStates; report.ExternalPIDIssues];
report.Passed = isempty(report.Violations);
end

function report = build_audit_report(model, snapshot, audit, violations, compileIssue)
report = struct('Action','audit','Model',model,'Passed',isempty(violations), ...
    'Violations',{violations}, ...
    'Warnings',{[audit.UnconnectedInputWarnings; audit.DanglingLines]}, ...
    'DanglingLines',{audit.DanglingLines}, ...
    'ExternalPIDIssues',{audit.ExternalPIDIssues}, ...
    'CompileIssue',compileIssue,'Snapshot',snapshot);
end

function finish_report(report, options)
fprintf('CONNECTION_GUARD action=%s model=%s passed=%d violations=%d warnings=%d\n', ...
    report.Action, report.Model, report.Passed, numel(report.Violations), numel(report.Warnings));
for i = 1:numel(report.Violations), fprintf('  VIOLATION %s\n', report.Violations{i}); end
if ~report.Passed && options.ThrowOnFailure
    error('simulink_connection_guard:IntegrityFailure', ...
        'Connection integrity check failed with %d violation(s).', numel(report.Violations));
end
end

function blocks = find_blocks_all_variants(model)
try
    blocks = find_system(model, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'MatchFilter', @Simulink.match.allVariants, 'Type', 'Block');
catch
    blocks = find_system(model, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'Type', 'Block');
end
end

function map = struct_map(items, keyField)
map = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(items), map(items(i).(keyField)) = items(i); end
end

function tf = touches_modified_scope(line, scopes)
tf = false;
for i = 1:numel(scopes)
    scope = char(scopes{i});
    if isempty(scope), continue; end
    if startsWith(line, [scope '.']) || contains(line, [' -> ' scope '.'])
        tf = true; return
    end
end
end

function tf = path_in_scopes(blockPath, scopes)
tf = false;
for i = 1:numel(scopes)
    scope = char(scopes{i});
    if strcmp(blockPath, scope) || startsWith(blockPath, [scope '/'])
        tf = true; return
    end
end
end

function tf = matches_any(value, patterns)
tf = false;
for i = 1:numel(patterns)
    if contains(value, patterns{i}), tf = true; return; end
end
end

function value = safe_param(target, parameter)
try, value = get_param(target, parameter); catch, value = ''; end
end

function pathValue = relative_path(fullPath, model)
if strcmp(fullPath, model), pathValue = '<ROOT>';
else, pathValue = char(extractAfter(string(fullPath), strlength(string(model)) + 1)); end
end

function ext = ext_for_model(modelFile, fallbackExt)
[~,~,ext] = fileparts(modelFile);
if isempty(ext), ext = fallbackExt; end
if isempty(ext), ext = '.slx'; end
end

function close_if_needed(model, closeWhenDone)
if closeWhenDone && bdIsLoaded(model), close_system(model, 0); end
end
