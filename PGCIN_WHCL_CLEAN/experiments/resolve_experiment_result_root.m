function resultRoot = resolve_experiment_result_root(experimentRoot)
%RESOLVE_EXPERIMENT_RESULT_ROOT Select the current experiment output folder.

if nargin < 1 || isempty(experimentRoot)
    experimentRoot = fileparts(mfilename('fullpath'));
end

override = strtrim(getenv('PGCIN_WHCL_RESULT_ROOT'));
if isempty(override)
    resultRoot = fullfile(experimentRoot, 'results');
else
    resultRoot = override;
end

if ~exist(resultRoot, 'dir')
    [created, message] = mkdir(resultRoot);
    assert(created, 'Cannot create experiment result directory: %s', message);
end
end
