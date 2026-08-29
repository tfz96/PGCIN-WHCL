function exportedFiles = generate_manuscript_figures(figureNumbers, refreshData)
%GENERATEMANUSCRIPTFIGURES Generate selected final-scheme manuscript figures.
%
% generate_manuscript_figures()
% generate_manuscript_figures(12)
% generate_manuscript_figures([5 9], true)
% generate_manuscript_figures([6 7 8 10 11 12], false)

if nargin < 1 || isempty(figureNumbers)
    figureNumbers = [3 5 6 7 8 9 10 11 12];
end
if nargin < 2 || isempty(refreshData)
    refreshData = true;
end
validateattributes(figureNumbers, {'numeric'}, ...
    {'vector', 'real', 'finite', 'integer', 'positive'});
validateattributes(refreshData, {'logical'}, {'scalar'});
figureNumbers = unique(double(figureNumbers(:).'), 'stable');
supported = [3 5 6 7 8 9 10 11 12];
assert(all(ismember(figureNumbers, supported)), ...
    'Supported automatic figures are 3, 5, 6, 7, 8, 9, 10, 11, and 12.');

dataFigures = intersect(figureNumbers, [3 5 9], 'stable');
if ~isempty(dataFigures) && (refreshData || dataMissing(dataFigures))
    generate_paper_figure_data(dataFigures);
end
exportedFiles = export_paper_figures(figureNumbers);
end

function missing = dataMissing(dataFigures)
experimentRoot = fileparts(mfilename('fullpath'));
resultRoot = resolve_experiment_result_root(experimentRoot);
dataRoot = fullfile(resultRoot, 'figure_data');
missing = false;
for figureNumber = dataFigures
    switch figureNumber
        case 3
            fileName = 'fig03_stage_support.csv';
        case 5
            fileName = 'fig05_visual_results.mat';
        case 9
            fileName = 'fig09_payload_locality.mat';
    end
    missing = missing || ~isfile(fullfile(dataRoot, fileName));
end
end
