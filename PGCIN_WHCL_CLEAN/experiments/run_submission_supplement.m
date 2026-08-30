function results = run_submission_supplement()
%RUNSUBMISSIONSUPPLEMENT Expand final-only D2 and D3 evidence.

experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = resolve_clean_root(experimentRoot);
projectRoot = fileparts(fileparts(experimentRoot));
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(cleanRoot);

results = struct();
results.algorithm = 'PGCIN-WHCL';
results.matlabVersion = version;
results.timestamp = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
results.D2 = runKodakApiSensitivity(projectRoot, resultRoot);
results.D3 = runBurstPayloadLocality(projectRoot, resultRoot);
save(fullfile(resultRoot, 'submission_supplement.mat'), 'results', '-v7');
writeSupplementManifest(results, resultRoot, experimentRoot, projectRoot);
fprintf('PGCIN-WHCL submission supplement completed.\n');
end

function summary = runKodakApiSensitivity(projectRoot, resultRoot)
imageDir = resolve_kodak_root(projectRoot);
files = dir(fullfile(imageDir, '*.png'));
assert(~isempty(files), 'Kodak image corpus is not available.');
[~, order] = sort({files.name});
files = files(order);
nonces = uint8([16:31; 48:63; 80:95]);
perturbationNames = {'plaintextBit', 'masterKeyBit', 'nonceBit'};
rowCount = numel(files) * size(nonces, 1) * numel(perturbationNames);
rows = repmat(struct('image', "", 'nonceIndex', uint8(0), ...
    'perturbation', "", 'height', uint32(0), 'width', uint32(0), ...
    'changedCipherBytes', uint64(0), 'changedCipherPixels', uint64(0), ...
    'meanChannelNPCR_percent', 0, 'minimumChannelNPCR_percent', 0, ...
    'meanChannelUACI_percent', 0, 'minimumChannelUACI_percent', 0, ...
    'roundTripPass', false), ...
    rowCount, 1);
writeIndex = 0;
for imageIndex = 1:numel(files)
    plain = pgcinwhcl.readImageFile(fullfile(files(imageIndex).folder, ...
        files(imageIndex).name));
    for nonceIndex = 1:size(nonces, 1)
        cfg = pgcinwhcl.defaultConfig();
        cfg.tileSize = 16;
        cfg = pgcinwhcl.withNonce(cfg, nonces(nonceIndex, :));
        [baselineCipher, baselineMeta] = pgcinwhcl.encryptImage(plain, cfg);
        recovered = pgcinwhcl.decryptImage(baselineCipher, cfg, baselineMeta);
        assert(isequal(plain, recovered), ...
            'Kodak D2 round trip failed for %s.', files(imageIndex).name);
        for perturbationIndex = 1:numel(perturbationNames)
            changedPlain = plain;
            changedCfg = cfg;
            switch perturbationIndex
                case 1
                    row = max(1, floor(size(plain, 1) / 2));
                    col = max(1, floor(size(plain, 2) / 2));
                    changedPlain(row, col, 1) = bitxor( ...
                        changedPlain(row, col, 1), uint8(1));
                case 2
                    changedCfg.masterKey(1) = bitxor( ...
                        changedCfg.masterKey(1), uint8(1));
                case 3
                    changedCfg.nonce(1) = bitxor( ...
                        changedCfg.nonce(1), uint8(1));
                    changedCfg.autoNonce = false;
            end
            [changedCipher, changedMeta] = pgcinwhcl.encryptImage( ...
                changedPlain, changedCfg);
            changedRecovered = pgcinwhcl.decryptImage( ...
                changedCipher, changedCfg, changedMeta);
            difference = baselineCipher ~= changedCipher;
            writeIndex = writeIndex + 1;
            rows(writeIndex).image = string(files(imageIndex).name);
            rows(writeIndex).nonceIndex = uint8(nonceIndex);
            rows(writeIndex).perturbation = string( ...
                perturbationNames{perturbationIndex});
            rows(writeIndex).height = uint32(size(baselineCipher, 1));
            rows(writeIndex).width = uint32(size(baselineCipher, 2));
            rows(writeIndex).changedCipherBytes = uint64(nnz(difference));
            rows(writeIndex).changedCipherPixels = uint64( ...
                nnz(any(difference, 3)));
            [rows(writeIndex).meanChannelNPCR_percent, ...
                rows(writeIndex).minimumChannelNPCR_percent, ...
                rows(writeIndex).meanChannelUACI_percent, ...
                rows(writeIndex).minimumChannelUACI_percent] = ...
                rgbDifferenceMetrics(baselineCipher, changedCipher);
            rows(writeIndex).roundTripPass = isequal( ...
                changedPlain, changedRecovered);
        end
    end
end
rows = rows(1:writeIndex);
tableResult = struct2table(rows);
assert(all(tableResult.roundTripPass), ...
    'Kodak D2 candidate round trip failed.');
writetable(tableResult, fullfile(resultRoot, ...
    'D2_kodak_mult_nonce.csv'));
save(fullfile(resultRoot, 'D2_kodak_mult_nonce.mat'), ...
    'tableResult', '-v7');
summary = struct('rows', height(tableResult), ...
    'imageCount', numel(files), 'nonceCount', size(nonces, 1), ...
    'npcrByPerturbation', groupsummary(tableResult, 'perturbation', ...
    'median', 'meanChannelNPCR_percent'), ...
    'uaciByPerturbation', groupsummary(tableResult, 'perturbation', ...
    'median', 'meanChannelUACI_percent'));
end

function summary = runBurstPayloadLocality(projectRoot, resultRoot)
imageDir = resolve_kodak_root(projectRoot);
files = dir(fullfile(imageDir, '*.png'));
assert(~isempty(files), 'Kodak image corpus is not available.');
[~, order] = sort({files.name});
files = files(order);
files = files(1:min(8, numel(files)));
nonces = uint8([112:127; 144:159]);
burstHeight = 4;
burstWidth = 4;
rowCount = numel(files) * size(nonces, 1) * 4;
rows = repmat(struct('image', "", 'nonceIndex', uint8(0), ...
    'locationIndex', uint8(0), 'burstHeight', uint8(burstHeight), ...
    'burstWidth', uint8(burstWidth), 'row', uint32(0), 'column', uint32(0), ...
    'changedPixels', uint64(0), ...
    'outsideTouchedMacroblockPixels', uint64(0), ...
    'roundTripPass', false), rowCount, 1);
writeIndex = 0;
for imageIndex = 1:numel(files)
    plain = pgcinwhcl.readImageFile(fullfile(files(imageIndex).folder, ...
        files(imageIndex).name));
    heightValue = size(plain, 1);
    widthValue = size(plain, 2);
    for nonceIndex = 1:size(nonces, 1)
        cfg = pgcinwhcl.defaultConfig();
        cfg.tileSize = 16;
        cfg = pgcinwhcl.withNonce(cfg, nonces(nonceIndex, :));
        [cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
        assert(isequal(plain, pgcinwhcl.decryptImage(cipher, cfg, meta)), ...
            'Kodak D3 round trip failed for %s.', files(imageIndex).name);
        starts = burstStarts(heightValue, widthValue, 16, ...
            burstHeight, burstWidth);
        for locationIndex = 1:size(starts, 1)
            row = starts(locationIndex, 1);
            col = starts(locationIndex, 2);
            damaged = cipher;
            damaged(row:row + burstHeight - 1, ...
                col:col + burstWidth - 1, 1) = bitxor( ...
                damaged(row:row + burstHeight - 1, ...
                col:col + burstWidth - 1, 1), uint8(1));
            recovered = pgcinwhcl.decryptImage(damaged, cfg, meta);
            difference = any(recovered ~= plain, 3);
            touchedRows = floor((row - 1) / 16) * 16 + (1:16);
            touchedCols = floor((col - 1) / 16) * 16 + (1:16);
            touchedRows = touchedRows(touchedRows <= heightValue);
            touchedCols = touchedCols(touchedCols <= widthValue);
            allowed = false(heightValue, widthValue);
            allowed(touchedRows, touchedCols) = true;
            writeIndex = writeIndex + 1;
            rows(writeIndex).image = string(files(imageIndex).name);
            rows(writeIndex).nonceIndex = uint8(nonceIndex);
            rows(writeIndex).locationIndex = uint8(locationIndex);
            rows(writeIndex).row = uint32(row);
            rows(writeIndex).column = uint32(col);
            rows(writeIndex).changedPixels = uint64(nnz(difference));
            rows(writeIndex).outsideTouchedMacroblockPixels = uint64( ...
                nnz(difference & ~allowed));
            rows(writeIndex).roundTripPass = true;
        end
    end
end
rows = rows(1:writeIndex);
tableResult = struct2table(rows);
writetable(tableResult, fullfile(resultRoot, ...
    'D3_kodak_burst_payload_locality.csv'));
save(fullfile(resultRoot, 'D3_kodak_burst_payload_locality.mat'), ...
    'tableResult', '-v7');
assert(all(tableResult.outsideTouchedMacroblockPixels == 0), ...
    'Burst payload error escaped the touched macroblock.');
summary = struct('rows', height(tableResult), ...
    'outsideMax', max(tableResult.outsideTouchedMacroblockPixels), ...
    'changedPixelsMedian', median(tableResult.changedPixels));
end

function starts = burstStarts(heightValue, widthValue, tileSize, ...
        burstHeight, burstWidth)
maxRow = heightValue - burstHeight + 1;
maxCol = widthValue - burstWidth + 1;
assert(maxRow >= 1 && maxCol >= 1, 'Image is smaller than burst.');
rowCandidates = unique([1, min(tileSize - burstHeight + 1, maxRow), ...
    alignedBlockStart(floor(heightValue / 2), tileSize, maxRow), ...
    alignedBlockStart(maxRow, tileSize, maxRow)]);
colCandidates = unique([1, min(tileSize - burstWidth + 1, maxCol), ...
    alignedBlockStart(floor(widthValue / 2), tileSize, maxCol), ...
    alignedBlockStart(maxCol, tileSize, maxCol)]);
starts = [rowCandidates(1), colCandidates(1); ...
    rowCandidates(1), colCandidates(end); ...
    rowCandidates(end), colCandidates(1); ...
    rowCandidates(end), colCandidates(end)];
end

function start = alignedBlockStart(candidate, tileSize, maxStart)
start = floor(max(candidate - 1, 0) / tileSize) * tileSize + 1;
start = min(start, maxStart);
start = floor((start - 1) / tileSize) * tileSize + 1;
start = min(start, maxStart);
end

function writeSupplementManifest(results, resultRoot, experimentRoot, projectRoot)
fileId = fopen(fullfile(resultRoot, 'SUBMISSION_SUPPLEMENT_MANIFEST.txt'), 'w');
assert(fileId >= 0, 'Cannot write supplement manifest.');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'algorithm=%s\n', results.algorithm);
fprintf(fileId, 'matlabVersion=%s\n', results.matlabVersion);
fprintf(fileId, 'timestamp=%s\n', results.timestamp);
fprintf(fileId, 'script=%s\n', mfilename('fullpath'));
fprintf(fileId, 'scriptSha256=%s\n', fileSha256(fullfile(experimentRoot, ...
    'run_submission_supplement.m')));
fprintf(fileId, 'kodakDirectory=%s\n', resolve_kodak_root(projectRoot));
fprintf(fileId, 'D2Csv=D2_kodak_mult_nonce.csv\n');
fprintf(fileId, 'D3Csv=D3_kodak_burst_payload_locality.csv\n');
fprintf(fileId, 'D2Rows=%d\n', results.D2.rows);
fprintf(fileId, 'D3Rows=%d\n', results.D3.rows);
fprintf(fileId, 'D3OutsideMax=%d\n', results.D3.outsideMax);
end

function digest = fileSha256(path)
fileId = fopen(path, 'r');
assert(fileId >= 0, 'Cannot read file for SHA-256.');
cleanup = onCleanup(@() fclose(fileId));
bytes = fread(fileId, inf, '*uint8').';
digestBytes = pgcinwhcl.sha256(bytes);
digest = lower(reshape(dec2hex(digestBytes, 2).', 1, []));
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
