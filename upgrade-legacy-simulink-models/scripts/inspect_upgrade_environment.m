function report = inspect_upgrade_environment(modelFile, varargin)
%INSPECT_UPGRADE_ENVIRONMENT Detect MATLAB release and migration capabilities.

if nargin < 1
    modelFile = '';
end
parser = inputParser;
addParameter(parser, 'AdditionalRoots', {});
parse(parser, varargin{:});

additionalRoots = parser.Results.AdditionalRoots;
if ischar(additionalRoots) || isstring(additionalRoots)
    additionalRoots = cellstr(additionalRoots);
end

report = struct();
report.currentRelease = localRelease();
report.matlabRoot = matlabroot;
report.installedRoots = unique([{matlabroot}, additionalRoots, ...
    discoverSiblingRoots(matlabroot)], 'stable');
report.capabilities = struct( ...
    'simulink', license('test', 'Simulink'), ...
    'simscape', license('test', 'Simscape'), ...
    'powergui', isResolvable('powergui'), ...
    'powerlib', isResolvable('powerlib'), ...
    'spsLibrary', isResolvable('sps_lib'), ...
    'spsConversionAssistant', isResolvable('spsConversionAssistant'), ...
    'spsConversionFindBlocks', isResolvable('spsConversionFindBlocks'));
report.modelFile = char(modelFile);
report.modelInfo = struct();

if ~isempty(modelFile) && exist(modelFile, 'file')
    try
        info = Simulink.MDLInfo(modelFile);
        properties = {'ModelVersion', 'ReleaseName', ...
            'SimulinkVersion', 'IsLibrary'};
        for k = 1:numel(properties)
            if isprop(info, properties{k})
                report.modelInfo.(properties{k}) = info.(properties{k});
            end
        end
    catch ME
        report.modelInfoError = ME.message;
    end
end

fprintf('MATLAB release: %s\n', report.currentRelease);
fprintf('MATLAB root: %s\n', report.matlabRoot);
fprintf('Installed MATLAB roots: %d\n', numel(report.installedRoots));
fprintf('powergui=%d, spsConversionAssistant=%d, spsConversionFindBlocks=%d\n', ...
    report.capabilities.powergui, ...
    report.capabilities.spsConversionAssistant, ...
    report.capabilities.spsConversionFindBlocks);
end

function tf = isResolvable(name)
tf = exist(name, 'file') ~= 0 || ~isempty(which(name));
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
