function results = run_repeated_dependency_campaign()
%RUNREPEATEDDEPENDENCYCAMPAIGN Repeat D1/D2/D3 on final clean code.

experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = resolve_clean_root(experimentRoot);
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(cleanRoot);

results = struct();
results.algorithm = 'PGCIN-WHCL';
results.matlabVersion = version;
results.timestamp = char(datetime('now', 'Format', ...
    'yyyy-MM-dd''T''HH:mm:ss'));
results.D1 = repeatD1(resultRoot);
results.D2 = repeatD2(resultRoot);
results.D3 = repeatD3(resultRoot);
save(fullfile(resultRoot, 'repeated_dependency_campaign.mat'), ...
    'results', '-v7');
fprintf('PGCIN-WHCL repeated D1/D2/D3 campaign completed.\n');
end

function summary = repeatD1(resultRoot)
tileSize = 16;
side = 64;
seeds = [2101, 2102, 2103];
nonces = uint8([0:15; 16:31; 32:47]);
locations = [5, 7, 1; 8, 31, 2; 16, 16, 3; ...
    17, 17, 1; 32, 48, 2; 48, 20, 3; 64, 64, 1];
rowCount = numel(seeds) * size(locations, 1) * 9;
rows = zeros(rowCount, 7);
writeIndex = 0;
for seedIndex = 1:numel(seeds)
    plain = makeTestImage(side, side, seeds(seedIndex));
    cfg = pgcinwhcl.defaultConfig();
    cfg.tileSize = tileSize;
    cfg = pgcinwhcl.withNonce(cfg, nonces(seedIndex, :));
    syntheticIV = pgcinwhcl.deriveSyntheticIV(plain, cfg);
    runtimeConfig = pgcinwhcl.applySyntheticIV(cfg, syntheticIV);
    session = pgcinwhcl.deriveSession(runtimeConfig, syntheticIV, 16);
    [~, baseStages] = pgcinwhcl.processImage(plain, runtimeConfig, ...
        session, true);
    for locationIndex = 1:size(locations, 1)
        perturbed = plain;
        row = locations(locationIndex, 1);
        col = locations(locationIndex, 2);
        channel = locations(locationIndex, 3);
        perturbed(row, col, channel) = bitxor( ...
            perturbed(row, col, channel), uint8(1));
        [~, changedStages] = pgcinwhcl.processImage(perturbed, ...
            runtimeConfig, session, true);
        touchedRows = floor((row - 1) / tileSize) * tileSize + ...
            (1:tileSize);
        touchedCols = floor((col - 1) / tileSize) * tileSize + ...
            (1:tileSize);
        for stage = 1:numel(baseStages)
            difference = baseStages{stage} ~= changedStages{stage};
            outside = difference;
            outside(touchedRows, touchedCols, :) = false;
            writeIndex = writeIndex + 1;
            rows(writeIndex, :) = [seedIndex, locationIndex, stage, ...
                nnz(difference), bitHammingDistance( ...
                baseStages{stage}, changedStages{stage}), nnz(outside), ...
                nnz(difference(touchedRows, touchedCols, :))];
        end
    end
end
rows = rows(1:writeIndex, :);
tableResult = array2table(rows, 'VariableNames', {'seedIndex', ...
    'locationIndex', 'stage', 'affectedBytes', 'affectedBits', ...
    'outsideTouchedMacroblockBytes', 'insideAffectedBytes'});
tableResult.seedIndex = uint16(tableResult.seedIndex);
tableResult.locationIndex = uint16(tableResult.locationIndex);
tableResult.stage = uint8(tableResult.stage);
writetable(tableResult, fullfile(resultRoot, ...
    'D1_repeated_fixed_session_dependency.csv'));
assert(all(tableResult.outsideTouchedMacroblockBytes == 0), ...
    'Repeated D1 escaped the touched macroblock.');
summary = struct('rows', height(tableResult), 'outsideMax', ...
    max(tableResult.outsideTouchedMacroblockBytes), ...
    'stageMedianAffectedBytes', groupsummary(tableResult, 'stage', ...
    'median', 'affectedBytes'));
end

function summary = repeatD2(resultRoot)
tileSize = 16;
side = 64;
seeds = [2201, 2202, 2203];
nonces = uint8([48:63; 64:79; 80:95]);
rows = zeros(numel(seeds) * 3, 8);
writeIndex = 0;
names = {'plaintextBit', 'masterKeyBit', 'nonceBit'};
for seedIndex = 1:numel(seeds)
    plain = makeTestImage(side, side, seeds(seedIndex));
    cfg = pgcinwhcl.defaultConfig();
    cfg.tileSize = tileSize;
    cfg = pgcinwhcl.withNonce(cfg, nonces(seedIndex, :));
    [baselineCipher, baselineMeta] = pgcinwhcl.encryptImage(plain, cfg);
    assert(isequal(plain, pgcinwhcl.decryptImage( ...
        baselineCipher, cfg, baselineMeta)), 'Repeated D2 round trip failed.');
    for caseIndex = 1:3
        changedPlain = plain;
        changedCfg = cfg;
        switch caseIndex
            case 1
                changedPlain(17, 23, 1) = bitxor( ...
                    changedPlain(17, 23, 1), uint8(1));
            case 2
                changedCfg.masterKey(1) = bitxor( ...
                    changedCfg.masterKey(1), uint8(1));
            case 3
                changedCfg.nonce(1) = bitxor(changedCfg.nonce(1), uint8(1));
        end
        changedCfg.autoNonce = false;
        changedCipher = pgcinwhcl.encryptImage(changedPlain, changedCfg);
        difference = baselineCipher ~= changedCipher;
        writeIndex = writeIndex + 1;
        [meanNpcr, minimumNpcr, meanUaci, minimumUaci] = ...
            rgbDifferenceMetrics(baselineCipher, changedCipher);
        rows(writeIndex, :) = [seedIndex, caseIndex, ...
            nnz(difference), nnz(any(difference, 3)), ...
            meanNpcr, minimumNpcr, meanUaci, minimumUaci];
    end
end
rows = rows(1:writeIndex, :);
tableResult = table(uint16(rows(:, 1)), string(names(rows(:, 2))).', ...
    uint32(rows(:, 3)), uint32(rows(:, 4)), rows(:, 5), rows(:, 6), ...
    rows(:, 7), rows(:, 8), ...
    'VariableNames', {'seedIndex', 'perturbation', 'changedCipherBytes', ...
    'changedCipherPixels', 'meanChannelNPCR_percent', ...
    'minimumChannelNPCR_percent', 'meanChannelUACI_percent', ...
    'minimumChannelUACI_percent'});
writetable(tableResult, fullfile(resultRoot, ...
    'D2_repeated_api_sensitivity.csv'));
summary = struct('rows', height(tableResult), 'NPCRMedian', ...
    groupsummary(tableResult, 'perturbation', 'median', ...
    'meanChannelNPCR_percent'), ...
    'UACIMedian', groupsummary(tableResult, 'perturbation', ...
    'median', 'meanChannelUACI_percent'));
end

function summary = repeatD3(resultRoot)
tileSize = 16;
side = 64;
seeds = [2301, 2302, 2303];
nonces = uint8([96:111; 112:127; 128:143]);
locations = [1, 1, 1; 1, 64, 2; 64, 1, 3; 64, 64, 1; ...
    16, 16, 2; 17, 17, 3; 32, 32, 1; 48, 48, 2];
rows = zeros(numel(seeds) * size(locations, 1), 6);
writeIndex = 0;
for seedIndex = 1:numel(seeds)
    plain = makeTestImage(side, side, seeds(seedIndex));
    cfg = pgcinwhcl.defaultConfig();
    cfg.tileSize = tileSize;
    cfg = pgcinwhcl.withNonce(cfg, nonces(seedIndex, :));
    [cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
    for locationIndex = 1:size(locations, 1)
        damaged = cipher;
        row = locations(locationIndex, 1);
        col = locations(locationIndex, 2);
        channel = locations(locationIndex, 3);
        damaged(row, col, channel) = bitxor( ...
            damaged(row, col, channel), uint8(1));
        recovered = pgcinwhcl.decryptImage(damaged, cfg, meta);
        difference = any(recovered ~= plain, 3);
        touchedRows = floor((row - 1) / tileSize) * tileSize + ...
            (1:tileSize);
        touchedCols = floor((col - 1) / tileSize) * tileSize + ...
            (1:tileSize);
        allowed = false(side, side);
        allowed(touchedRows, touchedCols) = true;
        writeIndex = writeIndex + 1;
        rows(writeIndex, :) = [seedIndex, locationIndex, row, col, ...
            nnz(difference), nnz(difference & ~allowed)];
    end
end
rows = rows(1:writeIndex, :);
tableResult = array2table(rows, 'VariableNames', {'seedIndex', ...
    'locationIndex', 'row', 'column', 'changedPixels', ...
    'outsideTouchedMacroblockPixels'});
tableResult.seedIndex = uint16(tableResult.seedIndex);
tableResult.locationIndex = uint16(tableResult.locationIndex);
writetable(tableResult, fullfile(resultRoot, ...
    'D3_repeated_payload_error_locality.csv'));
assert(all(tableResult.outsideTouchedMacroblockPixels == 0), ...
    'Repeated D3 escaped the touched macroblock.');
summary = struct('rows', height(tableResult), 'outsideMax', ...
    max(tableResult.outsideTouchedMacroblockPixels), ...
    'changedPixelsMedian', median(tableResult.changedPixels));
end

function distance = bitHammingDistance(reference, candidate)
distance = 0;
for bit = 1:8
    distance = distance + nnz(bitget(reference, bit) ~= ...
        bitget(candidate, bit));
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

function image = makeTestImage(heightValue, widthValue, seed)
[column, row] = meshgrid(0:widthValue - 1, 0:heightValue - 1);
red = mod(17 * row + 31 * column + seed, 256);
green = mod(13 * row + 47 * column + 3 * seed, 256);
blue = mod(29 * row + 19 * column + 5 * seed, 256);
image = uint8(cat(3, red, green, blue));
end
