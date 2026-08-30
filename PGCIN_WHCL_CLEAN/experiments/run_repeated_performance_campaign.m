function results = run_repeated_performance_campaign()
%RUNREPEATEDPERFORMANCECAMPAIGN Repeat paired timing on the clean API.

experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = resolve_clean_root(experimentRoot);
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(cleanRoot);

cases = [4, 2; 16, 2; 16, 16; 16, 64];
batchCount = 3;
trialCount = 7;
warmupCount = 2;
rows = repmat(struct(), size(cases, 1) * batchCount, 1);
writeIndex = 0;
for caseIndex = 1:size(cases, 1)
    tileSize = cases(caseIndex, 1);
    tileCount = cases(caseIndex, 2);
    [heightValue, widthValue] = dimensionsForTileCount( ...
        tileSize, tileCount);
    for batchIndex = 1:batchCount
        plain = makeTestImage(heightValue, widthValue, ...
            3100 + 100 * caseIndex + batchIndex);
        cfg = pgcinwhcl.defaultConfig();
        cfg.tileSize = tileSize;
        cfg = pgcinwhcl.withNonce(cfg, uint8( ...
            mod(16 * (batchIndex - 1) + (0:15), 256)));
        [cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
        assert(isequal(plain, pgcinwhcl.decryptImage( ...
            cipher, cfg, meta)), 'Performance warm-up round trip failed.');
        for warmupIndex = 1:warmupCount
            pgcinwhcl.encryptImage(plain, cfg);
            pgcinwhcl.decryptImage(cipher, cfg, meta);
        end
        encryptMs = zeros(trialCount, 1);
        decryptMs = zeros(trialCount, 1);
        encryptBefore = zeros(trialCount, 1);
        encryptAfter = zeros(trialCount, 1);
        decryptBefore = zeros(trialCount, 1);
        decryptAfter = zeros(trialCount, 1);
        for trialIndex = 1:trialCount
            encryptBefore(trialIndex) = matlabMemoryBytes();
            start = tic;
            pgcinwhcl.encryptImage(plain, cfg);
            encryptMs(trialIndex) = 1000 * toc(start);
            encryptAfter(trialIndex) = matlabMemoryBytes();
            decryptBefore(trialIndex) = matlabMemoryBytes();
            start = tic;
            pgcinwhcl.decryptImage(cipher, cfg, meta);
            decryptMs(trialIndex) = 1000 * toc(start);
            decryptAfter(trialIndex) = matlabMemoryBytes();
        end
        writeIndex = writeIndex + 1;
        rows(writeIndex).caseName = sprintf('B%d_%dtiles', ...
            tileSize, tileCount);
        rows(writeIndex).tileSize = tileSize;
        rows(writeIndex).tileCount = tileCount;
        rows(writeIndex).batchIndex = batchIndex;
        rows(writeIndex).encryptMedianMs = median(encryptMs);
        rows(writeIndex).encryptIQRMs = iqr(encryptMs);
        rows(writeIndex).encryptMeanMs = mean(encryptMs);
        rows(writeIndex).decryptMedianMs = median(decryptMs);
        rows(writeIndex).decryptIQRMs = iqr(decryptMs);
        rows(writeIndex).decryptMeanMs = mean(decryptMs);
        rows(writeIndex).encryptMemoryDeltaMB = ...
            (median(encryptAfter - encryptBefore)) / 2 ^ 20;
        rows(writeIndex).decryptMemoryDeltaMB = ...
            (median(decryptAfter - decryptBefore)) / 2 ^ 20;
        rows(writeIndex).encryptMemoryAfterMB = ...
            median(encryptAfter) / 2 ^ 20;
        rows(writeIndex).decryptMemoryAfterMB = ...
            median(decryptAfter) / 2 ^ 20;
        rows(writeIndex).trialCount = trialCount;
        rows(writeIndex).warmupCount = warmupCount;
    end
end
rows = rows(1:writeIndex);
tableResult = struct2table(rows);
writetable(tableResult, fullfile(resultRoot, ...
    'P1_repeated_performance.csv'));
save(fullfile(resultRoot, 'P1_repeated_performance.mat'), ...
    'tableResult', 'cases', 'batchCount', 'trialCount', 'warmupCount', '-v7');

results = struct();
results.algorithm = 'PGCIN-WHCL';
results.matlabVersion = version;
results.tableResult = tableResult;
results.memoryMetric = 'Windows MATLAB memory() MemUsedMATLAB before/after; not a peak-memory measurement';
save(fullfile(resultRoot, 'repeated_performance_campaign.mat'), ...
    'results', '-v7');
fprintf('PGCIN-WHCL repeated performance campaign completed.\n');
end

function bytes = matlabMemoryBytes()
try
    memoryInfo = memory;
    bytes = double(memoryInfo.MemUsedMATLAB);
catch
    bytes = NaN;
end
end

function [heightValue, widthValue] = dimensionsForTileCount( ...
        tileSize, tileCount)
if tileCount == 2
    heightValue = tileSize;
    widthValue = 2 * tileSize;
else
    sideTiles = sqrt(tileCount);
    assert(sideTiles == floor(sideTiles), ...
        'Tile count must be 2 or a square.');
    heightValue = tileSize * sideTiles;
    widthValue = heightValue;
end
end

function image = makeTestImage(heightValue, widthValue, seed)
[column, row] = meshgrid(0:widthValue - 1, 0:heightValue - 1);
red = mod(17 * row + 31 * column + seed, 256);
green = mod(13 * row + 47 * column + 3 * seed, 256);
blue = mod(29 * row + 19 * column + 5 * seed, 256);
image = uint8(cat(3, red, green, blue));
end
