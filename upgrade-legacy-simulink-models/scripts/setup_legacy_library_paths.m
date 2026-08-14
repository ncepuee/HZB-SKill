function report = setup_legacy_library_paths(varargin)
%SETUP_LEGACY_LIBRARY_PATHS Add exact missing asset folders for diagnosis.
%
% Mixed-release paths are a diagnostic or conversion aid. A zero unresolved
% count does not prove that old P-code or solver runtimes work in the active
% MATLAB release.

parser = inputParser;
addParameter(parser, 'RequiredNames', ...
    {'powergui', 'powerlib', 'sps_rtmsupport', ...
     'spsConversionAssistant', 'spsConversionFindBlocks'});
addParameter(parser, 'AdditionalRoots', {});
parse(parser, varargin{:});

names = parser.Results.RequiredNames;
if ischar(names) || isstring(names)
    names = cellstr(names);
end
additionalRoots = parser.Results.AdditionalRoots;
if ischar(additionalRoots) || isstring(additionalRoots)
    additionalRoots = cellstr(additionalRoots);
end
roots = unique([{matlabroot}, additionalRoots, ...
    discoverSiblingRoots(matlabroot)], 'stable');

items = repmat(struct('Name', '', 'Resolved', false, ...
    'Location', '', 'OriginRoot', '', 'AddedDirectories', {{}}), ...
    numel(names), 1);
allAdded = {};
for k = 1:numel(names)
    name = names{k};
    location = resolveLocation(name);
    originRoot = rootForLocation(location, roots);
    addedForName = {};
    for r = 1:numel(roots)
        if ~isempty(location)
            break;
        end
        folders = findAssetFolders(roots{r}, name);
        for f = 1:numel(folders)
            if any(strcmpi(allAdded, folders{f}))
                continue;
            end
            if r == 1
                addpath(folders{f}, '-begin');
            else
                addpath(folders{f}, '-end');
            end
            allAdded{end + 1} = folders{f}; %#ok<AGROW>
            addedForName{end + 1} = folders{f}; %#ok<AGROW>
        end
        rehash;
        location = resolveLocation(name);
        if ~isempty(location)
            originRoot = roots{r};
        end
    end
    items(k) = struct( ...
        'Name', name, ...
        'Resolved', ~isempty(location), ...
        'Location', location, ...
        'OriginRoot', originRoot, ...
        'AddedDirectories', {addedForName});
end

report = struct();
report.currentRelease = localRelease();
report.matlabRoot = matlabroot;
report.rootsSearched = roots;
report.items = items;
report.addedDirectories = allAdded;
report.missing = {items(~[items.Resolved]).Name};
report.passed = isempty(report.missing);

fprintf('Compatibility assets resolved: %d/%d\n', ...
    sum([items.Resolved]), numel(items));
for k = 1:numel(items)
    fprintf('  %s => %s\n', items(k).Name, items(k).Location);
end
if any(~cellfun(@isempty, {items.OriginRoot}) & ...
        ~strcmpi({items.OriginRoot}, matlabroot))
    warning(['One or more assets came from another MATLAB release. ' ...
        'Use this path setup for diagnosis/conversion only and require ' ...
        'model update plus simulation before acceptance.']);
end
end

function folders = findAssetFolders(root, name)
folders = {};
if isempty(root) || ~exist(root, 'dir')
    return;
end
extensions = {'.m', '.p', '.slx', '.mdl'};
for k = 1:numel(extensions)
    hits = dir(fullfile(root, 'toolbox', '**', [name extensions{k}]));
    for n = 1:numel(hits)
        folder = hits(n).folder;
        if ~any(strcmpi(folders, folder))
            folders{end + 1} = folder; %#ok<AGROW>
        end
    end
end
end

function location = resolveLocation(name)
location = which(name);
if ~isempty(location)
    return;
end
extensions = {'.m', '.p', '.slx', '.mdl'};
for k = 1:numel(extensions)
    location = which([name extensions{k}]);
    if ~isempty(location)
        return;
    end
end
end

function root = rootForLocation(location, roots)
root = '';
for k = 1:numel(roots)
    if ~isempty(location) && startsWith(lower(location), lower(roots{k}))
        root = roots{k};
        return;
    end
end
end

function roots = discoverSiblingRoots(root)
roots = {};
parent = fileparts(root);
entries = dir(parent);
for k = 1:numel(entries)
    if ~entries(k).isdir || any(strcmp(entries(k).name, {'.', '..'}))
        continue;
    end
    if ~isempty(regexp(entries(k).name, ...
            '^R\d{4}[ab](?:_Prerelease)?$', 'once'))
        candidate = fullfile(parent, entries(k).name);
        if ~strcmpi(candidate, root)
            roots{end + 1} = candidate; %#ok<AGROW>
        end
    end
end
end

function release = localRelease()
try
    release = version('-release');
catch
    release = version;
end
end
