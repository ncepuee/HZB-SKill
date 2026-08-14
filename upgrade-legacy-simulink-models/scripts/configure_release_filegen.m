function report = configure_release_filegen(modelOrFolder, varargin)
%CONFIGURE_RELEASE_FILEGEN Isolate Simulink artifacts by MATLAB release.

parser = inputParser;
addParameter(parser, 'PersistInModel', false, @islogical);
parse(parser, varargin{:});

inputPath = char(modelOrFolder);
[projectFolder, modelFile] = resolveInput(inputPath);
releaseName = lower(version('-release'));
cacheFolder = fullfile(projectFolder, '.matlab_cache', releaseName);
codegenFolder = fullfile(projectFolder, '.matlab_codegen', releaseName);

Simulink.fileGenControl('set', 'CacheFolder', cacheFolder, ...
    'CodeGenFolder', codegenFolder, 'createDir', true);

persisted = false;
if parser.Results.PersistInModel
    assert(~isempty(modelFile), ...
        'PersistInModel requires a model file, not only a folder.');
    persisted = persistSetup(modelFile);
end

report = struct();
report.release = releaseName;
report.projectFolder = projectFolder;
report.cacheFolder = cacheFolder;
report.codegenFolder = codegenFolder;
report.persistedInModel = persisted;

fprintf('Release-specific CacheFolder: %s\n', cacheFolder);
fprintf('Release-specific CodeGenFolder: %s\n', codegenFolder);
fprintf('Persisted in model: %d\n', persisted);
end

function [projectFolder, modelFile] = resolveInput(inputPath)
modelFile = '';
if exist(inputPath, 'dir')
    projectFolder = localAbsolute(inputPath);
    return;
end

resolved = inputPath;
if exist(resolved, 'file') == 0
    resolved = which(inputPath);
end
assert(~isempty(resolved) && exist(resolved, 'file') ~= 0, ...
    'Model file or project folder not found: %s', inputPath);
modelFile = localAbsolute(resolved);
projectFolder = fileparts(modelFile);
end

function path = localAbsolute(path)
[ok, attributes] = fileattrib(path);
assert(ok, 'Unable to resolve path: %s', path);
path = attributes.Name;
end

function changed = persistSetup(modelFile)
[~, modelName] = fileparts(modelFile);
wasLoaded = bdIsLoaded(modelName);
load_system(modelFile);
cleanup = onCleanup(@() closeIfNeeded(modelName, wasLoaded));

marker = '% RELEASE_SPECIFIC_SIMULINK_FILEGEN';
initFcn = get_param(modelName, 'InitFcn');
changed = ~contains(initFcn, marker);
if ~changed
    return;
end

setup = strjoin({ ...
    marker
    'migrationModelDir = fileparts(get_param(bdroot,''FileName''));'
    'migrationRelease = lower(version(''-release''));'
    'migrationCacheDir = fullfile(migrationModelDir,''.matlab_cache'',migrationRelease);'
    'migrationCodegenDir = fullfile(migrationModelDir,''.matlab_codegen'',migrationRelease);'
    'Simulink.fileGenControl(''set'',''CacheFolder'',migrationCacheDir,''CodeGenFolder'',migrationCodegenDir,''createDir'',true);'
    'clear migrationModelDir migrationRelease migrationCacheDir migrationCodegenDir;'
    ''}, newline);
set_param(modelName, 'InitFcn', [setup initFcn]);
save_system(modelName, modelFile);
end

function closeIfNeeded(modelName, wasLoaded)
if ~wasLoaded && bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end
