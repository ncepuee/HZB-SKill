function report = simulink_connection_guard(action, modelRef, baselineFile, options)
%SIMULINK_CONNECTION_GUARD Detect unintended Simulink wiring changes.
%   Actions:
%     baseline     Capture an in-memory topology and an on-disk SLX package.
%     check        Compare the loaded model with a baseline before saving.
%     packagecheck Compare the saved SLX package without loading the model.
%     audit        Run a standalone structural audit.
%
%   Profiles:
%     fast         Lines, critical block states, contracts, package snapshot.
%     standard     fast plus input-port and dangling/external-PID checks.
%     release      standard plus model update/compile requirements.
%
%   The function never saves the model.

if nargin < 3, baselineFile = ''; end
if nargin < 4 || isempty(options), options = struct(); end
options = apply_defaults(options);
action = lower(string(action));
started = tic;

if ismember(action, ["packagecheck", "postsave"])
    report = run_package_check(modelRef, baselineFile, options);
    report.DurationSeconds = toc(started);
    finish_report(report, options);
    return
end

[model, modelFile, closeWhenDone] = resolve_model(modelRef);
cleanup = onCleanup(@() close_if_needed(model, closeWhenDone)); %#ok<NASGU>

if action == "baseline"
    require_baseline_file(baselineFile);
    if strcmp(get_param(model, 'Dirty'), 'on') && ~options.AllowDirtyBaseline
        error('simulink_connection_guard:DirtyModel', ...
            ['The model has unsaved changes. Resolve them before creating ' ...
             'a connection baseline, or explicitly set AllowDirtyBaseline=true.']);
    end
    compileIssue = try_update_model(model, options.CompileModel);
    inventory = collect_inventory(model, options);
    baseline = make_snapshot(model, modelFile, inventory, options); %#ok<NASGU>
    baseline.CompileIssue = compileIssue;
    baseline.Profile = options.Profile;
    baseline.Package = snapshot_slx_package(modelFile, options.CapturePackageSnapshot);
    baselineFolder = fileparts(char(baselineFile));
    if ~isempty(baselineFolder) && ~isfolder(baselineFolder), mkdir(baselineFolder); end
    save(char(baselineFile), 'baseline', '-v7');
    backupFile = create_disk_backup(modelFile, baselineFile, options.CreateBackup);
    report = struct('Action', 'baseline', 'Profile', options.Profile, ...
        'Passed', true, 'Model', model, 'BaselineFile', char(baselineFile), ...
        'BackupFile', backupFile, 'Snapshot', baseline, ...
        'Violations', {{}}, 'Warnings', {{}});
    report.DurationSeconds = toc(started);
    fprintf(['CONNECTION_BASELINE_OK profile=%s model=%s lines=%d ' ...
        'ports=%d blocks=%d duration=%.3fs\n'], options.Profile, model, ...
        numel(baseline.Lines), numel(baseline.Ports), ...
        numel(baseline.Blocks), report.DurationSeconds);
    return
end

compileIssue = try_update_model(model, options.CompileModel);
if action == "check"
    baseline = load_baseline(baselineFile);
    options = inherit_baseline_contracts(options, baseline);
end
inventory = collect_inventory(model, options);
current = make_snapshot(model, modelFile, inventory, options);
audit = audit_inventory(model, inventory, options);

if action == "audit"
    violations = audit.ExternalPIDIssues;
    if options.RequireCompilePass && ~isempty(compileIssue)
        violations{end+1,1} = ['MODEL_UPDATE_FAILED: ' compileIssue];
    end
    report = build_audit_report(model, current, audit, violations, ...
        compileIssue, options.Profile);
elseif action == "check"
    report = compare_snapshots(model, baseline, current, audit, options);
    if options.RequireCompilePass && ~isempty(compileIssue)
        report.Violations{end+1,1} = ['MODEL_UPDATE_FAILED: ' compileIssue];
    end
    report.Passed = isempty(report.Violations);
else
    error('simulink_connection_guard:InvalidAction', ...
        'Action must be baseline, check, packagecheck, or audit.');
end

report.DurationSeconds = toc(started);
finish_report(report, options);
end

function options = apply_defaults(options)
if ~isfield(options, 'Profile') || isempty(options.Profile)
    options.Profile = 'standard';
end
options.Profile = char(lower(string(options.Profile)));
if ~ismember(options.Profile, {'fast', 'standard', 'release'})
    error('simulink_connection_guard:InvalidProfile', ...
        'Profile must be fast, standard, or release.');
end

profile = profile_defaults(options.Profile);
common = struct( ...
    'ModifiedScopes', {{}}, ...
    'AllowedRemovedLines', {{}}, ...
    'AllowedAddedLines', {{}}, ...
    'AllowedDisconnectedPorts', {{}}, ...
    'AllowDirtyBaseline', false, ...
    'CreateBackup', true, ...
    'ThrowOnFailure', true, ...
    'CapturePackageSnapshot', true, ...
    'PreserveModelCallbacks', false, ...
    'ModelCallbackNames', {{'PreLoadFcn','PostLoadFcn','InitFcn','StartFcn'}}, ...
    'ProtectedMaskParameters', {cell(0,2)}, ...
    'PackageAllowLineChanges', false, ...
    'PackageAllowBlockCountChanges', false);
options = fill_missing(options, common);
options = fill_missing(options, profile);

options.ModifiedScopes = cellstr(string(options.ModifiedScopes));
options.AllowedRemovedLines = cellstr(string(options.AllowedRemovedLines));
options.AllowedAddedLines = cellstr(string(options.AllowedAddedLines));
options.AllowedDisconnectedPorts = cellstr(string(options.AllowedDisconnectedPorts));
options.ModelCallbackNames = cellstr(string(options.ModelCallbackNames));
options.ProtectedMaskParameters = normalize_mask_contract( ...
    options.ProtectedMaskParameters);
end

function defaults = profile_defaults(profile)
switch profile
    case 'fast'
        defaults = struct('CompileModel', false, ...
            'RequireCompilePass', false, 'CapturePorts', false, ...
            'AuditDanglingLines', false, 'CheckExternalPID', false);
    case 'standard'
        defaults = struct('CompileModel', false, ...
            'RequireCompilePass', false, 'CapturePorts', true, ...
            'AuditDanglingLines', true, 'CheckExternalPID', true);
    case 'release'
        defaults = struct('CompileModel', true, ...
            'RequireCompilePass', true, 'CapturePorts', true, ...
            'AuditDanglingLines', true, 'CheckExternalPID', true);
end
end

function target = fill_missing(target, defaults)
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(target, names{i}), target.(names{i}) = defaults.(names{i}); end
end
end

function contract = normalize_mask_contract(value)
if isempty(value)
    contract = cell(0,2);
    return
end
if ~iscell(value) || size(value,2) ~= 2
    error('simulink_connection_guard:InvalidMaskContract', ...
        ['ProtectedMaskParameters must be an N-by-2 cell array: ' ...
         '{blockPath, {parameterNames}}.']);
end
contract = value;
for i = 1:size(contract,1)
    contract{i,1} = char(string(contract{i,1}));
    contract{i,2} = cellstr(string(contract{i,2}));
end
end

function options = inherit_baseline_contracts(options, baseline)
if ~isfield(baseline, 'ContractDefinition'), return; end
definition = baseline.ContractDefinition;
options.PreserveModelCallbacks = definition.PreserveModelCallbacks;
options.ModelCallbackNames = definition.ModelCallbackNames;
options.ProtectedMaskParameters = definition.ProtectedMaskParameters;
end

function require_baseline_file(baselineFile)
if isempty(baselineFile)
    error('simulink_connection_guard:MissingBaselineFile', ...
        'baselineFile is required for the baseline action.');
end
end

function baseline = load_baseline(baselineFile)
if isempty(baselineFile) || ~isfile(baselineFile)
    error('simulink_connection_guard:BaselineNotFound', ...
        'Baseline file not found: %s', char(baselineFile));
end
loaded = load(char(baselineFile), 'baseline');
baseline = loaded.baseline;
baseline = normalize_snapshot(baseline);
end

function snapshot = normalize_snapshot(snapshot)
if ~isfield(snapshot, 'Ports')
    snapshot.Ports = repmat(empty_port(), 0, 1);
end
if ~isfield(snapshot, 'Contracts')
    snapshot.Contracts = empty_contracts();
end
if ~isfield(snapshot, 'ContractDefinition')
    snapshot.ContractDefinition = empty_contract_definition();
end
end

function [model, modelFile, closeWhenDone] = resolve_model(modelRef)
ref = char(modelRef);
if isfile(ref)
    modelFile = canonical_path(ref);
    [folder, model] = fileparts(modelFile);
    if ~contains(path, folder), addpath(folder); end
else
    [~, candidate, ext] = fileparts(ref);
    if isempty(ext), candidate = ref; end
    model = candidate;
    modelFile = which(ref);
    if isempty(modelFile) && bdIsLoaded(model)
        modelFile = get_param(model, 'FileName');
    end
end
wasLoaded = bdIsLoaded(model);
if ~wasLoaded
    if ~isempty(modelFile), load_system(modelFile); else, load_system(model); end
end
closeWhenDone = ~wasLoaded;
if isempty(modelFile), modelFile = get_param(model, 'FileName'); end
end

function modelFile = resolve_model_file(modelRef)
ref = char(modelRef);
if isfile(ref)
    modelFile = canonical_path(ref);
elseif bdIsLoaded(ref)
    modelFile = get_param(ref, 'FileName');
else
    modelFile = which(ref);
end
if isempty(modelFile) || ~isfile(modelFile)
    error('simulink_connection_guard:ModelFileNotFound', ...
        'Model file not found: %s', ref);
end
end

function value = canonical_path(value)
value = char(java.io.File(value).getCanonicalPath());
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

function inventory = collect_inventory(model, options)
inventory = struct();
inventory.Blocks = find_blocks_all_variants(model);
inventory.Lines = find_lines_all_variants(model);
inventory.NeedPorts = options.CapturePorts;
end

function handles = find_lines_all_variants(model)
try
    handles = find_system(model, 'FindAll', 'on', ...
        'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'MatchFilter', @Simulink.match.allVariants, 'Type', 'Line');
catch
    handles = find_system(model, 'FindAll', 'on', ...
        'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'Line');
end
end

function snapshot = make_snapshot(model, modelFile, inventory, options)
snapshot = struct();
snapshot.Version = 2;
snapshot.Profile = options.Profile;
snapshot.ModelFile = modelFile;
snapshot.Created = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
snapshot.Blocks = snapshot_blocks(model, inventory.Blocks);
snapshot.Lines = snapshot_lines(model, inventory.Lines);
if options.CapturePorts
    snapshot.Ports = snapshot_ports(model, inventory.Blocks);
else
    snapshot.Ports = repmat(empty_port(), 0, 1);
end
[snapshot.Contracts, snapshot.ContractDefinition] = ...
    snapshot_contracts(model, options);
end

function blocks = snapshot_blocks(model, paths)
template = struct('Path','','BlockType','','Commented','', ...
    'Ports',[],'MaskType','','GotoTag','','TagVisibility','', ...
    'ControllerParametersSource','','ExternalReset','');
blocks = repmat(template, numel(paths), 1);
blockTypes = batch_safe_param(paths, 'BlockType');
commented = batch_safe_param(paths, 'Commented');
ports = batch_safe_param(paths, 'Ports');
maskTypes = batch_safe_param(paths, 'MaskType');
gotoTags = empty_values(paths);
tagVisibility = empty_values(paths);
parameterSources = empty_values(paths);
externalReset = empty_values(paths);

gotoIndices = find(ismember(blockTypes, ...
    {'Goto','From','GotoTagVisibility'}));
gotoTags = fill_selected_param(gotoTags, paths, gotoIndices, 'GotoTag');
visibilityIndices = find(strcmp(blockTypes, 'Goto'));
tagVisibility = fill_selected_param( ...
    tagVisibility, paths, visibilityIndices, 'TagVisibility');

pidIndices = find(contains(string(maskTypes), 'PID', 'IgnoreCase', true));
parameterSources = fill_selected_param(parameterSources, paths, ...
    pidIndices, 'ControllerParametersSource');
resetIndices = find(ismember(blockTypes, ...
    {'Integrator','DiscreteIntegrator'}));
resetIndices = union(resetIndices, pidIndices);
externalReset = fill_selected_param(externalReset, paths, ...
    resetIndices, 'ExternalReset');
for i = 1:numel(paths)
    blocks(i).Path = relative_path(paths{i}, model);
    blocks(i).BlockType = blockTypes{i};
    blocks(i).Commented = commented{i};
    blocks(i).Ports = ports{i};
    blocks(i).MaskType = maskTypes{i};
    blocks(i).GotoTag = gotoTags{i};
    blocks(i).TagVisibility = tagVisibility{i};
    blocks(i).ControllerParametersSource = parameterSources{i};
    blocks(i).ExternalReset = externalReset{i};
end
[~, order] = sort({blocks.Path});
blocks = blocks(order);
end

function lines = snapshot_lines(model, handles)
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
                relative_path(sourceBlock, model), ...
                get_param(sourcePort, 'PortType'), ...
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

function ports = snapshot_ports(model, blocks)
ports = repmat(empty_port(), 0, 1);
kinds = {'Inport','Enable','Trigger','Ifaction','Reset','LConn','RConn'};
allHandles = batch_safe_param(blocks, 'PortHandles');
for i = 1:numel(blocks)
    handles = allHandles{i};
    if ~isstruct(handles)
        continue
    end
    for k = 1:numel(kinds)
        if ~isfield(handles, kinds{k}), continue; end
        values = handles.(kinds{k});
        for n = 1:numel(values)
            if values(n) < 0, continue; end
            item = empty_port();
            item.BlockPath = relative_path(blocks{i}, model);
            item.Kind = kinds{k};
            item.Number = n;
            item.Key = sprintf('%s|%s|%d', item.BlockPath, item.Kind, n);
            try
                line = get_param(values(n), 'Line');
                item.Connected = any(line >= 0);
            catch
                item.Connected = false;
            end
            ports(end+1,1) = item; %#ok<AGROW>
        end
    end
end
[~, order] = sort({ports.Key});
ports = ports(order);
end

function item = empty_port()
item = struct('Key','','BlockPath','','Kind','','Number',0, ...
    'Connected',false);
end

function [contracts, definition] = snapshot_contracts(model, options)
definition = struct( ...
    'PreserveModelCallbacks', logical(options.PreserveModelCallbacks), ...
    'ModelCallbackNames', {options.ModelCallbackNames}, ...
    'ProtectedMaskParameters', {options.ProtectedMaskParameters});
contracts = empty_contracts();

if options.PreserveModelCallbacks
    for i = 1:numel(options.ModelCallbackNames)
        item = struct('Name', options.ModelCallbackNames{i}, ...
            'Value', safe_param(model, options.ModelCallbackNames{i}));
        contracts.ModelCallbacks(end+1,1) = item; %#ok<AGROW>
    end
end

for row = 1:size(options.ProtectedMaskParameters,1)
    relativeBlock = options.ProtectedMaskParameters{row,1};
    fullBlock = full_block_path(model, relativeBlock);
    if getSimulinkBlockHandle(fullBlock) < 0
        error('simulink_connection_guard:ProtectedBlockNotFound', ...
            'Protected mask block not found: %s', relativeBlock);
    end
    names = options.ProtectedMaskParameters{row,2};
    for i = 1:numel(names)
        try
            value = get_param(fullBlock, names{i});
        catch ME
            error('simulink_connection_guard:ProtectedMaskParameterNotFound', ...
                'Cannot read %s/%s: %s', relativeBlock, names{i}, ME.message);
        end
        item = struct('BlockPath', relative_path(fullBlock, model), ...
            'Parameter', names{i}, 'Value', value);
        contracts.MaskParameters(end+1,1) = item; %#ok<AGROW>
    end
end
end

function contracts = empty_contracts()
contracts = struct('ModelCallbacks', repmat( ...
    struct('Name','','Value',''), 0, 1), ...
    'MaskParameters', repmat( ...
    struct('BlockPath','','Parameter','','Value',''), 0, 1));
end

function definition = empty_contract_definition()
definition = struct('PreserveModelCallbacks', false, ...
    'ModelCallbackNames', {{'PreLoadFcn','PostLoadFcn','InitFcn','StartFcn'}}, ...
    'ProtectedMaskParameters', {cell(0,2)});
end

function fullPath = full_block_path(model, pathValue)
pathValue = char(pathValue);
if strcmp(pathValue, '<ROOT>') || strcmp(pathValue, model)
    fullPath = model;
elseif startsWith(pathValue, [model '/'])
    fullPath = pathValue;
else
    fullPath = [model '/' pathValue];
end
end

function audit = audit_inventory(model, inventory, options)
audit = struct('DanglingLines', {{}}, 'ExternalPIDIssues', {{}}, ...
    'UnconnectedInputWarnings', {{}});
if options.AuditDanglingLines
    audit.DanglingLines = audit_dangling_lines(inventory.Lines);
end
if options.CheckExternalPID
    audit.ExternalPIDIssues = audit_external_pid(model, inventory.Blocks);
end
end

function issues = audit_dangling_lines(handles)
issues = {};
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
            issues{end+1,1} = sprintf('DANGLING_LINE handle=%g', handles(i)); %#ok<AGROW>
        end
    catch ME
        issues{end+1,1} = ['DANGLING_LINE_READ_FAILED: ' ME.message]; %#ok<AGROW>
    end
end
end

function issues = audit_external_pid(model, blocks)
issues = {};
parameterSources = batch_safe_param(blocks, 'ControllerParametersSource');
allHandles = batch_safe_param(blocks, 'PortHandles');
for i = 1:numel(blocks)
    if ~strcmpi(parameterSources{i}, 'external')
        continue
    end
    handles = allHandles{i};
    if ~isstruct(handles)
        continue
    end
    for p = 1:numel(handles.Inport)
        if get_param(handles.Inport(p), 'Line') < 0
            issues{end+1,1} = sprintf( ... %#ok<AGROW>
                'UNCONNECTED_EXTERNAL_PID_PORT %s port%d', ...
                relative_path(blocks{i}, model), p);
        end
    end
end
end

function report = compare_snapshots(model, baseline, current, audit, options)
report = empty_check_report('check', model, options.Profile);
report.Warnings = [audit.UnconnectedInputWarnings; audit.DanglingLines];
report.DanglingLines = audit.DanglingLines;
report.ExternalPIDIssues = audit.ExternalPIDIssues;

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

if ~isempty(baseline.Ports) && ~isempty(current.Ports)
    report.NewlyDisconnectedPorts = compare_ports( ...
        baseline.Ports, current.Ports, options.AllowedDisconnectedPorts);
end
report.ChangedBlockStates = compare_block_states( ...
    baseline.Blocks, current.Blocks, options.ModifiedScopes);
report.ContractViolations = compare_contracts( ...
    baseline.Contracts, current.Contracts);
report.Violations = [report.UnexpectedRemovedLines; ...
    report.UnexpectedAddedLines; report.NewlyDisconnectedPorts; ...
    report.ChangedBlockStates; report.ExternalPIDIssues; ...
    report.ContractViolations];
report.Passed = isempty(report.Violations);
end

function issues = compare_ports(baseline, current, allowed)
issues = {};
basePortMap = struct_map(baseline, 'Key');
currentPortMap = struct_map(current, 'Key');
keys = basePortMap.keys;
for i = 1:numel(keys)
    key = keys{i};
    basePort = basePortMap(key);
    if ~basePort.Connected, continue; end
    if ~isKey(currentPortMap, key) || ~currentPortMap(key).Connected
        if ~matches_any(key, allowed)
            issues{end+1,1} = key; %#ok<AGROW>
        end
    end
end
end

function issues = compare_block_states(baseline, current, scopes)
issues = {};
baseMap = struct_map(baseline, 'Path');
currentMap = struct_map(current, 'Path');
allPaths = union(baseMap.keys, currentMap.keys);
for i = 1:numel(allPaths)
    blockPath = allPaths{i};
    if path_in_scopes(blockPath, scopes), continue; end
    if ~isKey(baseMap, blockPath)
        issues{end+1,1} = ['ADDED_BLOCK ' blockPath]; %#ok<AGROW>
    elseif ~isKey(currentMap, blockPath)
        issues{end+1,1} = ['REMOVED_BLOCK ' blockPath]; %#ok<AGROW>
    elseif ~isequaln(baseMap(blockPath), currentMap(blockPath))
        issues{end+1,1} = ['CHANGED_BLOCK_STATE ' blockPath]; %#ok<AGROW>
    end
end
end

function issues = compare_contracts(baseline, current)
issues = {};
issues = [issues; compare_contract_group( ...
    baseline.ModelCallbacks, current.ModelCallbacks, 'Name', ...
    'MODEL_CALLBACK_CHANGED')];
baseMask = add_contract_keys(baseline.MaskParameters);
currentMask = add_contract_keys(current.MaskParameters);
issues = [issues; compare_contract_group(baseMask, currentMask, 'Key', ...
    'MASK_PARAMETER_CHANGED')];
end

function items = add_contract_keys(items)
for i = 1:numel(items)
    items(i).Key = [items(i).BlockPath '|' items(i).Parameter];
end
end

function issues = compare_contract_group(baseline, current, keyField, prefix)
issues = {};
baseMap = struct_map(baseline, keyField);
currentMap = struct_map(current, keyField);
keys = baseMap.keys;
for i = 1:numel(keys)
    key = keys{i};
    if ~isKey(currentMap, key) || ...
            ~isequaln(baseMap(key).Value, currentMap(key).Value)
        issues{end+1,1} = sprintf('%s %s', prefix, key); %#ok<AGROW>
    end
end
end

function report = empty_check_report(action, model, profile)
report = struct('Action', action, 'Profile', profile, 'Model', model, ...
    'Passed', false, 'Violations', {{}}, 'Warnings', {{}}, ...
    'DanglingLines', {{}}, 'ExternalPIDIssues', {{}}, ...
    'UnexpectedRemovedLines', {{}}, 'UnexpectedAddedLines', {{}}, ...
    'NewlyDisconnectedPorts', {{}}, 'ChangedBlockStates', {{}}, ...
    'ContractViolations', {{}}, 'PackageLineChanges', {{}}, ...
    'PackageBlockCountChanges', {{}}, 'PackageSystemChanges', {{}});
end

function report = build_audit_report(model, snapshot, audit, violations, ...
        compileIssue, profile)
report = empty_check_report('audit', model, profile);
report.Passed = isempty(violations);
report.Violations = violations;
report.Warnings = [audit.UnconnectedInputWarnings; audit.DanglingLines];
report.DanglingLines = audit.DanglingLines;
report.ExternalPIDIssues = audit.ExternalPIDIssues;
report.CompileIssue = compileIssue;
report.Snapshot = snapshot;
end

function report = run_package_check(modelRef, baselineFile, options)
baseline = load_baseline(baselineFile);
if ~isfield(baseline, 'Package') || ~baseline.Package.Available
    error('simulink_connection_guard:PackageBaselineUnavailable', ...
        'The baseline does not contain an SLX package snapshot.');
end
modelFile = resolve_model_file(modelRef);
current = snapshot_slx_package(modelFile, true);
if ~current.Available
    error('simulink_connection_guard:PackageCheckUnsupported', ...
        'packagecheck supports saved .slx files only.');
end
[lineChanges, blockChanges, systemChanges] = ...
    compare_packages(baseline.Package, current);
report = empty_check_report('packagecheck', modelFile, options.Profile);
report.PackageLineChanges = lineChanges;
report.PackageBlockCountChanges = blockChanges;
report.PackageSystemChanges = systemChanges;
if ~options.PackageAllowLineChanges
    report.Violations = [report.Violations; lineChanges];
end
if ~options.PackageAllowBlockCountChanges
    report.Violations = [report.Violations; blockChanges; systemChanges];
end
report.Passed = isempty(report.Violations);
report.Package = current;
end

function package = snapshot_slx_package(modelFile, enabled)
package = struct('Available', false, 'ModelFile', modelFile, ...
    'Systems', repmat(struct('Entry','','Lines',{{}},'BlockCount',0), 0, 1));
if ~enabled || isempty(modelFile) || ~isfile(modelFile)
    return
end
[~,~,extension] = fileparts(modelFile);
if ~strcmpi(extension, '.slx'), return; end

zip = java.util.zip.ZipFile(java.io.File(modelFile));
cleanup = onCleanup(@() zip.close()); %#ok<NASGU>
entries = zip.entries();
systems = package.Systems;
while entries.hasMoreElements()
    entry = entries.nextElement();
    entryName = char(entry.getName());
    if ~startsWith(entryName, 'simulink/systems/') || ...
            ~endsWith(entryName, '.xml')
        continue
    end
    xml = read_zip_entry(zip, entry);
    lines = canonical_line_xml(xml);
    item = struct('Entry', entryName, 'Lines', {lines}, ...
        'BlockCount', numel(regexp(xml, '<Block(?:\s|>)', 'match')));
    systems(end+1,1) = item; %#ok<AGROW>
end
if ~isempty(systems)
    [~, order] = sort({systems.Entry});
    systems = systems(order);
end
package.Available = true;
package.Systems = systems;
end

function text = read_zip_entry(zip, entry)
stream = zip.getInputStream(entry);
cleanup = onCleanup(@() stream.close()); %#ok<NASGU>
scanner = java.util.Scanner(stream, 'UTF-8');
scannerCleanup = onCleanup(@() scanner.close()); %#ok<NASGU>
scanner.useDelimiter('\A');
if scanner.hasNext()
    text = char(scanner.next());
else
    text = '';
end
end

function lines = canonical_line_xml(xml)
lines = regexp(xml, '(?s)<Line(?:\s[^>]*)?>.*?</Line>', 'match');
for i = 1:numel(lines)
    value = lines{i};
    value = regexprep(value, ...
        '(?s)<P Name="(?:Points|Labels|ZOrder)">.*?</P>', '');
    value = regexprep(value, '>\s+<', '><');
    value = strtrim(value);
    lines{i} = value;
end
lines = sort(lines(:));
end

function [lineChanges, blockChanges, systemChanges] = ...
        compare_packages(baseline, current)
lineChanges = {};
blockChanges = {};
systemChanges = {};
baseMap = struct_map(baseline.Systems, 'Entry');
currentMap = struct_map(current.Systems, 'Entry');
allEntries = union(baseMap.keys, currentMap.keys);
for i = 1:numel(allEntries)
    entry = allEntries{i};
    if ~isKey(baseMap, entry)
        systemChanges{end+1,1} = ['ADDED_SYSTEM_XML ' entry]; %#ok<AGROW>
        continue
    elseif ~isKey(currentMap, entry)
        systemChanges{end+1,1} = ['REMOVED_SYSTEM_XML ' entry]; %#ok<AGROW>
        continue
    end
    baseItem = baseMap(entry);
    currentItem = currentMap(entry);
    removed = setdiff(baseItem.Lines, currentItem.Lines, 'stable');
    added = setdiff(currentItem.Lines, baseItem.Lines, 'stable');
    if ~isempty(removed) || ~isempty(added)
        lineChanges{end+1,1} = sprintf( ... %#ok<AGROW>
            'PACKAGE_LINE_CHANGE %s removed=%d added=%d', ...
            entry, numel(removed), numel(added));
    end
    if baseItem.BlockCount ~= currentItem.BlockCount
        blockChanges{end+1,1} = sprintf( ... %#ok<AGROW>
            'PACKAGE_BLOCK_COUNT_CHANGE %s before=%d after=%d', ...
            entry, baseItem.BlockCount, currentItem.BlockCount);
    end
end
end

function backupFile = create_disk_backup(modelFile, baselineFile, enabled)
backupFile = '';
if ~enabled || isempty(modelFile) || ~isfile(modelFile), return; end
[folder, name, fallbackExt] = fileparts(char(baselineFile));
backupFile = fullfile(folder, ...
    [name '_model_backup' ext_for_model(modelFile, fallbackExt)]);
copyfile(modelFile, backupFile, 'f');
end

function finish_report(report, options)
fprintf(['CONNECTION_GUARD action=%s profile=%s model=%s passed=%d ' ...
    'violations=%d warnings=%d duration=%.3fs\n'], ...
    report.Action, report.Profile, report.Model, report.Passed, ...
    numel(report.Violations), numel(report.Warnings), report.DurationSeconds);
for i = 1:numel(report.Violations)
    fprintf('  VIOLATION %s\n', report.Violations{i});
end
if ~report.Passed && options.ThrowOnFailure
    error('simulink_connection_guard:IntegrityFailure', ...
        'Connection integrity check failed with %d violation(s).', ...
        numel(report.Violations));
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
    sourceTouches = startsWith(line, [scope '.']) || ...
        startsWith(line, [scope '/']);
    destinationTouches = contains(line, [' -> ' scope '.']) || ...
        contains(line, [' -> ' scope '/']);
    if sourceTouches || destinationTouches
        tf = true;
        return
    end
end
end

function tf = path_in_scopes(blockPath, scopes)
tf = false;
for i = 1:numel(scopes)
    scope = char(scopes{i});
    if strcmp(blockPath, scope) || startsWith(blockPath, [scope '/'])
        tf = true;
        return
    end
end
end

function tf = matches_any(value, patterns)
tf = false;
for i = 1:numel(patterns)
    if contains(value, patterns{i})
        tf = true;
        return
    end
end
end

function value = safe_param(target, parameter)
try
    value = get_param(target, parameter);
catch
    value = '';
end
end

function values = batch_safe_param(targets, parameter)
targets = targets(:);
values = cell(size(targets));
if isempty(targets), return; end
try
    raw = get_param(targets, parameter);
    if ~iscell(raw), raw = {raw}; end
    if numel(raw) == numel(targets)
        values = reshape(raw, size(targets));
        return
    end
catch
end
for i = 1:numel(targets)
    values{i} = safe_param(targets{i}, parameter);
end
end

function values = empty_values(targets)
values = repmat({''}, numel(targets), 1);
end

function values = fill_selected_param(values, targets, indices, parameter)
if isempty(indices), return; end
selected = batch_safe_param(targets(indices), parameter);
values(indices) = selected;
end

function pathValue = relative_path(fullPath, model)
if strcmp(fullPath, model)
    pathValue = '<ROOT>';
else
    pathValue = char(extractAfter(string(fullPath), ...
        strlength(string(model)) + 1));
end
end

function ext = ext_for_model(modelFile, fallbackExt)
[~,~,ext] = fileparts(modelFile);
if isempty(ext), ext = fallbackExt; end
if isempty(ext), ext = '.slx'; end
end

function close_if_needed(model, closeWhenDone)
if closeWhenDone && bdIsLoaded(model), close_system(model, 0); end
end
