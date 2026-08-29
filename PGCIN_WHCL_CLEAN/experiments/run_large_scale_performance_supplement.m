function results = run_large_scale_performance_supplement()
%RUNLARGESCALEPERFORMANCESUPPLEMENT Measure larger clean-only inputs.

experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = fileparts(experimentRoot);
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(cleanRoot);

cases = [16, 256; 16, 1024];
batchCount = 2;
trialCount = 5;
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
            5100 + 100 * caseIndex + batchIndex);
        cfg = pgcinwhcl.defaultConfig();
        cfg.tileSize = tileSize;
        cfg = pgcinwhcl.withNonce(cfg, uint8( ...
            mod(32 * (batchIndex - 1) + (0:15), 256)));
        [cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
        assert(isequal(plain, pgcinwhcl.decryptImage( ...
            cipher, cfg, meta)), 'Large-scale round trip failed.');
        for warmupIndex = 1:warmupCount
            pgcinwhcl.encryptImage(plain, cfg);
            pgcinwhcl.decryptImage(cipher, cfg, meta);
        end
        encryptMs = zeros(trialCount, 1);
        decryptMs = zeros(trialCount, 1);
        encryptMemoryBefore = zeros(trialCount, 1);
        encryptMemoryAfter = zeros(trialCount, 1);
        decryptMemoryBefore = zeros(trialCount, 1);
        decryptMemoryAfter = zeros(trialCount, 1);
        for trialIndex = 1:trialCount
            encryptMemoryBefore(trialIndex) = matlabMemoryBytes();
            start = tic;
            pgcinwhcl.encryptImage(plain, cfg);
            encryptMs(trialIndex) = 1000 * toc(start);
            encryptMemoryAfter(trialIndex) = matlabMemoryBytes();
            decryptMemoryBefore(trialIndex) = matlabMemoryBytes();
            start = tic;
            pgcinwhcl.decryptImage(cipher, cfg, meta);
            decryptMs(trialIndex) = 1000 * toc(start);
            decryptMemoryAfter(trialIndex) = matlabMemoryBytes();
        end
        writeIndex = writeIndex + 1;
        rows(writeIndex).caseName = sprintf('B%d_%dtiles', ...
            tileSize, tileCount);
        rows(writeIndex).tileSize = tileSize;
        rows(writeIndex).tileCount = tileCount;
        rows(writeIndex).height = heightValue;
        rows(writeIndex).width = widthValue;
        rows(writeIndex).payloadBytes = heightValue * widthValue * 3;
        rows(writeIndex).encryptMedianMs = median(encryptMs);
        rows(writeIndex).encryptIQRMs = iqr(encryptMs);
        rows(writeIndex).decryptMedianMs = median(decryptMs);
        rows(writeIndex).decryptIQRMs = iqr(decryptMs);
        rows(writeIndex).encryptMBps = rows(writeIndex).payloadBytes / ...
            (rows(writeIndex).encryptMedianMs / 1000) / 1e6;
        rows(writeIndex).decryptMBps = rows(writeIndex).payloadBytes / ...
            (rows(writeIndex).decryptMedianMs / 1000) / 1e6;
        rows(writeIndex).encryptMemoryDeltaMB = median( ...
            encryptMemoryAfter - encryptMemoryBefore) / 2 ^ 20;
        rows(writeIndex).decryptMemoryDeltaMB = median( ...
            decryptMemoryAfter - decryptMemoryBefore) / 2 ^ 20;
        rows(writeIndex).encryptMemoryAfterMB = median( ...
            encryptMemoryAfter) / 2 ^ 20;
        rows(writeIndex).decryptMemoryAfterMB = median( ...
            decryptMemoryAfter) / 2 ^ 20;
        rows(writeIndex).trialCount = trialCount;
        rows(writeIndex).warmupCount = warmupCount;
    end
end
rows = rows(1:writeIndex);
tableResult = struct2table(rows);
writetable(tableResult, fullfile(resultRoot, ...
    'P1_large_scale_performance.csv'));
save(fullfile(resultRoot, 'P1_large_scale_performance.mat'), ...
    'tableResult', 'cases', 'batchCount', 'trialCount', 'warmupCount', '-v7');

results = struct();
results.algorithm = 'PGCIN-WHCL';
results.matlabVersion = version;
results.tableResult = tableResult;
results.memoryMetric = 'MATLAB memory() before/after diagnostic; not peak memory';
save(fullfile(resultRoot, 'large_scale_performance_supplement.mat'), ...
    'results', '-v7');
writeManifest(results, resultRoot, experimentRoot);
fprintf('PGCIN-WHCL large-scale performance supplement completed.\n');
end

function [heightValue, widthValue] = dimensionsForTileCount( ...
        tileSize, tileCount)
sideTiles = sqrt(tileCount);
assert(sideTiles == floor(sideTiles), ...
    'Large-scale supplement requires a square tile count.');
heightValue = tileSize * sideTiles;
widthValue = heightValue;
end

function bytes = matlabMemoryBytes()
try
    memoryInfo = memory;
    bytes = double(memoryInfo.MemUsedMATLAB);
catch
    bytes = NaN;
end
end

function image = makeTestImage(heightValue, widthValue, seed)
[column, row] = meshgrid(0:widthValue - 1, 0:heightValue - 1);
red = mod(17 * row + 31 * column + seed, 256);
green = mod(13 * row + 47 * column + 3 * seed, 256);
blue = mod(29 * row + 19 * column + 5 * seed, 256);
image = uint8(cat(3, red, green, blue));
end

function writeManifest(results, resultRoot, experimentRoot)
fileId = fopen(fullfile(resultRoot, ...
    'P1_LARGE_SCALE_MANIFEST.txt'), 'w');
assert(fileId >= 0, 'Cannot write large-scale manifest.');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'algorithm=%s\n', results.algorithm);
fprintf(fileId, 'matlabVersion=%s\n', results.matlabVersion);
fprintf(fileId, 'timestamp=%s\n', char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss')));
fprintf(fileId, 'script=%s\n', mfilename('fullpath'));
fprintf(fileId, 'scriptSha256=%s\n', fileSha256(fullfile(experimentRoot, ...
    'run_large_scale_performance_supplement.m')));
fprintf(fileId, 'csv=P1_large_scale_performance.csv\n');
fprintf(fileId, 'rows=%d\n', height(results.tableResult));
fprintf(fileId, 'memoryMetric=%s\n', results.memoryMetric);
end

function digest = fileSha256(path)
fileId = fopen(path, 'r');
assert(fileId >= 0, 'Cannot read file for SHA-256.');
cleanup = onCleanup(@() fclose(fileId));
bytes = fread(fileId, inf, '*uint8').';
digestBytes = pgcinwhcl.sha256(bytes);
digest = lower(reshape(dec2hex(digestBytes, 2).', 1, []));
end
