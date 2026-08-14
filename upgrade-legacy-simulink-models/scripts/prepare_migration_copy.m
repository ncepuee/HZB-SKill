function report = prepare_migration_copy(sourceFile, outputFile, varargin)
%PREPARE_MIGRATION_COPY Create a protected model copy for release migration.

parser = inputParser;
addParameter(parser, 'InitMarker', '');
addParameter(parser, 'LegacyCallbackTokens', ...
    {'sps_rtmsupport', 'powericon'});
addParameter(parser, 'ClearLegacyCallbacks', false, @islogical);
addParameter(parser, 'Overwrite', false, @islogical);
parse(parser, varargin{:});

sourceFile = char(sourceFile);
outputFile = char(outputFile);
assert(exist(sourceFile, 'file') ~= 0, 'Source model not found: %s', sourceFile);
assert(~strcmpi(localAbsolute(sourceFile), localAbsolute(outputFile)), ...
    'Source and output files must be different.');
if exist(outputFile, 'file') && ~parser.Results.Overwrite
    error('Output file already exists: %s', outputFile);
end

[outputFolder, ~, extension] = fileparts(outputFile);
assert(any(strcmpi(extension, {'.slx', '.mdl'})), ...
    'Output file must use .slx or .mdl.');
if ~isempty(outputFolder) && ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end
copyfile(sourceFile, outputFile, 'f');

handle = load_system(outputFile);
model = get_param(handle, 'Name');
cleanup = onCleanup(@() closeIfLoaded(model));

originalInitFcn = safeGet(model, 'InitFcn');
autoSaveDetected = ischar(originalInitFcn) && ...
    (contains(lower(originalInitFcn), 'save_system') || ...
     contains(lower(originalInitFcn), 'cd('));
migrationInitFcn = originalInitFcn;
marker = char(parser.Results.InitMarker);
initModified = false;
if ~isempty(marker)
    markerIndex = strfind(originalInitFcn, marker);
    assert(~isempty(markerIndex), ...
        'InitMarker was not found in the model InitFcn: %s', marker);
    migrationInitFcn = originalInitFcn(markerIndex(1):end);
    set_param(model, 'InitFcn', migrationInitFcn);
    initModified = true;
elseif autoSaveDetected
    warning(['InitFcn contains save_system or cd, but no InitMarker was ' ...
        'provided. The callback was preserved for manual review.']);
end

tokens = parser.Results.LegacyCallbackTokens;
if ischar(tokens) || isstring(tokens)
    tokens = cellstr(tokens);
end
[flaggedCallbacks, clearedCallbacks] = auditTokenCallbacks( ...
    model, tokens, parser.Results.ClearLegacyCallbacks);

save_system(model, outputFile);
report = struct();
report.sourceFile = sourceFile;
report.outputFile = outputFile;
report.model = model;
report.autoSaveDetected = autoSaveDetected;
report.initModified = initModified;
report.originalInitFcn = originalInitFcn;
report.migrationInitFcn = migrationInitFcn;
report.flaggedCallbacks = flaggedCallbacks;
report.flaggedCallbackCount = numel(flaggedCallbacks);
report.clearedCallbacks = clearedCallbacks;
report.clearedCallbackCount = numel(clearedCallbacks);

fprintf('Migration copy: %s\n', outputFile);
fprintf('InitFcn modified: %d\n', initModified);
fprintf('Legacy callbacks flagged: %d\n', report.flaggedCallbackCount);
fprintf('Legacy callbacks cleared: %d\n', report.clearedCallbackCount);
end

function [flagged, cleared] = auditTokenCallbacks(model, tokens, clearMatches)
blocks = find_system(model, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'off');
flagged = repmat(struct('Block', '', 'Property', '', 'Token', ''), 0, 1);
cleared = repmat(struct('Block', '', 'Property', '', 'Token', ''), 0, 1);
for k = 1:numel(blocks)
    try
        parameters = get_param(blocks{k}, 'ObjectParameters');
        callbackNames = fieldnames(parameters);
        callbackNames = callbackNames(endsWith(callbackNames, 'Fcn'));
    catch
        callbackNames = {};
    end
    for n = 1:numel(callbackNames)
        code = safeGet(blocks{k}, callbackNames{n});
        if ~ischar(code) || isempty(code)
            continue;
        end
        for t = 1:numel(tokens)
            if contains(lower(code), lower(tokens{t}))
                match = struct('Block', blocks{k}, ...
                    'Property', callbackNames{n}, 'Token', tokens{t});
                flagged(end + 1) = match; %#ok<AGROW>
                if ~clearMatches
                    break;
                end
                try
                    set_param(blocks{k}, callbackNames{n}, '');
                    cleared(end + 1) = match; %#ok<AGROW>
                catch
                end
                break;
            end
        end
    end
end
end

function value = safeGet(block, parameter)
try
    value = get_param(block, parameter);
catch
    value = '';
end
end

function path = localAbsolute(path)
[ok, attributes] = fileattrib(path);
if ok
    path = attributes.Name;
else
    [folder, name, extension] = fileparts(path);
    if isempty(folder)
        folder = pwd;
    end
    [folderOk, folderAttributes] = fileattrib(folder);
    assert(folderOk, 'Unable to resolve path: %s', path);
    path = fullfile(folderAttributes.Name, [name extension]);
end
end

function closeIfLoaded(model)
if bdIsLoaded(model)
    close_system(model, 0);
end
end
