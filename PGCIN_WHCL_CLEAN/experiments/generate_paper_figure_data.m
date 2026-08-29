function manifest = generate_paper_figure_data(selection)
%GENERATEPAPERFIGUREDATA Generate final-scheme data required by paper figures.
%
% manifest = generate_paper_figure_data()
% manifest = generate_paper_figure_data([3 5 9])

if nargin < 1 || isempty(selection)
    selection = [3 5 9];
end
selection = validateSelection(selection, [3 5 9]);
paths = resolvePaths();
ensureDirectory(paths.figureDataRoot);
addpath(paths.cleanRoot);

manifest = struct();
manifest.algorithm = 'PGCIN-WHCL';
manifest.matlabVersion = version;
manifest.timestamp = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
manifest.selectedFigures = selection;

if ismember(3, selection)
    manifest.fig03 = generateFigure03Data(paths);
end
if ismember(5, selection)
    manifest.fig05 = generateFigure05Data(paths);
end
if ismember(9, selection)
    manifest.fig09 = generateFigure09Data(paths);
end

save(fullfile(paths.figureDataRoot, 'paper_figure_data_manifest.mat'), ...
    'manifest', '-v7');
writeManifestText(manifest, paths);
fprintf('PGCIN-WHCL paper figure data generated in:\n%s\n', ...
    paths.figureDataRoot);
end

function summary = generateFigure03Data(paths)
cfg = pgcinwhcl.defaultConfig();
cfg.tileSize = 16;
nonce = uint8(0:15);
cfg = pgcinwhcl.withNonce(cfg, nonce);
plain = makeTestImage(16, 16, 316);
[runtimeConfig, session, state] = prepareRuntime(cfg, plain, 1);
schedule = pgcinwhcl.buildSchedule(runtimeConfig, session, 1, state);

pixelCount = cfg.tileSize ^ 2;
stageCount = double(schedule.stageCount);
support = eye(pixelCount) > 0;
stage = (1:stageCount).';
baseIncrement = pgcinwhcl.baseCenters(cfg.tileSize);
actualCenter = double(schedule.centers(:, 1));
minimumSupport = zeros(stageCount, 1);
medianSupport = zeros(stageCount, 1);
maximumSupport = zeros(stageCount, 1);
fullSupportRate = zeros(stageCount, 1);
pairRows = stageCount * double(schedule.pairCount);
pairStage = zeros(pairRows, 1);
pairIndex = zeros(pairRows, 1);
pairU = zeros(pairRows, 1);
pairV = zeros(pairRows, 1);
writeIndex = 0;

for stageIndex = 1:stageCount
    currentU = double(schedule.pairU(:, 1, stageIndex));
    currentV = double(schedule.pairV(:, 1, stageIndex));
    vertices = [currentU; currentV];
    assert(numel(unique(vertices)) == pixelCount, ...
        'Figure 3 schedule is not a perfect matching at stage %d.', ...
        stageIndex);
    unionRows = support(currentU, :) | support(currentV, :);
    nextSupport = false(pixelCount, pixelCount);
    nextSupport(currentU, :) = unionRows;
    nextSupport(currentV, :) = unionRows;
    support = nextSupport;
    supportSize = sum(support, 2);
    minimumSupport(stageIndex) = min(supportSize);
    medianSupport(stageIndex) = median(supportSize);
    maximumSupport(stageIndex) = max(supportSize);
    fullSupportRate(stageIndex) = mean(supportSize == pixelCount);

    rows = writeIndex + (1:numel(currentU));
    pairStage(rows) = stageIndex;
    pairIndex(rows) = (1:numel(currentU)).';
    pairU(rows) = currentU;
    pairV(rows) = currentV;
    writeIndex = writeIndex + numel(currentU);
end

stageTable = table(stage, baseIncrement, actualCenter, minimumSupport, ...
    medianSupport, maximumSupport, fullSupportRate);
pairTable = table(pairStage, pairIndex, pairU, pairV, ...
    'VariableNames', {'stage', 'pairIndex', 'pairU', 'pairV'});
assert(minimumSupport(end) == pixelCount ...
    && maximumSupport(end) == pixelCount ...
    && fullSupportRate(end) == 1, ...
    'Figure 3 schedule did not reproduce full graph support.');

writetable(stageTable, fullfile(paths.figureDataRoot, ...
    'fig03_stage_support.csv'));
writetable(pairTable, fullfile(paths.figureDataRoot, ...
    'fig03_schedule_pairs.csv'));
save(fullfile(paths.figureDataRoot, 'fig03_schedule_data.mat'), ...
    'stageTable', 'pairTable', 'schedule', 'nonce', '-v7');
summary = struct('stageCount', stageCount, ...
    'pairCountPerStage', double(schedule.pairCount), ...
    'finalMinimumSupport', minimumSupport(end), ...
    'finalFullSupportRate', fullSupportRate(end));
end

function summary = generateFigure05Data(paths)
imageNames = ["kodim01.png", "kodim23.png"];
nonces = uint8([16:31; 80:95]);
caseCount = numel(imageNames);
cases = repmat(struct('imageName', "", 'plain', uint8([]), ...
    'cipher', uint8([]), 'recovered', uint8([]), ...
    'absoluteError', uint8([]), 'meta', struct(), ...
    'nonce', uint8([]), 'cipherEntropy', 0, ...
    'roundTripPass', false), caseCount, 1);
rows = repmat(struct('image', "", 'nonceHex', "", ...
    'height', uint32(0), 'width', uint32(0), ...
    'cipherEntropy', 0, 'maximumAbsoluteError', uint8(0), ...
    'roundTripPass', false), caseCount, 1);

for index = 1:caseCount
    imagePath = fullfile(paths.kodakRoot, imageNames(index));
    assert(isfile(imagePath), 'Required Kodak image is missing: %s', ...
        imagePath);
    plain = pgcinwhcl.readImageFile(imagePath);
    cfg = pgcinwhcl.defaultConfig();
    cfg = pgcinwhcl.withNonce(cfg, nonces(index, :));
    [cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
    recovered = pgcinwhcl.decryptImage(cipher, cfg, meta);
    absoluteError = uint8(abs(double(recovered) - double(plain)));
    entropyValue = pgcinwhcl.imageEntropy(cipher);
    roundTripPass = isequal(plain, recovered);
    assert(roundTripPass && ~any(absoluteError(:)), ...
        'Figure 5 round trip failed for %s.', imageNames(index));

    cases(index).imageName = imageNames(index);
    cases(index).plain = plain;
    cases(index).cipher = cipher;
    cases(index).recovered = recovered;
    cases(index).absoluteError = absoluteError;
    cases(index).meta = meta;
    cases(index).nonce = nonces(index, :);
    cases(index).cipherEntropy = entropyValue;
    cases(index).roundTripPass = roundTripPass;
    rows(index).image = imageNames(index);
    rows(index).nonceHex = bytesToHex(nonces(index, :));
    rows(index).height = uint32(size(plain, 1));
    rows(index).width = uint32(size(plain, 2));
    rows(index).cipherEntropy = entropyValue;
    rows(index).maximumAbsoluteError = max(absoluteError(:));
    rows(index).roundTripPass = roundTripPass;
end

caseTable = struct2table(rows);
writetable(caseTable, fullfile(paths.figureDataRoot, ...
    'fig05_visual_results.csv'));
save(fullfile(paths.figureDataRoot, 'fig05_visual_results.mat'), ...
    'cases', 'caseTable', '-v7.3');
summary = struct('imageCount', caseCount, ...
    'images', imageNames, 'roundTripPass', all(caseTable.roundTripPass), ...
    'minimumCipherEntropy', min(caseTable.cipherEntropy));
end

function summary = generateFigure09Data(paths)
imageName = "kodim01.png";
imagePath = fullfile(paths.kodakRoot, imageName);
assert(isfile(imagePath), 'Required Kodak image is missing: %s', imagePath);
plain = pgcinwhcl.readImageFile(imagePath);
cfg = pgcinwhcl.defaultConfig();
cfg = pgcinwhcl.withNonce(cfg, uint8(112:127));
[cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
baselineRecovered = pgcinwhcl.decryptImage(cipher, cfg, meta);
baselineRoundTripPass = isequal(plain, baselineRecovered);
assert(baselineRoundTripPass, 'Figure 9 baseline round trip failed.');

locations = [37, 53, 1; 45, 61, 1];
burstSizes = [1, 1; 4, 4];
caseNames = ["singleBit", "burst4x4"];
caseCount = numel(caseNames);
cases = repmat(struct('caseName', "", 'plain', uint8([]), ...
    'cipher', uint8([]), 'damagedCipher', uint8([]), ...
    'baselineRecovered', uint8([]), 'damagedRecovered', uint8([]), ...
    'cipherErrorMask', false(0), 'differenceMask', false(0), ...
    'allowedMask', false(0), 'row', uint32(0), ...
    'column', uint32(0), 'channel', uint8(0), ...
    'burstHeight', uint8(0), 'burstWidth', uint8(0), ...
    'macroblockRows', uint32([]), 'macroblockColumns', uint32([]), ...
    'changedPixels', uint64(0), 'outsideMacroblockPixels', uint64(0), ...
    'baselineRoundTripPass', false, 'decryptCompleted', false, ...
    'exactRecovery', false), caseCount, 1);
rows = repmat(struct('caseName', "", 'row', uint32(0), ...
    'column', uint32(0), 'channel', uint8(0), ...
    'burstHeight', uint8(0), 'burstWidth', uint8(0), ...
    'changedPixels', uint64(0), 'outsideMacroblockPixels', uint64(0), ...
    'affectedMacroblockCount', uint32(0), ...
    'baselineRoundTripPass', false, 'decryptCompleted', false, ...
    'exactRecovery', false), caseCount, 1);

for index = 1:caseCount
    row = locations(index, 1);
    column = locations(index, 2);
    channel = locations(index, 3);
    burstHeight = burstSizes(index, 1);
    burstWidth = burstSizes(index, 2);
    assert(floor((row - 1) / cfg.tileSize) == ...
        floor((row + burstHeight - 2) / cfg.tileSize) ...
        && floor((column - 1) / cfg.tileSize) == ...
        floor((column + burstWidth - 2) / cfg.tileSize), ...
        'Figure 9 burst must remain inside one macroblock.');
    damagedCipher = cipher;
    cipherErrorMask = false(size(cipher, 1), size(cipher, 2));
    errorRows = row:row + burstHeight - 1;
    errorColumns = column:column + burstWidth - 1;
    damagedCipher(errorRows, errorColumns, channel) = bitxor( ...
        damagedCipher(errorRows, errorColumns, channel), uint8(1));
    cipherErrorMask(errorRows, errorColumns) = true;
    damagedRecovered = pgcinwhcl.decryptImage(damagedCipher, cfg, meta);
    differenceMask = any(damagedRecovered ~= plain, 3);
    [macroblockRows, macroblockColumns, allowedMask] = ...
        macroblockMask(size(plain), row, column, cfg.tileSize);
    changedPixels = nnz(differenceMask);
    outsidePixels = nnz(differenceMask & ~allowedMask);
    affectedCount = countAffectedMacroblocks(differenceMask, cfg.tileSize);
    decryptCompleted = true;
    exactRecovery = isequal(damagedRecovered, plain);
    assert(changedPixels == cfg.tileSize ^ 2, ...
        'Figure 9 did not affect exactly one full macroblock.');
    assert(outsidePixels == 0 && affectedCount == 1, ...
        'Figure 9 payload error escaped its macroblock.');

    cases(index).caseName = caseNames(index);
    cases(index).plain = plain;
    cases(index).cipher = cipher;
    cases(index).damagedCipher = damagedCipher;
    cases(index).baselineRecovered = baselineRecovered;
    cases(index).damagedRecovered = damagedRecovered;
    cases(index).cipherErrorMask = cipherErrorMask;
    cases(index).differenceMask = differenceMask;
    cases(index).allowedMask = allowedMask;
    cases(index).row = uint32(row);
    cases(index).column = uint32(column);
    cases(index).channel = uint8(channel);
    cases(index).burstHeight = uint8(burstHeight);
    cases(index).burstWidth = uint8(burstWidth);
    cases(index).macroblockRows = uint32(macroblockRows);
    cases(index).macroblockColumns = uint32(macroblockColumns);
    cases(index).changedPixels = uint64(changedPixels);
    cases(index).outsideMacroblockPixels = uint64(outsidePixels);
    cases(index).baselineRoundTripPass = baselineRoundTripPass;
    cases(index).decryptCompleted = decryptCompleted;
    cases(index).exactRecovery = exactRecovery;

    rows(index).caseName = caseNames(index);
    rows(index).row = uint32(row);
    rows(index).column = uint32(column);
    rows(index).channel = uint8(channel);
    rows(index).burstHeight = uint8(burstHeight);
    rows(index).burstWidth = uint8(burstWidth);
    rows(index).changedPixels = uint64(changedPixels);
    rows(index).outsideMacroblockPixels = uint64(outsidePixels);
    rows(index).affectedMacroblockCount = uint32(affectedCount);
    rows(index).baselineRoundTripPass = baselineRoundTripPass;
    rows(index).decryptCompleted = decryptCompleted;
    rows(index).exactRecovery = exactRecovery;
end

caseTable = struct2table(rows);
writetable(caseTable, fullfile(paths.figureDataRoot, ...
    'fig09_payload_locality.csv'));
save(fullfile(paths.figureDataRoot, 'fig09_payload_locality.mat'), ...
    'cases', 'caseTable', 'meta', '-v7.3');
summary = struct('image', imageName, 'caseCount', caseCount, ...
    'changedPixels', double(caseTable.changedPixels).', ...
    'outsideMaximum', max(double(caseTable.outsideMacroblockPixels)), ...
    'baselineRoundTripPass', baselineRoundTripPass);
end

function [runtimeConfig, session, state] = prepareRuntime(cfg, plain, tileCount)
syntheticIV = pgcinwhcl.deriveSyntheticIV(plain, cfg);
runtimeConfig = pgcinwhcl.applySyntheticIV(cfg, syntheticIV);
session = pgcinwhcl.deriveSession(runtimeConfig, syntheticIV, tileCount);
state = pgcinwhcl.generateStates(runtimeConfig, session, tileCount);
end

function [rows, columns, mask] = macroblockMask(imageSize, row, column, tileSize)
rowStart = floor((row - 1) / tileSize) * tileSize + 1;
columnStart = floor((column - 1) / tileSize) * tileSize + 1;
rows = rowStart:min(rowStart + tileSize - 1, imageSize(1));
columns = columnStart:min(columnStart + tileSize - 1, imageSize(2));
mask = false(imageSize(1), imageSize(2));
mask(rows, columns) = true;
end

function count = countAffectedMacroblocks(mask, tileSize)
tileRows = ceil(size(mask, 1) / tileSize);
tileColumns = ceil(size(mask, 2) / tileSize);
count = 0;
for tileRow = 1:tileRows
    rows = (tileRow - 1) * tileSize + 1:min(tileRow * tileSize, size(mask, 1));
    for tileColumn = 1:tileColumns
        columns = (tileColumn - 1) * tileSize + 1: ...
            min(tileColumn * tileSize, size(mask, 2));
        count = count + any(mask(rows, columns), 'all');
    end
end
end

function image = makeTestImage(height, width, seed)
[column, row] = meshgrid(0:width - 1, 0:height - 1);
red = mod(17 * row + 31 * column + seed, 256);
green = mod(13 * row + 47 * column + 3 * seed, 256);
blue = mod(29 * row + 19 * column + 5 * seed, 256);
image = uint8(cat(3, red, green, blue));
end

function paths = resolvePaths()
experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = fileparts(experimentRoot);
projectRoot = fileparts(cleanRoot);
resultRoot = resolve_experiment_result_root(experimentRoot);
paths = struct('experimentRoot', experimentRoot, ...
    'cleanRoot', cleanRoot, 'projectRoot', projectRoot, ...
    'kodakRoot', fullfile(projectRoot, 'matlab', 'data', 'kodak'), ...
    'figureDataRoot', fullfile(resultRoot, 'figure_data'));
end

function ensureDirectory(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end

function selection = validateSelection(selection, supported)
validateattributes(selection, {'numeric'}, ...
    {'vector', 'real', 'finite', 'integer', 'positive'});
selection = unique(double(selection(:).'), 'stable');
assert(all(ismember(selection, supported)), ...
    'Supported figure-data selections are 3, 5, and 9.');
end

function value = bytesToHex(bytes)
value = string(lower(reshape(dec2hex(bytes, 2).', 1, [])));
end

function writeManifestText(manifest, paths)
path = fullfile(paths.figureDataRoot, 'paper_figure_data_manifest.txt');
fileId = fopen(path, 'w');
assert(fileId >= 0, 'Cannot write paper figure data manifest.');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'algorithm=%s\n', manifest.algorithm);
fprintf(fileId, 'matlabVersion=%s\n', manifest.matlabVersion);
fprintf(fileId, 'timestamp=%s\n', manifest.timestamp);
fprintf(fileId, 'selectedFigures=%s\n', ...
    strjoin(string(manifest.selectedFigures), ','));
fprintf(fileId, 'productionPackage=%s\n', paths.cleanRoot);
fprintf(fileId, 'kodakDirectory=%s\n', paths.kodakRoot);
fprintf(fileId, 'note=No independent permutation or diffusion image is generated.\n');
end
