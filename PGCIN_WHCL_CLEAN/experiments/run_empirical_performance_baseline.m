function results = run_empirical_performance_baseline()
%RUNEMPIRICALPERFORMANCEBASELINE Run clean-only E1/E2/P1 experiments.

experimentRoot = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(experimentRoot));
cleanRoot = resolve_clean_root(experimentRoot);
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(cleanRoot);

results = struct();
results.algorithm = 'PGCIN-WHCL';
results.matlabVersion = version;
results.timestamp = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
results.naturalImages = runNaturalImageDiagnostics(projectRoot, resultRoot);
results.weakInputs = runWeakInputDiagnostics(resultRoot);
results.performance = runPairedPerformance(resultRoot);
save(fullfile(resultRoot, 'empirical_performance_baseline.mat'), ...
    'results', '-v7');
fprintf('PGCIN-WHCL clean E1/E2/P1 baseline completed.\n');
end

function tableResult = runNaturalImageDiagnostics(projectRoot, resultRoot)
imageDir = resolve_kodak_root(projectRoot);
files = dir(fullfile(imageDir, '*.png'));
assert(~isempty(files), 'Kodak image corpus is not available.');
rowCount = numel(files);
names = strings(rowCount, 1);
entropyAll = zeros(rowCount, 1);
entropyR = zeros(rowCount, 1);
entropyG = zeros(rowCount, 1);
entropyB = zeros(rowCount, 1);
corrH = zeros(rowCount, 1);
corrV = zeros(rowCount, 1);
corrD = zeros(rowCount, 1);
npcr = zeros(rowCount, 1);
minimumChannelNpcr = zeros(rowCount, 1);
uaci = zeros(rowCount, 1);
minimumChannelUaci = zeros(rowCount, 1);
cfg = pgcinwhcl.defaultConfig();
cfg.tileSize = 16;
cfg = pgcinwhcl.withNonce(cfg, uint8(64:79));
for index = 1:rowCount
    path = fullfile(files(index).folder, files(index).name);
    plain = pgcinwhcl.readImageFile(path);
    [cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
    assert(isequal(plain, pgcinwhcl.decryptImage(cipher, cfg, meta)), ...
        'E1 round trip failed for %s.', files(index).name);
    names(index) = string(files(index).name);
    entropyAll(index) = pgcinwhcl.imageEntropy(cipher);
    entropyR(index) = channelEntropy(cipher(:, :, 1));
    entropyG(index) = channelEntropy(cipher(:, :, 2));
    entropyB(index) = channelEntropy(cipher(:, :, 3));
    corrH(index) = adjacentCorrelation(cipher, 0, 1);
    corrV(index) = adjacentCorrelation(cipher, 1, 0);
    corrD(index) = adjacentCorrelationDiagonal(cipher);

    changedPlain = plain;
    changedPlain(1, 1, 1) = bitxor(changedPlain(1, 1, 1), uint8(1));
    changedCipher = pgcinwhcl.encryptImage(changedPlain, cfg);
    [npcr(index), minimumChannelNpcr(index), ...
        uaci(index), minimumChannelUaci(index)] = ...
        rgbDifferenceMetrics(cipher, changedCipher);
end
tableResult = table(names, entropyAll, entropyR, entropyG, entropyB, ...
    corrH, corrV, corrD, npcr, minimumChannelNpcr, uaci, ...
    minimumChannelUaci, ...
    'VariableNames', {'image', 'entropyAll', 'entropyR', 'entropyG', ...
    'entropyB', 'absCorrHorizontal', 'absCorrVertical', ...
    'absCorrDiagonal', 'meanChannelNPCR_percent', ...
    'minimumChannelNPCR_percent', 'meanChannelUACI_percent', ...
    'minimumChannelUACI_percent'});
writetable(tableResult, fullfile(resultRoot, 'E1_natural_image_diagnostics.csv'));
save(fullfile(resultRoot, 'E1_natural_image_diagnostics.mat'), ...
    'tableResult', '-v7');
end

function tableResult = runWeakInputDiagnostics(resultRoot)
side = 64;
cfg = pgcinwhcl.defaultConfig();
cfg.tileSize = 16;
cfg = pgcinwhcl.withNonce(cfg, uint8(80:95));
[column, row] = meshgrid(0:side - 1, 0:side - 1);
checker = uint8(255 * mod(row + column, 2));
rowGradient = uint8(mod(row, 256));
columnGradient = uint8(mod(column, 256));
patterns = {zeros(side, side, 3, 'uint8'), ...
    255 * ones(side, side, 3, 'uint8'), repmat(checker, 1, 1, 3), ...
    repmat(rowGradient, 1, 1, 3), repmat(columnGradient, 1, 1, 3)};
names = ["allZero"; "all255"; "checkerboard"; ...
    "rowGradient"; "columnGradient"];
count = numel(patterns);
entropyValues = zeros(count, 1);
repeatPass = false(count, 1);
roundTripPass = false(count, 1);
for index = 1:count
    plain = patterns{index};
    [cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
    repeatCipher = pgcinwhcl.encryptImage(plain, cfg);
    entropyValues(index) = pgcinwhcl.imageEntropy(cipher);
    repeatPass(index) = isequal(cipher, repeatCipher);
    roundTripPass(index) = isequal(plain, pgcinwhcl.decryptImage(cipher, cfg, meta));
end
tableResult = table(names, entropyValues, repeatPass, roundTripPass, ...
    'VariableNames', {'input', 'cipherEntropy', ...
    'fixedNonceRepeatPass', 'roundTripPass'});
assert(all(repeatPass) && all(roundTripPass), ...
    'E2 weak-input baseline failed.');
writetable(tableResult, fullfile(resultRoot, 'E2_weak_input_diagnostics.csv'));
save(fullfile(resultRoot, 'E2_weak_input_diagnostics.mat'), ...
    'tableResult', '-v7');
end

function tableResult = runPairedPerformance(resultRoot)
cases = [4, 2; 16, 2; 16, 16];
caseCount = size(cases, 1);
trialCount = 7;
names = strings(caseCount, 1);
encryptMedianMs = zeros(caseCount, 1);
encryptIqrMs = zeros(caseCount, 1);
decryptMedianMs = zeros(caseCount, 1);
decryptIqrMs = zeros(caseCount, 1);
encryptThroughput = zeros(caseCount, 1);
decryptThroughput = zeros(caseCount, 1);
for caseIndex = 1:caseCount
    tileSize = cases(caseIndex, 1);
    tileCount = cases(caseIndex, 2);
    [height, width] = dimensionsForTileCount(tileSize, tileCount);
    plain = makeTestImage(height, width, 1700 + caseIndex);
    cfg = pgcinwhcl.defaultConfig();
    cfg.tileSize = tileSize;
    cfg = pgcinwhcl.withNonce(cfg, uint8(112:127));
    [cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
    assert(isequal(plain, pgcinwhcl.decryptImage(cipher, cfg, meta)), ...
        'P1 warm-up round trip failed.');
    for warmupIndex = 1:2
        runWarmupIteration(plain, cipher, cfg, meta, warmupIndex);
    end
    encryptMs = zeros(trialCount, 1);
    decryptMs = zeros(trialCount, 1);
    for trial = 1:trialCount
        start = tic;
        pgcinwhcl.encryptImage(plain, cfg);
        encryptMs(trial) = 1000 * toc(start);
        start = tic;
        pgcinwhcl.decryptImage(cipher, cfg, meta);
        decryptMs(trial) = 1000 * toc(start);
    end
    names(caseIndex) = sprintf('B%d_%dtiles', tileSize, tileCount);
    encryptMedianMs(caseIndex) = median(encryptMs);
    encryptIqrMs(caseIndex) = iqr(encryptMs);
    decryptMedianMs(caseIndex) = median(decryptMs);
    decryptIqrMs(caseIndex) = iqr(decryptMs);
    payloadBytes = height * width * 3;
    encryptThroughput(caseIndex) = payloadBytes / ...
        (encryptMedianMs(caseIndex) / 1000) / 1e6;
    decryptThroughput(caseIndex) = payloadBytes / ...
        (decryptMedianMs(caseIndex) / 1000) / 1e6;
end
tableResult = table(names, cases(:, 1), cases(:, 2), encryptMedianMs, ...
    encryptIqrMs, decryptMedianMs, decryptIqrMs, encryptThroughput, ...
    decryptThroughput, 'VariableNames', {'caseName', 'tileSize', ...
    'tileCount', 'encryptMedianMs', 'encryptIQRMs', 'decryptMedianMs', ...
    'decryptIQRMs', 'encryptMBps', 'decryptMBps'});
writetable(tableResult, fullfile(resultRoot, 'P1_paired_performance.csv'));
save(fullfile(resultRoot, 'P1_paired_performance.mat'), ...
    'tableResult', '-v7');
end

function value = channelEntropy(channel)
counts = accumarray(double(channel(:)) + 1, 1, [256 1]);
probability = counts(counts > 0) / numel(channel);
value = -sum(probability .* log2(probability));
end

function runWarmupIteration(plain, cipher, cfg, meta, iteration)
assert(iteration >= 1, 'Warm-up iteration index must be positive.');
pgcinwhcl.encryptImage(plain, cfg);
pgcinwhcl.decryptImage(cipher, cfg, meta);
end

function value = adjacentCorrelation(image, rowStep, colStep)
values = zeros(1, 3);
for channel = 1:3
    plane = double(image(:, :, channel));
    left = plane(1:end - rowStep, 1:end - colStep);
    right = plane(1 + rowStep:end, 1 + colStep:end);
    values(channel) = abs(corr(left(:), right(:)));
end
value = max(values);
end

function value = adjacentCorrelationDiagonal(image)
value = adjacentCorrelation(image, 1, 1);
end

function [meanNpcr, minimumNpcr, meanUaci, minimumUaci] = ...
        rgbDifferenceMetrics(reference, candidate)
npcrChannels = zeros(1, 3);
uaciChannels = zeros(1, 3);
for channel = 1:3
    referenceChannel = reference(:, :, channel);
    candidateChannel = candidate(:, :, channel);
    npcrChannels(channel) = 100 * nnz( ...
        referenceChannel ~= candidateChannel) / numel(referenceChannel);
    uaciChannels(channel) = 100 * mean(abs( ...
        double(referenceChannel(:)) - double(candidateChannel(:))) / 255);
end
meanNpcr = mean(npcrChannels);
minimumNpcr = min(npcrChannels);
meanUaci = mean(uaciChannels);
minimumUaci = min(uaciChannels);
end

function [height, width] = dimensionsForTileCount(tileSize, tileCount)
if tileCount == 2
    height = tileSize;
    width = 2 * tileSize;
else
    sideTiles = sqrt(tileCount);
    assert(sideTiles == floor(sideTiles), 'Tile count must be square or 2.');
    height = tileSize * sideTiles;
    width = height;
end
end

function image = makeTestImage(height, width, seed)
[column, row] = meshgrid(0:width - 1, 0:height - 1);
red = mod(17 * row + 31 * column + seed, 256);
green = mod(13 * row + 47 * column + 3 * seed, 256);
blue = mod(29 * row + 19 * column + 5 * seed, 256);
image = uint8(cat(3, red, green, blue));
end
