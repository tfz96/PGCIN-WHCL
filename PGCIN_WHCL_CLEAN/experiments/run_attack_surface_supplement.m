function results = run_attack_surface_supplement()
%RUN_ATTACK_SURFACE_SUPPLEMENT Quantify final-scheme attack boundaries.

experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = fileparts(experimentRoot);
projectRoot = fileparts(fileparts(experimentRoot));
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(cleanRoot);

results = struct();
results.algorithm = 'PGCIN-WHCL';
results.matlabVersion = version;
results.timestamp = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
results.maskReuse = runPlaintextMaskReuse(projectRoot, resultRoot);
results.macroblockManipulation = runMacroblockManipulation( ...
    projectRoot, resultRoot);
save(fullfile(resultRoot, 'attack_surface_supplement.mat'), ...
    'results', '-v7');
fprintf('PGCIN-WHCL attack-surface supplement completed.\n');
end

function summary = runPlaintextMaskReuse(projectRoot, resultRoot)
files = kodakFiles(projectRoot, 8);
nonces = uint8([16:31; 80:95]);
rowCount = numel(files) * size(nonces, 1);
rows = repmat(struct('image', "", 'nonceIndex', uint8(0), ...
    'repeatCipherExact', false, 'repeatSivExact', false, ...
    'changedSiv', false, 'xorByteAgreementPercent', 0, ...
    'additiveByteAgreementPercent', 0, ...
    'xorPixelAgreementPercent', 0, ...
    'additivePixelAgreementPercent', 0, ...
    'xorPSNRdB', 0, 'additivePSNRdB', 0), rowCount, 1);
writeIndex = 0;
for imageIndex = 1:numel(files)
    plain = pgcinwhcl.readImageFile(fullfile(files(imageIndex).folder, ...
        files(imageIndex).name));
    changedPlain = plain;
    row = max(1, floor(size(plain, 1) / 2));
    column = max(1, floor(size(plain, 2) / 2));
    changedPlain(row, column, 1) = bitxor( ...
        changedPlain(row, column, 1), uint8(1));
    for nonceIndex = 1:size(nonces, 1)
        cfg = pgcinwhcl.defaultConfig();
        cfg.tileSize = 16;
        cfg = pgcinwhcl.withNonce(cfg, nonces(nonceIndex, :));
        [cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
        [repeatCipher, repeatMeta] = pgcinwhcl.encryptImage(plain, cfg);
        [changedCipher, changedMeta] = pgcinwhcl.encryptImage( ...
            changedPlain, cfg);

        xorMask = bitxor(cipher, plain);
        xorRecovered = bitxor(changedCipher, xorMask);
        additiveMask = mod(double(cipher) - double(plain), 256);
        additiveRecovered = uint8(mod( ...
            double(changedCipher) - additiveMask, 256));

        writeIndex = writeIndex + 1;
        rows(writeIndex).image = string(files(imageIndex).name);
        rows(writeIndex).nonceIndex = uint8(nonceIndex);
        rows(writeIndex).repeatCipherExact = isequal(cipher, repeatCipher);
        rows(writeIndex).repeatSivExact = isequal( ...
            meta.syntheticIV, repeatMeta.syntheticIV);
        rows(writeIndex).changedSiv = ~isequal( ...
            meta.syntheticIV, changedMeta.syntheticIV);
        rows(writeIndex).xorByteAgreementPercent = byteAgreement( ...
            xorRecovered, changedPlain);
        rows(writeIndex).additiveByteAgreementPercent = byteAgreement( ...
            additiveRecovered, changedPlain);
        rows(writeIndex).xorPixelAgreementPercent = pixelAgreement( ...
            xorRecovered, changedPlain);
        rows(writeIndex).additivePixelAgreementPercent = pixelAgreement( ...
            additiveRecovered, changedPlain);
        rows(writeIndex).xorPSNRdB = imagePsnr(xorRecovered, changedPlain);
        rows(writeIndex).additivePSNRdB = imagePsnr( ...
            additiveRecovered, changedPlain);
    end
end
tableResult = struct2table(rows(1:writeIndex));
assert(all(tableResult.repeatCipherExact) ...
    && all(tableResult.repeatSivExact) && all(tableResult.changedSiv), ...
    'Mask-reuse session preconditions failed.');
writetable(tableResult, fullfile(resultRoot, ...
    'A1_plaintext_mask_reuse.csv'));
summary = struct('rows', height(tableResult), ...
    'xorByteAgreementMedian', median( ...
    tableResult.xorByteAgreementPercent), ...
    'additiveByteAgreementMedian', median( ...
    tableResult.additiveByteAgreementPercent), ...
    'xorPSNRMedian', median(tableResult.xorPSNRdB), ...
    'additivePSNRMedian', median(tableResult.additivePSNRdB));
end

function summary = runMacroblockManipulation(projectRoot, resultRoot)
files = kodakFiles(projectRoot, 8);
baselineNonce = uint8(112:127);
donorNonce = uint8(144:159);
rows = repmat(struct('image', "", 'caseType', "", ...
    'locationIndex', uint8(0), 'targetMacroblockCount', uint8(0), ...
    'decryptCompleted', false, 'exactRecovery', false, ...
    'changedPixels', uint64(0), 'outsideTargetPixels', uint64(0), ...
    'affectedMacroblockCount', uint32(0)), numel(files) * 4, 1);
writeIndex = 0;
for imageIndex = 1:numel(files)
    plain = pgcinwhcl.readImageFile(fullfile(files(imageIndex).folder, ...
        files(imageIndex).name));
    cfg = pgcinwhcl.defaultConfig();
    cfg.tileSize = 16;
    cfg = pgcinwhcl.withNonce(cfg, baselineNonce);
    [cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
    donorCfg = pgcinwhcl.withNonce(cfg, donorNonce);
    donorCipher = pgcinwhcl.encryptImage(plain, donorCfg);
    starts = replayStarts(size(cipher, 1), size(cipher, 2), 16);
    for locationIndex = 1:size(starts, 1)
        damaged = cipher;
        row = starts(locationIndex, 1);
        column = starts(locationIndex, 2);
        damaged(row:row + 15, column:column + 15, :) = ...
            donorCipher(row:row + 15, column:column + 15, :);
        allowed = false(size(plain, 1), size(plain, 2));
        allowed(row:row + 15, column:column + 15) = true;
        writeIndex = writeIndex + 1;
        rows(writeIndex) = manipulationRow(files(imageIndex).name, ...
            "crossSessionReplay", locationIndex, 1, damaged, cfg, ...
            meta, plain, allowed, 16);
    end

    damaged = cipher;
    firstRows = 1:16;
    firstCols = 1:16;
    lastRows = size(cipher, 1) - 15:size(cipher, 1);
    lastCols = size(cipher, 2) - 15:size(cipher, 2);
    firstTile = damaged(firstRows, firstCols, :);
    damaged(firstRows, firstCols, :) = damaged(lastRows, lastCols, :);
    damaged(lastRows, lastCols, :) = firstTile;
    allowed = false(size(plain, 1), size(plain, 2));
    allowed(firstRows, firstCols) = true;
    allowed(lastRows, lastCols) = true;
    writeIndex = writeIndex + 1;
    rows(writeIndex) = manipulationRow(files(imageIndex).name, ...
        "withinCipherSwap", 1, 2, damaged, cfg, meta, plain, allowed, 16);
end
tableResult = struct2table(rows(1:writeIndex));
assert(all(tableResult.decryptCompleted) ...
    && ~any(tableResult.exactRecovery) ...
    && all(tableResult.outsideTargetPixels == 0), ...
    'Macroblock manipulation boundary was not reproduced.');
writetable(tableResult, fullfile(resultRoot, ...
    'A2_macroblock_manipulation.csv'));
summary = struct('rows', height(tableResult), ...
    'decryptCompletionRate', mean(tableResult.decryptCompleted), ...
    'outsideMaximum', max(tableResult.outsideTargetPixels), ...
    'changedPixelsByType', groupsummary(tableResult, 'caseType', ...
    'median', 'changedPixels'));
end

function row = manipulationRow(imageName, caseType, locationIndex, ...
        targetCount, damaged, cfg, meta, plain, allowed, tileSize)
row = struct('image', string(imageName), 'caseType', string(caseType), ...
    'locationIndex', uint8(locationIndex), ...
    'targetMacroblockCount', uint8(targetCount), ...
    'decryptCompleted', false, 'exactRecovery', false, ...
    'changedPixels', uint64(0), 'outsideTargetPixels', uint64(0), ...
    'affectedMacroblockCount', uint32(0));
try
    recovered = pgcinwhcl.decryptImage(damaged, cfg, meta);
    difference = any(recovered ~= plain, 3);
    row.decryptCompleted = true;
    row.exactRecovery = isequal(recovered, plain);
    row.changedPixels = uint64(nnz(difference));
    row.outsideTargetPixels = uint64(nnz(difference & ~allowed));
    row.affectedMacroblockCount = uint32(countAffectedTiles( ...
        difference, tileSize));
catch
    row.decryptCompleted = false;
end
end

function starts = replayStarts(heightValue, widthValue, tileSize)
centerRow = floor((heightValue / tileSize) / 2) * tileSize + 1;
centerColumn = floor((widthValue / tileSize) / 2) * tileSize + 1;
centerRow = min(centerRow, heightValue - tileSize + 1);
centerColumn = min(centerColumn, widthValue - tileSize + 1);
starts = [1, 1; centerRow, centerColumn; ...
    heightValue - tileSize + 1, widthValue - tileSize + 1];
end

function files = kodakFiles(projectRoot, limit)
files = dir(fullfile(projectRoot, 'matlab', 'data', 'kodak', '*.png'));
assert(~isempty(files), 'Kodak image corpus is not available.');
[~, order] = sort({files.name});
files = files(order);
files = files(1:min(limit, numel(files)));
end

function value = byteAgreement(candidate, reference)
value = 100 * nnz(candidate == reference) / numel(reference);
end

function value = pixelAgreement(candidate, reference)
value = 100 * nnz(all(candidate == reference, 3)) / ...
    (size(reference, 1) * size(reference, 2));
end

function value = imagePsnr(candidate, reference)
mseValue = mean((double(candidate(:)) - double(reference(:))) .^ 2);
if mseValue == 0
    value = Inf;
else
    value = 10 * log10(255 ^ 2 / mseValue);
end
end

function count = countAffectedTiles(mask, tileSize)
tileRows = size(mask, 1) / tileSize;
tileColumns = size(mask, 2) / tileSize;
count = 0;
for tileRow = 1:tileRows
    for tileColumn = 1:tileColumns
        rows = (tileRow - 1) * tileSize + (1:tileSize);
        columns = (tileColumn - 1) * tileSize + (1:tileSize);
        count = count + any(mask(rows, columns), 'all');
    end
end
end
