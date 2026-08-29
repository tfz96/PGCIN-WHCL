function results = run_dependency_locality_baseline()
%RUNDEPENDENCYLOCALITYBASELINE Run clean-only D1/D2/D3 baseline experiments.

experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = fileparts(experimentRoot);
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(cleanRoot);

results = struct();
results.algorithm = 'PGCIN-WHCL';
results.matlabVersion = version;
results.timestamp = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
results.fixedSession = runFixedSessionDependency(cleanRoot, resultRoot);
results.apiSensitivity = runApiSensitivity(cleanRoot, resultRoot);
results.payloadLocality = runPayloadErrorLocality(cleanRoot, resultRoot);
save(fullfile(resultRoot, 'dependency_locality_baseline.mat'), ...
    'results', '-v7');
fprintf('PGCIN-WHCL clean D1/D2/D3 baseline completed.\n');
end

function tableResult = runFixedSessionDependency(~, resultRoot)
tileSize = 16;
tileRows = 4;
tileCols = 4;
tileCount = tileRows * tileCols;
plain = makeTestImage(tileRows * tileSize, tileCols * tileSize, 1201);
cfg = pgcinwhcl.defaultConfig();
cfg.tileSize = tileSize;
cfg = pgcinwhcl.withNonce(cfg, uint8(0:15));
syntheticIV = pgcinwhcl.deriveSyntheticIV(plain, cfg);
runtimeConfig = pgcinwhcl.applySyntheticIV(cfg, syntheticIV);
session = pgcinwhcl.deriveSession(runtimeConfig, syntheticIV, tileCount);

perturbed = plain;
perturbed(5, 7, 2) = bitxor(perturbed(5, 7, 2), uint8(1));
[~, baseStages] = pgcinwhcl.processImage(plain, runtimeConfig, ...
    session, true);
[~, changedStages] = pgcinwhcl.processImage(perturbed, runtimeConfig, ...
    session, true);
stageCount = numel(baseStages);
affectedBytes = zeros(stageCount, 1);
affectedBits = zeros(stageCount, 1);
outsideBytes = zeros(stageCount, 1);
for stage = 1:stageCount
    reference = baseStages{stage};
    candidate = changedStages{stage};
    difference = reference ~= candidate;
    affectedBytes(stage) = nnz(difference);
    affectedBits(stage) = bitHammingDistance(reference, candidate);
    outside = difference;
    outside(1:tileSize, 1:tileSize, :) = false;
    outsideBytes(stage) = nnz(outside);
end
tableResult = table((1:stageCount).', affectedBytes, affectedBits, ...
    outsideBytes, 'VariableNames', {'stage', 'affectedBytes', ...
    'affectedBits', 'outsideTouchedMacroblockBytes'});
assert(all(outsideBytes == 0), ...
    'D1 fixed-session change escaped the touched macroblock.');
writetable(tableResult, fullfile(resultRoot, 'D1_fixed_session_dependency.csv'));
save(fullfile(resultRoot, 'D1_fixed_session_dependency.mat'), ...
    'tableResult', 'plain', 'perturbed', '-v7');
end

function tableResult = runApiSensitivity(~, resultRoot)
tileSize = 16;
side = 64;
plain = makeTestImage(side, side, 1302);
cfg = pgcinwhcl.defaultConfig();
cfg.tileSize = tileSize;
cfg = pgcinwhcl.withNonce(cfg, uint8(16:31));
[baselineCipher, baselineMeta] = pgcinwhcl.encryptImage(plain, cfg);
recovered = pgcinwhcl.decryptImage(baselineCipher, cfg, baselineMeta);
assert(isequal(plain, recovered), 'D2 baseline round trip failed.');

names = {'plaintextBit', 'masterKeyBit', 'nonceBit'};
changedCipherBytes = zeros(3, 1);
changedPixels = zeros(3, 1);
npcr = zeros(3, 1);
minimumChannelNpcr = zeros(3, 1);
uaci = zeros(3, 1);
minimumChannelUaci = zeros(3, 1);
for index = 1:3
    changedCfg = cfg;
    changedPlain = plain;
    switch index
        case 1
            changedPlain(17, 23, 1) = bitxor( ...
                changedPlain(17, 23, 1), uint8(1));
        case 2
            changedCfg.masterKey(1) = bitxor(changedCfg.masterKey(1), uint8(1));
        case 3
            changedCfg.nonce(1) = bitxor(changedCfg.nonce(1), uint8(1));
    end
    changedCfg.autoNonce = false;
    changedCipher = pgcinwhcl.encryptImage(changedPlain, changedCfg);
    difference = baselineCipher ~= changedCipher;
    changedCipherBytes(index) = nnz(difference);
    changedPixels(index) = nnz(any(difference, 3));
    [npcr(index), minimumChannelNpcr(index), ...
        uaci(index), minimumChannelUaci(index)] = ...
        rgbDifferenceMetrics(baselineCipher, changedCipher);
end
tableResult = table(names.', changedCipherBytes, changedPixels, npcr, ...
    minimumChannelNpcr, uaci, minimumChannelUaci, ...
    'VariableNames', {'perturbation', 'changedCipherBytes', ...
    'changedCipherPixels', 'meanChannelNPCR_percent', ...
    'minimumChannelNPCR_percent', 'meanChannelUACI_percent', ...
    'minimumChannelUACI_percent'});
writetable(tableResult, fullfile(resultRoot, 'D2_api_sensitivity.csv'));
save(fullfile(resultRoot, 'D2_api_sensitivity.mat'), ...
    'tableResult', 'baselineCipher', 'baselineMeta', '-v7');
end

function tableResult = runPayloadErrorLocality(~, resultRoot)
tileSize = 16;
side = 64;
plain = makeTestImage(side, side, 1403);
cfg = pgcinwhcl.defaultConfig();
cfg.tileSize = tileSize;
cfg = pgcinwhcl.withNonce(cfg, uint8(32:47));
[cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
locations = [5, 7, 1; 20, 20, 2; 48, 47, 3];
caseCount = size(locations, 1);
changedPixels = zeros(caseCount, 1);
outsidePixels = zeros(caseCount, 1);
affectedTileCount = zeros(caseCount, 1);
for index = 1:caseCount
    damaged = cipher;
    row = locations(index, 1);
    column = locations(index, 2);
    channel = locations(index, 3);
    damaged(row, column, channel) = bitxor( ...
        damaged(row, column, channel), uint8(1));
    recovered = pgcinwhcl.decryptImage(damaged, cfg, meta);
    difference = any(recovered ~= plain, 3);
    touchedRows = floor((row - 1) / tileSize) * tileSize + (1:tileSize);
    touchedCols = floor((column - 1) / tileSize) * tileSize + (1:tileSize);
    allowed = false(side, side);
    allowed(touchedRows, touchedCols) = true;
    outsidePixels(index) = nnz(difference & ~allowed);
    changedPixels(index) = nnz(difference);
    affectedTileCount(index) = countAffectedTiles(difference, tileSize);
end
tableResult = table(locations(:, 1), locations(:, 2), locations(:, 3), ...
    changedPixels, outsidePixels, affectedTileCount, ...
    'VariableNames', {'row', 'column', 'channel', 'changedPixels', ...
    'outsideTouchedMacroblockPixels', 'affectedMacroblockCount'});
assert(all(outsidePixels == 0), ...
    'D3 payload error escaped the touched macroblock.');
assert(all(affectedTileCount == 1), ...
    'D3 payload error affected more than one macroblock.');
writetable(tableResult, fullfile(resultRoot, 'D3_payload_error_locality.csv'));
save(fullfile(resultRoot, 'D3_payload_error_locality.mat'), ...
    'tableResult', 'plain', 'cipher', 'meta', '-v7');
end

function distance = bitHammingDistance(reference, candidate)
distance = 0;
for bit = 1:8
    distance = distance + nnz(bitget(reference, bit) ~= bitget(candidate, bit));
end
end

function count = countAffectedTiles(mask, tileSize)
tileRows = size(mask, 1) / tileSize;
tileCols = size(mask, 2) / tileSize;
count = 0;
for tileRow = 1:tileRows
    for tileCol = 1:tileCols
        rows = (tileRow - 1) * tileSize + (1:tileSize);
        cols = (tileCol - 1) * tileSize + (1:tileSize);
        count = count + any(mask(rows, cols), 'all');
    end
end
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

function image = makeTestImage(height, width, seed)
[column, row] = meshgrid(0:width - 1, 0:height - 1);
red = mod(17 * row + 31 * column + seed, 256);
green = mod(13 * row + 47 * column + 3 * seed, 256);
blue = mod(29 * row + 19 * column + 5 * seed, 256);
image = uint8(cat(3, red, green, blue));
end
