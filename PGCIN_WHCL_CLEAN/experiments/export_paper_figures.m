function exportedFiles = export_paper_figures(figureNumbers)
%EXPORTPAPERFIGURES Export manuscript figures from canonical result data.
%
% exportedFiles = export_paper_figures()
% exportedFiles = export_paper_figures([3 5 6 7 8 9 10 11 12])
%
% This plotting layer reads canonical CSV files and the frozen image-data
% artifact only. It does not execute encryption experiments or diagnostic
% trace functions.

if nargin < 1 || isempty(figureNumbers)
    figureNumbers = [3 5 6 7 8 9 10 11 12];
end
validateattributes(figureNumbers, {'numeric'}, ...
    {'vector', 'integer', 'finite', 'positive'});
figureNumbers = unique(double(figureNumbers(:).'), 'stable');
supported = [3 5 6 7 8 9 10 11 12];
assert(all(ismember(figureNumbers, supported)), ...
    'Supported paper figures are 3, 5, 6, 7, 8, 9, 10, 11, and 12.');

experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = fileparts(experimentRoot);
projectRoot = fileparts(cleanRoot);
resultRoot = resolve_experiment_result_root(experimentRoot);
figureDataRoot = fullfile(resultRoot, 'figure_data');
outputOverride = strtrim(getenv('PGCIN_WHCL_FIGURE_OUTPUT_ROOT'));
if isempty(outputOverride)
    outputRoot = fullfile(projectRoot, 'figures_generated');
else
    outputRoot = outputOverride;
end
if ~exist(outputRoot, 'dir')
    mkdir(outputRoot);
end

exportedFiles = strings(0, 1);
for figureNumber = figureNumbers
    switch figureNumber
        case 3
            files = exportFigure03(resultRoot, figureDataRoot, outputRoot);
        case 5
            files = exportFigure05(figureDataRoot, outputRoot);
        case 6
            files = exportFigure06(resultRoot, outputRoot);
        case 7
            files = exportFigure07(resultRoot, outputRoot);
        case 8
            files = exportFigure08(resultRoot, outputRoot);
        case 9
            files = exportFigure09(figureDataRoot, outputRoot);
        case 10
            files = exportFigure10(resultRoot, outputRoot);
        case 11
            files = exportFigure11(resultRoot, outputRoot);
        case 12
            files = exportFigure12(resultRoot, outputRoot);
    end
    exportedFiles = appendPaths(exportedFiles, files);
end
if keepFigureOpen()
    fprintf('Preview mode: %d figure window(s) remain open; no files were exported.\n', ...
        numel(figureNumbers));
else
    fprintf('Exported %d PGCIN-WHCL manuscript figure file(s) to:\n%s\n', ...
        numel(exportedFiles), outputRoot);
end
end

function files = exportFigure03(resultRoot, figureDataRoot, outputRoot)
structure = readCanonicalTable(resultRoot, 'S1_structure_coverage.csv', ...
    {'tileSize', 'stageCount', 'pairwiseLowerBound', 'boundGap', ...
    'finalMinimumSupport', 'finalMaximumSupport', 'matchingAllValid', ...
    'finalFullSupportRate'});
row = structure(structure.tileSize == 16, :);
assert(height(row) == 1 && row.stageCount == 9 ...
    && row.matchingAllValid && row.finalFullSupportRate == 1, ...
    'The canonical B=16 structural result is incomplete or invalid.');

scheduleData = readFigureTable(figureDataRoot, ...
    'fig03_stage_support.csv', {'stage', 'baseIncrement', ...
    'actualCenter', 'minimumSupport', 'medianSupport', ...
    'maximumSupport', 'fullSupportRate'});
stage = double(scheduleData.stage);
minimumSupport = double(scheduleData.minimumSupport);
maximumSupport = double(scheduleData.maximumSupport);
increment = double(scheduleData.baseIncrement);
assert(numel(stage) == 9 && isequal(stage(:), (1:9).'), ...
    'Figure 3 requires nine ordered stages.');
assert(all(minimumSupport > 0 & minimumSupport <= maximumSupport) ...
    && maximumSupport(end) == 256 && minimumSupport(end) == 256, ...
    'Figure 3 support data are inconsistent with complete final support.');

fig = makeFigure([13.2 6.8]);
 ax = subplot(1, 2, 1, 'Parent', fig);
hold(ax, 'on');
plot(ax, stage, minimumSupport, '-o', 'LineWidth', 1.4, ...
    'MarkerSize', 5, 'Color', palette(1));
plot(ax, stage, maximumSupport, '-s', 'LineWidth', 1.4, ...
    'MarkerSize', 5, 'Color', palette(2));
yline(ax, 256, ':', 'Color', neutral(0.45));
xline(ax, row.pairwiseLowerBound, '--', 'Color', neutral(0.35));
text(ax, 1.0, 249, 'Full support = 256', 'FontSize', 7.5, ...
    'Color', neutral(0.30), 'BackgroundColor', 'w');
text(ax, row.pairwiseLowerBound + 0.10, 18, ...
    sprintf('Pairwise lower bound = %d', row.pairwiseLowerBound), ...
    'Rotation', 90, 'FontSize', 7.5, 'Color', neutral(0.25), ...
    'BackgroundColor', 'w');
axisLabels(ax, 'Stage', 'Dependency-support size');
xticks(ax, 1:9);
xlim(ax, [0.6 9.4]);
ylim(ax, [0 268]);
legend(ax, {'Minimum support', 'Maximum support'}, ...
    'Location', 'west', 'Box', 'off');
text(ax, 0.02, 0.98, '(b)', 'Units', 'normalized', ...
    'FontName', 'Times New Roman', 'FontSize', 10, 'FontWeight', 'normal', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');

 ax = subplot(1, 2, 2, 'Parent', fig);
bar(ax, stage, increment, 0.72, 'FaceColor', palette(3), ...
    'EdgeColor', 'none');
set(ax, 'YScale', 'log');
axisLabels(ax, 'Stage', 'Base contact increment');
xticks(ax, 1:9);
yticks(ax, [1 2 4 8 16 32 64 128]);
xlim(ax, [0.4 9.6]);
ylim(ax, [0.8 180]);
text(ax, 0.02, 0.98, '(c)', 'Units', 'normalized', ...
    'FontName', 'Times New Roman', 'FontSize', 10, 'FontWeight', 'normal', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');

path = fullfile(outputRoot, 'fig03_nine_stage_schedule.pdf');
exportVector(fig, path);
finalizeFigure(fig);
files = string(path);
end

function files = exportFigure05(figureDataRoot, outputRoot)
figureData = loadFigureMat(figureDataRoot, 'fig05_visual_results.mat');
assert(isfield(figureData, 'cases') && isstruct(figureData.cases), ...
    'Figure 5 MAT file must contain the cases structure.');
caseData = figureData.cases;
caseData = caseData(:);
plain = {caseData.plain};
cipher = {caseData.cipher};
recovered = {caseData.recovered};
caseCount = min([numel(plain), numel(cipher), numel(recovered), 2]);
assert(caseCount == 2, 'Figure 5 requires two complete image cases.');

% Arrange each case as plaintext -> plaintext histogram -> ciphertext ->
% ciphertext histogram -> recovered image -> absolute error.  The two
% histogram columns use separate shared percentage scales: this keeps the
% plaintext structure and the near-uniform ciphertext structure visible.
plainHistogramYMax = 0;
cipherHistogramYMax = 0;
for caseIndex = 1:caseCount
    plainHistogramYMax = max(plainHistogramYMax, ...
        maxRgbHistogramProbability(plain{caseIndex}));
    cipherHistogramYMax = max(cipherHistogramYMax, ...
        maxRgbHistogramProbability(cipher{caseIndex}));
end
plainHistogramYMax = max(1e-3, 1.12 * plainHistogramYMax);
cipherHistogramYMax = max(1e-3, 1.18 * cipherHistogramYMax);

fig = makeFigure([22.0 8.2]);
columnLabels = {'Plaintext', 'Plaintext histogram', 'Ciphertext', ...
    'Ciphertext histogram', 'Recovered', 'Absolute error'};
for caseIndex = 1:caseCount
    tile = (caseIndex - 1) * 6;
    letter = caseLetter(caseIndex);

    ax = subplot(2, 6, tile + 1, 'Parent', fig);
    showImage(ax, plain{caseIndex}, '');
    labelFigure05Panel(ax, tile + 1);
    if caseIndex == 1
        labelFigure05Column(ax, columnLabels{1});
    end

    ax = subplot(2, 6, tile + 2, 'Parent', fig);
    plotRgbHistogram(ax, plain{caseIndex}, plainHistogramYMax, ...
        caseIndex == 1, caseIndex == caseCount, caseIndex == 1, false);
    labelFigure05Panel(ax, tile + 2);
    if caseIndex == 1
        labelFigure05Column(ax, columnLabels{2});
    end

    ax = subplot(2, 6, tile + 3, 'Parent', fig);
    showImage(ax, cipher{caseIndex}, '');
    labelFigure05Panel(ax, tile + 3);
    if caseIndex == 1
        labelFigure05Column(ax, columnLabels{3});
    end

    ax = subplot(2, 6, tile + 4, 'Parent', fig);
    plotRgbHistogram(ax, cipher{caseIndex}, cipherHistogramYMax, ...
        false, caseIndex == caseCount, caseIndex == 1, true);
    labelFigure05Panel(ax, tile + 4);
    if caseIndex == 1
        labelFigure05Column(ax, columnLabels{4});
    end

    ax = subplot(2, 6, tile + 5, 'Parent', fig);
    showImage(ax, recovered{caseIndex}, '');
    labelFigure05Panel(ax, tile + 5);
    if caseIndex == 1
        labelFigure05Column(ax, columnLabels{5});
    end

    difference = abs(double(recovered{caseIndex}) - double(plain{caseIndex}));
    ax = subplot(2, 6, tile + 6, 'Parent', fig);
    imagesc(ax, max(difference, [], 3), [0 255]);
    axis(ax, 'image', 'off');
    colormap(ax, gray(256));
    labelFigure05Panel(ax, tile + 6);
    if caseIndex == 1
        labelFigure05Column(ax, columnLabels{6});
    end
end
pdfPath = fullfile(outputRoot, 'fig05_visual_results.pdf');
pngPath = fullfile(outputRoot, 'fig05_visual_results.png');
exportVector(fig, pdfPath);
exportRaster(fig, pngPath);
finalizeFigure(fig);
files = string({pdfPath; pngPath});
end

function plotRgbHistogram(ax, image, yMax, showLegend, showXLabel, ...
    showYLabel, showUniformReference)
edges = -0.5:1:255.5;
levels = 0:255;
channelColors = [0.82 0.16 0.16; 0.15 0.55 0.22; 0.12 0.30 0.78];
hold(ax, 'on');
for channel = 1:3
    counts = histcounts(double(image(:, :, channel)), edges);
    probability = 100 * counts / numel(image(:, :, channel));
    plot(ax, levels, probability, '-', 'Color', channelColors(channel, :), ...
        'LineWidth', 0.85);
end
if showUniformReference
    yline(ax, 100 / 256, ':', 'Color', neutral(0.48), 'LineWidth', 0.75);
end
hold(ax, 'off');
xlim(ax, [0 255]);
ylim(ax, [0 yMax]);
xticks(ax, [0 128 255]);
yticks(ax, [0 yMax / 2 yMax]);
ytickformat(ax, '%.2f');
xtickangle(ax, 0);
if showXLabel
    xlabel(ax, 'Intensity');
else
    ax.XTickLabel = [];
end
if showYLabel
    ylabel(ax, 'Frequency (%)');
else
    ax.YTickLabel = [];
end
grid(ax, 'off');
box(ax, 'on');
ax.FontName = 'Times New Roman';
ax.FontSize = 7.2;
ax.LineWidth = 0.6;
ax.TickDir = 'out';
ax.Layer = 'top';
if showLegend
    legend(ax, {'R', 'G', 'B'}, 'Location', 'northoutside', ...
        'Orientation', 'horizontal', 'NumColumns', 3, ...
        'Box', 'off', 'FontSize', 7.5);
end
end

function labelFigure05Panel(ax, panelIndex)
% Use compact in-panel labels so the manuscript caption carries the meaning.
text(ax, 0.025, 0.965, sprintf('(%c)', char('a' + panelIndex - 1)), ...
    'Units', 'normalized', 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', 'FontName', 'Times New Roman', ...
    'FontSize', 8.5, 'FontWeight', 'bold', 'Color', neutral(0.10), ...
    'BackgroundColor', 'w', 'Margin', 1.5, 'Clipping', 'on');
end

function labelFigure05Column(ax, label)
title(ax, label, 'FontName', 'Times New Roman', 'FontSize', 8.5, ...
    'FontWeight', 'normal', 'Interpreter', 'none');
end

function value = maxRgbHistogramProbability(image)
edges = -0.5:1:255.5;
value = 0;
for channel = 1:3
    counts = histcounts(double(image(:, :, channel)), edges);
    value = max(value, max(100 * counts / numel(image(:, :, channel))));
end
end

function files = exportFigure06(resultRoot, outputRoot)
tableResult = readCanonicalTable(resultRoot, ...
    'D1_repeated_fixed_session_dependency.csv', ...
    {'seedIndex', 'locationIndex', 'stage', 'affectedBytes', ...
    'affectedBits', 'outsideTouchedMacroblockBytes', ...
    'insideAffectedBytes'});
assert(all(tableResult.outsideTouchedMacroblockBytes == 0), ...
    'Figure 6 canonical data contain an out-of-macroblock difference.');

fig = makeFigure([14.2 6.4]);
 plotStageDistribution(subplot(1, 2, 1, 'Parent', fig), tableResult.stage, ...
    tableResult.affectedBytes, 'Affected bytes', 768, true);
 plotStageDistribution(subplot(1, 2, 2, 'Parent', fig), tableResult.stage, ...
    tableResult.affectedBits, 'Affected bits', [], false);
path = fullfile(outputRoot, 'fig06_stagewise_dependency.pdf');
exportVector(fig, path);
finalizeFigure(fig);
files = string(path);
end

function files = exportFigure07(resultRoot, outputRoot)
tableResult = readCanonicalTable(resultRoot, 'D2_kodak_mult_nonce.csv', ...
    {'image', 'nonceIndex', 'perturbation', 'height', 'width', ...
    'changedCipherBytes', 'changedCipherPixels', ...
    'meanChannelNPCR_percent', 'minimumChannelNPCR_percent', ...
    'meanChannelUACI_percent', 'minimumChannelUACI_percent', ...
    'roundTripPass'});
assert(height(tableResult) == 216 && all(tableResult.roundTripPass), ...
    'Figure 7 requires 216 successful canonical perturbation cases.');
categories = ["plaintextBit", "masterKeyBit", "nonceBit"];
labels = {'Plaintext bit', 'Master-key bit', 'Nonce bit'};

fig = makeFigure([14.2 6.4]);
 ax = subplot(1, 2, 1, 'Parent', fig);
plotCategoryDistribution(ax, string(tableResult.perturbation), ...
    tableResult.meanChannelNPCR_percent, categories, labels);
yline(ax, 99.609375, '--', 'Color', neutral(0.35));
axisLabels(ax, '', 'Mean channel NPCR (%)');
title(ax, '(a) Ciphertext change rate');
text(ax, 0.03, 0.05, 'Reference = 99.609375%', ...
    'Units', 'normalized', 'FontSize', 7.5, 'BackgroundColor', 'w');

 ax = subplot(1, 2, 2, 'Parent', fig);
plotCategoryDistribution(ax, string(tableResult.perturbation), ...
    tableResult.meanChannelUACI_percent, categories, labels);
yline(ax, 33.463542, '--', 'Color', neutral(0.35));
axisLabels(ax, '', 'Mean channel UACI (%)');
title(ax, '(b) Intensity-change magnitude');
text(ax, 0.03, 0.05, 'Reference = 33.463542%', ...
    'Units', 'normalized', 'FontSize', 7.5, 'BackgroundColor', 'w');
text(ax, 0.03, 0.97, sprintf(['216/216 exact round trips\n' ...
    'Min channel NPCR = %.6f%%\n' ...
    'Min channel UACI = %.6f%%'], ...
    min(tableResult.minimumChannelNPCR_percent), ...
    min(tableResult.minimumChannelUACI_percent)), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'FontSize', 7.5);

path = fullfile(outputRoot, 'fig07_api_sensitivity.pdf');
exportVector(fig, path);
finalizeFigure(fig);
files = string(path);
end

function files = exportFigure08(resultRoot, outputRoot)
maskData = readCanonicalTable(resultRoot, 'A1_plaintext_mask_reuse.csv', ...
    {'image', 'nonceIndex', 'repeatCipherExact', 'repeatSivExact', ...
    'changedSiv', 'xorByteAgreementPercent', ...
    'additiveByteAgreementPercent', 'xorPixelAgreementPercent', ...
    'additivePixelAgreementPercent', 'xorPSNRdB', 'additivePSNRdB'});
operationData = readCanonicalTable(resultRoot, ...
    'A2_macroblock_manipulation.csv', ...
    {'image', 'caseType', 'locationIndex', 'targetMacroblockCount', ...
    'decryptCompleted', 'exactRecovery', 'changedPixels', ...
    'outsideTargetPixels', 'affectedMacroblockCount'});
assert(all(maskData.repeatCipherExact) && all(maskData.repeatSivExact) ...
    && all(maskData.changedSiv), 'Figure 8 mask-reuse prerequisites failed.');
assert(all(operationData.decryptCompleted) ...
    && ~any(operationData.exactRecovery) ...
    && all(operationData.outsideTargetPixels == 0), ...
    'Figure 8 manipulation boundary data are inconsistent.');

fig = makeFigure([14.4 6.6]);
 ax = subplot(1, 2, 1, 'Parent', fig);
method = [repmat("XOR", height(maskData), 1); ...
    repmat("Additive", height(maskData), 1)];
agreement = [maskData.xorByteAgreementPercent; ...
    maskData.additiveByteAgreementPercent];
plotCategoryDistribution(ax, method, agreement, ...
    ["XOR", "Additive"], {'XOR mask', 'Additive mask'});
yline(ax, 100 / 256, '--', 'Color', neutral(0.35));
axisLabels(ax, '', 'Recovered-byte agreement (%)');
title(ax, '(a) Known-plaintext mask transfer');
text(ax, 0.04, 0.96, sprintf(['median PSNR: XOR %.3f dB, additive %.3f dB\n' ...
    'pixel-perfect agreement: 0%% for both'], ...
    median(maskData.xorPSNRdB), median(maskData.additivePSNRdB)), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 8, ...
    'BackgroundColor', 'w');
text(ax, 0.04, 0.06, 'Random-byte reference = 1/256', ...
    'Units', 'normalized', 'FontSize', 7.5, 'BackgroundColor', 'w');

 ax = subplot(1, 2, 2, 'Parent', fig);
caseType = string(operationData.caseType);
categories = ["crossSessionReplay", "withinCipherSwap"];
labels = {'Block replacement', 'Block swap'};
plotCategoryDistribution(ax, caseType, double(operationData.changedPixels), ...
    categories, labels);
xtickangle(ax, 18);
axisLabels(ax, '', 'Changed plaintext pixels');
title(ax, '(b) Unauthenticated macroblock operations');
text(ax, 0.04, 0.96, sprintf(['outside-target pixels = 0\n' ...
    'affected macroblocks: replacement %g, swap %g'], ...
    median(operationData.affectedMacroblockCount(caseType == categories(1))), ...
    median(operationData.affectedMacroblockCount(caseType == categories(2)))), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 8, ...
    'BackgroundColor', 'w');
ylim(ax, [220 535]);

path = fullfile(outputRoot, 'fig08_attack_boundaries.pdf');
exportVector(fig, path);
finalizeFigure(fig);
files = string(path);
end

function files = exportFigure09(figureDataRoot, outputRoot)
figureData = loadFigureMat(figureDataRoot, 'fig09_payload_locality.mat');
assert(isfield(figureData, 'cases') && isstruct(figureData.cases), ...
    'Figure 9 MAT file must contain the cases structure.');
caseData = figureData.cases;
assert(numel(caseData) == 2, ...
    'Figure 9 data must contain exactly two locality cases.');
caseNames = string({caseData.caseName});
assert(nnz(caseNames == "singleBit") == 1 ...
    && nnz(caseNames == "burst4x4") == 1, ...
    'Figure 9 requires singleBit and burst4x4 cases.');
singleBit = normalizeLocalityCase( ...
    caseData(caseNames == "singleBit"));
burst = normalizeLocalityCase( ...
    caseData(caseNames == "burst4x4"));

fig = makeFigure([13.4 9.4]);
plotLocalityPanel(fig, 2, 2, 1, singleBit, '(a)');
plotLocalityPanel(fig, 2, 2, 2, singleBit, '(b)');
plotLocalityPanel(fig, 2, 2, 3, burst, '(c)');
plotLocalityPanel(fig, 2, 2, 4, burst, '(d)');
pdfPath = fullfile(outputRoot, 'fig09_payload_error_locality.pdf');
pngPath = fullfile(outputRoot, 'fig09_payload_error_locality.png');
exportVector(fig, pdfPath);
exportRaster(fig, pngPath);
finalizeFigure(fig);
files = string({pdfPath; pngPath});
end

function files = exportFigure10(resultRoot, outputRoot)
gear = readCanonicalTable(resultRoot, 'G_gear_control_audit.csv', ...
    {'variant', 'scheduleChanged', 'stageKeyDigest', ...
    'cipherChangedPercent', 'exactRoundTrip', 'matchingValid', ...
    'fullSupportRate'});
generic = readCanonicalTable(resultRoot, ...
    'G_generic_controller_repeated.csv', ...
    {'caseIndex', 'imageSeed', 'nonceHex', 'baselineRoundTrip', ...
    'genericRoundTrip', 'matchingValid', 'baselineSupportRate', ...
    'genericSupportRate', 'cipherDifferencePercent'});
variant = string(gear.variant);
variantOrder = ["header-frozen", "gear-phase-frozen", ...
    "whcl-input-frozen"];
assert(all(ismember(variantOrder, variant)) ...
    && all(gear.exactRoundTrip) && all(gear.matchingValid) ...
    && all(gear.fullSupportRate == 1), ...
    'Figure 10 gear-control data are incomplete.');
assert(all(generic.baselineRoundTrip) && all(generic.genericRoundTrip) ...
    && all(generic.matchingValid) && all(generic.genericSupportRate == 1), ...
    'Figure 10 generic-controller data are incomplete.');

fig = makeFigure([18.8 7.2]);
ax = subplot(1, 2, 1, 'Parent', fig);
hold(ax, 'on');
interventionOrder = ["baseline", variantOrder];
interventionLabels = {'Baseline', 'Header fixed', ...
    'Gear dynamics frozen', 'WHCL inputs frozen'};
interventionValues = zeros(1, numel(interventionOrder));
scheduleStatus = strings(1, numel(interventionOrder));
for index = 1:numel(interventionOrder)
    item = gear(variant == interventionOrder(index), :);
    assert(height(item) == 1, 'A Figure 10 intervention row is missing.');
    interventionValues(index) = item.cipherChangedPercent;
    if item.scheduleChanged
        scheduleStatus(index) = "schedule changed";
    else
        if index == 1
            scheduleStatus(index) = "reference";
        else
            scheduleStatus(index) = "schedule unchanged";
        end
    end
end
y = 1:numel(interventionOrder);
for index = 1:numel(interventionOrder)
    if index == 1
        markerColor = neutral(0.15);
    elseif scheduleStatus(index) == "schedule changed"
        markerColor = palette(2);
    else
        markerColor = palette(1);
    end
    scatter(ax, interventionValues(index), y(index), 48, 'o', ...
        'MarkerFaceColor', markerColor, 'MarkerEdgeColor', 'w', ...
        'LineWidth', 0.7);
    text(ax, interventionValues(index) + 2.5, y(index), ...
        sprintf('%.4f%%', interventionValues(index)), ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'FontSize', 7.5, 'Color', neutral(0.10));
end
yticks(ax, y);
yticklabels(ax, interventionLabels);
set(ax, 'YDir', 'reverse');
xlim(ax, [0 116]);
ylim(ax, [0.4 numel(interventionOrder) + 0.6]);
axisLabels(ax, 'Cipher-byte difference (%)', 'Control variant');
title(ax, '(a) Control interventions');
changedHandle = plot(ax, NaN, NaN, 'o', 'MarkerSize', 6, ...
    'MarkerFaceColor', palette(2), 'MarkerEdgeColor', 'w');
unchangedHandle = plot(ax, NaN, NaN, 'o', 'MarkerSize', 6, ...
    'MarkerFaceColor', palette(1), 'MarkerEdgeColor', 'w');
referenceHandle = plot(ax, NaN, NaN, 'o', 'MarkerSize', 6, ...
    'MarkerFaceColor', neutral(0.15), 'MarkerEdgeColor', 'w');
legend(ax, [changedHandle unchangedHandle referenceHandle], ...
    {'Schedule changed', 'Schedule unchanged', 'Reference'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', ...
    'Box', 'off', 'FontSize', 7.0);

ax = subplot(1, 2, 2, 'Parent', fig);
hold(ax, 'on');
genericValues = double(generic.cipherDifferencePercent(:));
caseIndex = (1:numel(genericValues)).';
minimumValue = min(genericValues);
medianValue = median(genericValues);
maximumValue = max(genericValues);
plot(ax, [2 2], [minimumValue maximumValue], '-', ...
    'Color', neutral(0.15), 'LineWidth', 1.7);
scatter(ax, caseIndex, genericValues, 46, 'o', ...
    'MarkerFaceColor', palette(2), 'MarkerEdgeColor', 'w', ...
    'LineWidth', 0.7);
plot(ax, [0.72 3.28], [medianValue medianValue], '--', ...
    'Color', neutral(0.15), 'LineWidth', 1.1);
scatter(ax, 2, medianValue, 54, 'd', ...
    'MarkerFaceColor', neutral(0.15), 'MarkerEdgeColor', 'w', ...
    'LineWidth', 0.7);
for index = 1:numel(genericValues)
    text(ax, caseIndex(index), genericValues(index) + 0.006, ...
        sprintf('%.4f%%', genericValues(index)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', 7.5, 'Color', neutral(0.10));
end
text(ax, 0.03, 0.97, sprintf('min--median--max: %.4f--%.4f--%.4f%%', ...
    minimumValue, medianValue, maximumValue), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontSize', 7.5, 'Color', neutral(0.20), 'BackgroundColor', 'w');
text(ax, 0.03, 0.04, 'All cases pass: inverse / matching / support', ...
    'Units', 'normalized', 'VerticalAlignment', 'bottom', ...
    'FontSize', 7.5, 'Color', neutral(0.20), 'BackgroundColor', 'w');
xlim(ax, [0.55 3.45]);
ylim(ax, [99.4 99.53]);
xticks(ax, caseIndex);
xticklabels(ax, compose('Case %d', caseIndex));
axisLabels(ax, 'Generic-controller case', 'Cipher-byte difference (%)');
title(ax, '(b) Operation-matched generic controller');

path = fullfile(outputRoot, 'fig10_control_ablation.pdf');
exportVector(fig, path);
finalizeFigure(fig);
files = string(path);
end

function files = exportFigure11(resultRoot, outputRoot)
natural = readCanonicalTable(resultRoot, ...
    'E1_natural_image_diagnostics.csv', ...
    {'image', 'entropyAll', 'entropyR', 'entropyG', 'entropyB', ...
    'absCorrHorizontal', 'absCorrVertical', 'absCorrDiagonal', ...
    'meanChannelNPCR_percent', 'minimumChannelNPCR_percent', ...
    'meanChannelUACI_percent', 'minimumChannelUACI_percent'});
weak = readCanonicalTable(resultRoot, 'E2_weak_input_diagnostics.csv', ...
    {'input', 'cipherEntropy', 'fixedNonceRepeatPass', 'roundTripPass'});
assert(height(natural) == 24 && all(weak.roundTripPass) ...
    && all(weak.fixedNonceRepeatPass), ...
    'Figure 11 canonical diagnostic data are incomplete.');

fig = makeFigure([17.0 6.3]);
 ax = subplot(1, 3, 1, 'Parent', fig);
deficit = 1e4 * (8 - natural.entropyAll);
scatter(ax, 1:height(natural), deficit, 24, ...
    'MarkerFaceColor', palette(1), 'MarkerEdgeColor', 'w', ...
    'LineWidth', 0.4);
hold(ax, 'on');
yline(ax, median(deficit), '-', 'Median', 'Color', neutral(0.15));
axisLabels(ax, 'Kodak image index', ...
    'Entropy deficit (x10^{-4} bit/byte)');
xlim(ax, [0 25]);
title(ax, '(a) Ciphertext entropy deficit');

 ax = subplot(1, 3, 2, 'Parent', fig);
direction = [repmat("Horizontal", height(natural), 1); ...
    repmat("Vertical", height(natural), 1); ...
    repmat("Diagonal", height(natural), 1)];
correlation = 1e3 * [natural.absCorrHorizontal; natural.absCorrVertical; ...
    natural.absCorrDiagonal];
plotCategoryDistribution(ax, direction, correlation, ...
    ["Horizontal", "Vertical", "Diagonal"], ...
    {'Horizontal', 'Vertical', 'Diagonal'});
axisLabels(ax, '', 'Maximum absolute RGB correlation (x10^{-3})');
title(ax, '(b) Adjacent-pixel correlation');

 ax = subplot(1, 3, 3, 'Parent', fig);
inputNames = string(weak.input);
order = ["allZero", "all255", "checkerboard", ...
    "rowGradient", "columnGradient"];
labels = {'All zero', 'All 255', 'Checkerboard', ...
    'Row gradient', 'Column gradient'};
values = zeros(1, numel(order));
for index = 1:numel(order)
    item = weak(inputNames == order(index), :);
    assert(height(item) == 1, 'A weak-input category is missing.');
    values(index) = item.cipherEntropy;
end
bar(ax, values, 0.68, 'FaceColor', palette(3), 'EdgeColor', 'none');
xticks(ax, 1:numel(labels));
xticklabels(ax, labels);
xtickangle(ax, 18);
axisLabels(ax, '', 'Joint RGB entropy (bit/byte)');
title(ax, '(c) Structured weak inputs');

path = fullfile(outputRoot, 'fig11_statistical_diagnostics.pdf');
exportVector(fig, path);
finalizeFigure(fig);
files = string(path);
end

function files = exportFigure12(resultRoot, outputRoot)
repeated = readCanonicalTable(resultRoot, ...
    'P1_repeated_performance.csv', ...
    {'caseName', 'tileSize', 'tileCount', 'batchIndex', ...
    'encryptMedianMs', 'encryptIQRMs', 'encryptMeanMs', ...
    'decryptMedianMs', 'decryptIQRMs', 'decryptMeanMs', ...
    'encryptMemoryDeltaMB', 'decryptMemoryDeltaMB', ...
    'encryptMemoryAfterMB', 'decryptMemoryAfterMB', ...
    'trialCount', 'warmupCount'});
large = readCanonicalTable(resultRoot, ...
    'P1_large_scale_performance.csv', ...
    {'caseName', 'tileSize', 'tileCount', 'height', 'width', ...
    'payloadBytes', 'encryptMedianMs', 'encryptIQRMs', ...
    'decryptMedianMs', 'decryptIQRMs', 'encryptMBps', ...
    'decryptMBps', 'encryptMemoryDeltaMB', ...
    'decryptMemoryDeltaMB', 'encryptMemoryAfterMB', ...
    'decryptMemoryAfterMB', 'trialCount', 'warmupCount'});

smallCommon = repeated(:, {'caseName', 'tileSize', 'tileCount', ...
    'encryptMedianMs', 'encryptIQRMs', 'decryptMedianMs', 'decryptIQRMs'});
largeCommon = large(:, {'caseName', 'tileSize', 'tileCount', ...
    'encryptMedianMs', 'encryptIQRMs', 'decryptMedianMs', 'decryptIQRMs'});
timing = [smallCommon; largeCommon];
isB16 = timing.tileSize == 16;
assert(all(timing.encryptIQRMs >= 0) && all(timing.decryptIQRMs >= 0), ...
    'Figure 12 IQR widths must be nonnegative.');

fig = makeFigure([16.2 8.0]);
 ax = subplot(2, 2, [1 2], 'Parent', fig);
hold(ax, 'on');
scatter(ax, timing.tileCount(isB16), timing.encryptMedianMs(isB16), ...
    34, 'o', 'MarkerFaceColor', palette(1), 'MarkerEdgeColor', 'w', ...
    'LineWidth', 0.4);
scatter(ax, timing.tileCount(isB16), timing.decryptMedianMs(isB16), ...
    38, '^', 'MarkerFaceColor', palette(2), 'MarkerEdgeColor', 'w', ...
    'LineWidth', 0.4);
isB4 = timing.tileSize == 4;
scatter(ax, timing.tileCount(isB4), timing.encryptMedianMs(isB4), ...
    38, 's', 'MarkerFaceColor', palette(3), 'MarkerEdgeColor', 'w', ...
    'LineWidth', 0.4);
scatter(ax, timing.tileCount(isB4), timing.decryptMedianMs(isB4), ...
    38, 'd', 'MarkerFaceColor', palette(4), 'MarkerEdgeColor', 'w', ...
    'LineWidth', 0.4);
set(ax, 'XScale', 'log', 'YScale', 'log');
axisLabels(ax, 'Macroblock count', 'Batch median time (ms)');
ylim(ax, [2 500]);
legend(ax, {'B=16 encryption', 'B=16 decryption', ...
    'B=4 encryption', 'B=4 decryption'}, ...
    'Location', 'northwest', 'Box', 'off');
title(ax, '(a) Independent-batch median timings');

 ax = subplot(2, 2, 3, 'Parent', fig);
hold(ax, 'on');
scatter(ax, timing.tileCount(isB16), timing.encryptIQRMs(isB16), ...
    32, 'o', 'MarkerFaceColor', palette(1), 'MarkerEdgeColor', 'w', ...
    'LineWidth', 0.4);
scatter(ax, timing.tileCount(isB16), timing.decryptIQRMs(isB16), ...
    36, '^', 'MarkerFaceColor', palette(2), 'MarkerEdgeColor', 'w', ...
    'LineWidth', 0.4);
set(ax, 'XScale', 'log');
axisLabels(ax, 'Macroblock count', 'Within-batch IQR width (ms)');
ylim(ax, [0 18]);
title(ax, '(b) Timing dispersion, B=16');

 ax = subplot(2, 2, 4, 'Parent', fig);
largeTileCount = unique(large.tileCount, 'stable');
encryptThroughput = zeros(numel(largeTileCount), 1);
decryptThroughput = zeros(numel(largeTileCount), 1);
for index = 1:numel(largeTileCount)
    rows = large.tileCount == largeTileCount(index);
    encryptThroughput(index) = median(large.encryptMBps(rows));
    decryptThroughput(index) = median(large.decryptMBps(rows));
end
bar(ax, 1:numel(largeTileCount), ...
    [encryptThroughput decryptThroughput], 'grouped');
xticks(ax, 1:numel(largeTileCount));
xticklabels(ax, compose('%d tiles', largeTileCount));
axisLabels(ax, '', 'Median throughput (MB/s)');
legend(ax, {'Encryption', 'Decryption'}, 'Box', 'off', ...
    'Location', 'northoutside', 'Orientation', 'horizontal');
title(ax, '(c) Large-input throughput');

path = fullfile(outputRoot, 'fig12_performance_scaling.pdf');
exportVector(fig, path);
finalizeFigure(fig);
files = string(path);
end

function plotStageDistribution(ax, stage, values, yLabel, reference, ...
        addCapacity)
hold(ax, 'on');
stageValues = unique(stage(:)).';
medianValues = zeros(size(stageValues));
lowerValues = zeros(size(stageValues));
upperValues = zeros(size(stageValues));
observationHandle = gobjects(1);
for index = 1:numel(stageValues)
    sample = double(values(stage == stageValues(index)));
    x = deterministicJitter(repmat(stageValues(index), numel(sample), 1), ...
        0.18);
    pointHandle = scatter(ax, x, sample, 12, ...
        'MarkerFaceColor', palette(5), ...
        'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.35);
    if index == 1
        observationHandle = pointHandle;
    end
    medianValues(index) = median(sample);
    quartiles = prctile(sample, [25 75]);
    lowerValues(index) = quartiles(1);
    upperValues(index) = quartiles(2);
end
iqrHandle = fill(ax, [stageValues fliplr(stageValues)], ...
    [lowerValues fliplr(upperValues)], palette(1), ...
    'FaceAlpha', 0.14, 'EdgeColor', 'none');
medianHandle = plot(ax, stageValues, medianValues, '-o', 'LineWidth', 1.45, ...
    'MarkerSize', 4.5, 'Color', palette(1), ...
    'MarkerFaceColor', palette(1));
referenceHandle = gobjects(0);
if ~isempty(reference)
    referenceHandle = yline(ax, reference, ':', ...
        'Color', neutral(0.38));
end
if addCapacity
    capacity = 3 * min(2 .^ stageValues, 256);
    capacityHandle = plot(ax, stageValues, capacity, '--', 'LineWidth', 1.0, ...
        'Color', palette(4));
    legend(ax, [observationHandle iqrHandle medianHandle ...
        referenceHandle capacityHandle], {'Observations', 'IQR', 'Median', ...
        'Byte reference', 'Support-capacity bound'}, ...
        'Location', 'northwest', 'Box', 'off');
else
    legend(ax, [observationHandle iqrHandle medianHandle], ...
        {'Observations', 'IQR', 'Median'}, ...
        'Location', 'northwest', 'Box', 'off');
end
axisLabels(ax, 'Stage', yLabel);
xticks(ax, stageValues);
xlim(ax, [0.6 9.4]);
title(ax, sprintf('(%c) %s', char('a' + (contains(yLabel, 'bits'))), yLabel));
end

function plotCategoryDistribution(ax, group, values, categoryOrder, labels)
hold(ax, 'on');
for index = 1:numel(categoryOrder)
    sample = double(values(group == categoryOrder(index)));
    assert(~isempty(sample), 'A required plotting category is empty.');
    x = deterministicJitter(repmat(index, numel(sample), 1), 0.14);
    scatter(ax, x, sample, 15, 'MarkerFaceColor', palette(index), ...
        'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.42);
    quartiles = prctile(sample, [25 50 75]);
    plot(ax, [index - 0.22 index + 0.22], [quartiles(1) quartiles(1)], ...
        '-', 'Color', palette(index), 'LineWidth', 1.0);
    plot(ax, [index - 0.27 index + 0.27], [quartiles(2) quartiles(2)], ...
        '-', 'Color', neutral(0.05), 'LineWidth', 1.7);
    plot(ax, [index - 0.22 index + 0.22], [quartiles(3) quartiles(3)], ...
        '-', 'Color', palette(index), 'LineWidth', 1.0);
    plot(ax, [index index], [quartiles(1) quartiles(3)], ...
        '-', 'Color', palette(index), 'LineWidth', 1.0);
end
xlim(ax, [0.5 numel(categoryOrder) + 0.5]);
xticks(ax, 1:numel(categoryOrder));
xticklabels(ax, labels);
end

function plotLocalityPanel(fig, rowCount, columnCount, panel, item, panelLabel)
[rowIndices, columnIndices] = find(item.allowedMask);
rowMin = min(rowIndices);
rowMax = max(rowIndices);
columnMin = min(columnIndices);
columnMax = max(columnIndices);
rowRange = max(1, rowMin - 2):min(size(item.allowedMask, 1), rowMax + 2);
columnRange = max(1, columnMin - 2):min(size(item.allowedMask, 2), columnMax + 2);

isCipherErrorPanel = mod(panel - 1, columnCount) == 0;
if isCipherErrorPanel
    mask = item.cipherErrorMask(rowRange, columnRange);
else
    mask = item.differenceMagnitude(rowRange, columnRange);
end

ax = subplot(rowCount, columnCount, panel, 'Parent', fig);
imagesc(ax, mask);
axis(ax, 'image');
if isCipherErrorPanel
    colormap(ax, [0.94 0.94 0.94; palette(1)]);
else
    colormap(ax, localityMagnitudeMap());
    caxis(ax, [0 255]);
end
hold(ax, 'on');
rectangle(ax, 'Position', [columnMin - columnRange(1) + 0.5, ...
    rowMin - rowRange(1) + 0.5, columnMax - columnMin + 1, ...
    rowMax - rowMin + 1], 'EdgeColor', [0.05 0.25 0.70], ...
    'LineWidth', 1.0);

text(ax, 0.03, 0.97, panelLabel, 'Units', 'normalized', ...
    'FontName', 'Times New Roman', 'FontSize', 10, ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'Color', neutral(0.05), 'BackgroundColor', 'w', 'Margin', 1.5);
if panel == 1
    title(ax, 'Ciphertext error');
elseif panel == 2
    title(ax, 'Decryption difference magnitude');
end
set(ax, 'XTick', 1:4:numel(columnRange), 'YTick', 1:4:numel(rowRange));
if panel > columnCount
    xlabel(ax, 'Column (local)');
end
if mod(panel - 1, columnCount) == 0
    ylabel(ax, 'Row (local)');
end
grid(ax, 'on');
box(ax, 'on');
ax.FontName = 'Times New Roman';
ax.FontSize = 8.5;
ax.LineWidth = 0.75;
ax.GridAlpha = 0.18;
if panel == 4
    colorbarHandle = colorbar(ax, 'eastoutside');
    colorbarHandle.Label.String = 'Max. RGB difference';
    colorbarHandle.FontName = 'Times New Roman';
    colorbarHandle.FontSize = 7.5;
end
end

function item = normalizeLocalityCase(item)
item = unwrapScalar(item);
item.cipherErrorMask = logical(getNamedField(item, ...
    {'cipherErrorMask', 'errorMask', 'cipherMask'}));
item.differenceMask = logical(getNamedField(item, ...
    {'differenceMask', 'decryptDifferenceMask', 'plainDifferenceMask'}));
item.allowedMask = logical(getNamedField(item, ...
    {'allowedMask', 'macroblockMask', 'targetMacroblockMask'}));
if isfield(item, 'plain') && isfield(item, 'damagedRecovered')
    % Use the maximum absolute RGB-channel difference for the heat map.
    item.differenceMagnitude = max(abs(double(item.damagedRecovered) - ...
        double(item.plain)), [], 3);
else
    item.differenceMagnitude = double(item.differenceMask);
end
assert(ismatrix(item.cipherErrorMask) && ismatrix(item.differenceMask) ...
    && isequal(size(item.differenceMask), size(item.allowedMask)), ...
    'Figure 9 masks have inconsistent dimensions.');
assert(isequal(size(item.differenceMagnitude), size(item.differenceMask)), ...
    'Figure 9 difference magnitude has inconsistent dimensions.');
assert(nnz(item.differenceMask & ~item.allowedMask) == 0, ...
    'Figure 9 data contain a difference outside the permitted macroblock.');
end

function data = loadFigureMat(figureDataRoot, fileName)
path = fullfile(figureDataRoot, fileName);
assert(exist(path, 'file') == 2, ...
    ['Required final-scheme figure data are missing: %s\n' ...
    'Run generate_paper_figure_data first.'], path);
data = load(path);
assert(~isempty(fieldnames(data)), 'The frozen figure-data MAT file is empty.');
end

function tableResult = readFigureTable(figureDataRoot, fileName, required)
path = fullfile(figureDataRoot, fileName);
assert(exist(path, 'file') == 2, ...
    ['Required final-scheme figure data are missing: %s\n' ...
    'Run generate_paper_figure_data first.'], path);
tableResult = readtable(path, 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
missing = setdiff(required, tableResult.Properties.VariableNames, 'stable');
assert(isempty(missing), 'Figure data %s lacks field(s): %s', ...
    fileName, strjoin(missing, ', '));
assert(height(tableResult) > 0, 'Figure data %s are empty.', fileName);
end

function value = getNamedField(container, names)
if istable(container)
    fields = container.Properties.VariableNames;
else
    container = unwrapScalar(container);
    fields = fieldnames(container);
end
for index = 1:numel(names)
    match = find(strcmpi(fields, names{index}), 1);
    if ~isempty(match)
        value = container.(fields{match});
        return
    end
end
error('Required field not found. Accepted names: %s', strjoin(names, ', '));
end

function value = unwrapScalar(value)
assert(isstruct(value) && isscalar(value), ...
    'Expected a scalar structure in paper figure data.');
end

function tableResult = readCanonicalTable(resultRoot, fileName, required)
path = fullfile(resultRoot, fileName);
assert(exist(path, 'file') == 2, 'Canonical result file is missing: %s', path);
tableResult = readtable(path, 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
missing = setdiff(required, tableResult.Properties.VariableNames, 'stable');
assert(isempty(missing), 'Canonical result %s lacks field(s): %s', ...
    fileName, strjoin(missing, ', '));
assert(height(tableResult) > 0, 'Canonical result %s is empty.', fileName);
end

function fig = makeFigure(sizeCm)
fig = figure('Visible', ternaryVisible(), 'Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 sizeCm], 'PaperPositionMode', 'auto');
end

function value = ternaryVisible()
if keepFigureOpen()
    value = 'on';
else
    value = 'off';
end
end

function value = keepFigureOpen()
value = strcmpi(strtrim(getenv('PGCIN_WHCL_KEEP_FIGURES')), '1') || ...
    strcmpi(strtrim(getenv('PGCIN_WHCL_KEEP_FIGURES')), 'true');
end

function finalizeFigure(fig)
if keepFigureOpen()
    fprintf('Preview is open. Adjust the figure, then export it manually.\n');
else
    close(fig);
end
end

function showImage(ax, image, label)
imshow(image, 'Parent', ax);
axis(ax, 'image', 'off');
title(ax, label, 'Interpreter', 'none');
end

function exportVector(fig, path)
if keepFigureOpen()
    return;
end
exportgraphics(fig, path, 'ContentType', 'vector', ...
    'BackgroundColor', 'white');
end

function exportRaster(fig, path)
if keepFigureOpen()
    return;
end
exportgraphics(fig, path, 'Resolution', 600, ...
    'BackgroundColor', 'white');
end

function axisLabels(ax, xLabel, yLabel)
if ~isempty(xLabel)
    xlabel(ax, xLabel);
end
if ~isempty(yLabel)
    ylabel(ax, yLabel);
end
grid(ax, 'on');
box(ax, 'on');
ax.FontName = 'Times New Roman';
ax.FontSize = 8.5;
ax.LineWidth = 0.75;
ax.GridAlpha = 0.16;
ax.MinorGridAlpha = 0.08;
end

function x = deterministicJitter(center, amplitude)
count = numel(center);
if count <= 1
    offsets = 0;
else
    permutation = mod((0:count - 1) * 37, count);
    offsets = ((permutation + 0.5) / count - 0.5) * 2 * amplitude;
end
x = double(center(:)) + offsets(:);
end

function value = byteEntropy(image)
counts = accumarray(double(image(:)) + 1, 1, [256 1]);
probability = counts(counts > 0) / numel(image);
value = -sum(probability .* log2(probability));
end

function label = caseLetter(index)
label = char('A' + index - 1);
end

function color = palette(index)
colors = [0.10 0.38 0.66; ...
    0.76 0.24 0.18; ...
    0.12 0.52 0.38; ...
    0.52 0.32 0.65; ...
    0.34 0.56 0.72; ...
    0.83 0.55 0.13];
color = colors(mod(index - 1, size(colors, 1)) + 1, :);
end

function color = neutral(value)
color = repmat(value, 1, 3);
end

function colors = localityMagnitudeMap()
count = 256;
low = [0.94 0.94 0.94];
high = palette(2);
weights = linspace(0, 1, count).';
colors = low + weights .* (high - low);
end

function output = appendPaths(existing, added)
added = string(added(:));
output = strings(numel(existing) + numel(added), 1);
output(1:numel(existing)) = existing;
output(numel(existing) + 1:end) = added;
end
