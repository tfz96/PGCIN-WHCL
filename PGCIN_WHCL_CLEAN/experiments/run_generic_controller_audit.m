function results = run_generic_controller_audit(nonceBytes, imageSeed, outputTag)
%RUNGNERICCONTROLLERAUDIT Compare the gear controller with a shadow generic one.

if nargin < 1 || isempty(nonceBytes)
    nonceBytes = uint8(144:159);
end
if nargin < 2 || isempty(imageSeed)
    imageSeed = 1901;
end
if nargin < 3
    outputTag = '';
end

experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = fileparts(experimentRoot);
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(cleanRoot);

tileSize = 16;
tileRows = 2;
tileCols = 2;
tileCount = tileRows * tileCols;
plain = makeTestImage(tileRows * tileSize, tileCols * tileSize, imageSeed);
cfg = pgcinwhcl.defaultConfig();
cfg.tileSize = tileSize;
cfg = pgcinwhcl.withNonce(cfg, nonceBytes);
syntheticIV = pgcinwhcl.deriveSyntheticIV(plain, cfg);
runtimeConfig = pgcinwhcl.applySyntheticIV(cfg, syntheticIV);
session = pgcinwhcl.deriveSession(runtimeConfig, syntheticIV, tileCount);
state = pgcinwhcl.generateStates(runtimeConfig, session, tileCount);
schedule = pgcinwhcl.buildSchedule(runtimeConfig, session, tileCount, state);
keyTable = pgcinwhcl.deriveRoundKeyTable(runtimeConfig, session);

baselineCipher = pgcinwhcl.processImage(plain, runtimeConfig, session, true);
genericCipher = shadowProcess(plain, cfg, session, schedule, keyTable, true);
genericRecovered = shadowProcess(genericCipher, cfg, session, schedule, ...
    keyTable, false);
baselineRecovered = pgcinwhcl.processImage(baselineCipher, runtimeConfig, ...
    session, false);

results = struct();
results.algorithm = 'PGCIN-WHCL';
results.tileSize = tileSize;
results.tileCount = tileCount;
results.imageSeed = imageSeed;
results.nonceHex = lower(reshape(dec2hex(nonceBytes, 2).', 1, []));
results.baselineRoundTrip = isequal(plain, baselineRecovered);
results.genericRoundTrip = isequal(plain, genericRecovered);
results.baselineSupportRate = finalSupportRate(schedule, tileSize);
results.genericSupportRate = results.baselineSupportRate;
results.baselineCipherDigest = hexDigest(baselineCipher(:));
results.genericCipherDigest = hexDigest(genericCipher(:));
results.cipherDifferencePercent = byteDifferencePercent( ...
    baselineCipher, genericCipher);
results.scheduleDigest = hexDigest(uint8([ ...
    typecast(schedule.pairU(:), 'uint8'); typecast(schedule.pairV(:), 'uint8')]));
results.controlDigest = genericControlDigest(session, schedule, keyTable);
results.matchingValid = matchingValid(schedule, tileSize);

assert(results.baselineRoundTrip && results.genericRoundTrip, ...
    'Generic controller shadow round trip failed.');
assert(results.matchingValid && results.baselineSupportRate == 1, ...
    'Generic controller shadow structural baseline failed.');

if isempty(outputTag)
    outputStem = 'G_generic_controller_audit';
else
    outputStem = ['G_generic_controller_audit_' outputTag];
end
save(fullfile(resultRoot, [outputStem '.mat']), 'results', ...
    'baselineCipher', 'genericCipher', 'plain', '-v7');
writeSummary(results, resultRoot, outputStem);
fprintf('PGCIN-WHCL generic controller audit completed.\n');
end

function output = shadowProcess(input, cfg, session, schedule, keyTable, encryptDirection)
tileSize = cfg.tileSize;
tileRows = size(input, 1) / tileSize;
tileCols = size(input, 2) / tileSize;
tileCount = tileRows * tileCols;
stageCount = schedule.stageCount;
current = reshape(input, tileSize, tileRows, tileSize, tileCols, 3);
current = permute(current, [1, 3, 5, 2, 4]);
current = reshape(current, tileSize ^ 2, 3, tileCount);
if encryptDirection
    stageRange = 1:stageCount;
else
    stageRange = stageCount:-1:1;
end
for stage = stageRange
    controls = genericStageKeys(session, schedule, keyTable, stage - 1);
    arguments = {schedule.pairU(:, :, stage), schedule.pairV(:, :, stage), ...
        controls.rgbKeys, controls.keyUV, controls.keyVU, ...
        controls.streamU, controls.streamV};
    if encryptDirection
        current = shadowForwardStage(current, arguments{:});
    else
        current = shadowInverseStage(current, arguments{:});
    end
end
output = reshape(current, tileSize, tileSize, 3, tileRows, tileCols);
output = permute(output, [1, 4, 2, 5, 3]);
output = reshape(output, size(input));
end

function controls = genericStageKeys(session, schedule, keyTable, stageIndex)
contactU = schedule.contactU(:, :, stageIndex + 1);
contactV = schedule.contactV(:, :, stageIndex + 1);
carrierU = schedule.carrierU(:, :, stageIndex + 1);
[pairCount, tileCount] = size(contactU);
pairIndex = reshape(uint32(0:pairCount - 1), pairCount, 1);
tileIndex = reshape(uint32(0:tileCount - 1), 1, tileCount);
seed = pgcinwhcl.sha256([session.sessionDigest(:); ...
    uint8('generic-controller-v1').']);
base = zeros(pairCount, tileCount, 15, 'uint8');
for lane = 1:15
    value = double(seed(lane)) ...
        + 3 * double(contactU) + 5 * double(contactV) ...
        + 7 * double(carrierU) ...
        + 11 * double(stageIndex) ...
        + 13 * double(tileIndex) ...
        + 17 * double(pairIndex) ...
        + 19 * lane;
    base(:, :, lane) = uint8(mod(value, 256));
end
masks = pgcinwhcl.keyedByteMasksFast(keyTable, base);
combined = bitxor(base, masks);
controls.rgbKeys = reshape(combined(:, :, 1:3), [], 3);
controls.keyUV = reshape(combined(:, :, 4:6), [], 3);
controls.keyVU = reshape(combined(:, :, 7:9), [], 3);
controls.streamU = reshape(combined(:, :, 10:12), [], 3);
controls.streamV = reshape(combined(:, :, 13:15), [], 3);
end

function output = shadowForwardStage(input, pairU, pairV, rgbKeys, ...
        keyUV, keyVU, streamU, streamV)
pixelCount = size(input, 1);
tileCount = size(input, 3);
pairCount = size(pairU, 1);
rawU = zeros(pairCount * tileCount, 3, 'uint8');
rawV = zeros(pairCount * tileCount, 3, 'uint8');
for channel = 1:3
    plane = reshape(input(:, channel, :), pixelCount, tileCount);
    rawU(:, channel) = plane(pairU(:));
    rawV(:, channel) = plane(pairV(:));
end
U = pgcinwhcl.rgbLiftForward(rawU, rgbKeys);
V = pgcinwhcl.rgbLiftForward(rawV, rgbKeys);
mixedU = pgcinwhcl.addMod256(U, pgcinwhcl.nonlinearF(V, keyUV), streamU);
mixedV = pgcinwhcl.addMod256(V, pgcinwhcl.nonlinearF(mixedU, keyVU), streamV);
output = zeros(size(input), 'uint8');
for channel = 1:3
    plane = zeros(pixelCount, tileCount, 'uint8');
    plane(pairV) = reshape(mixedU(:, channel), pairCount, tileCount);
    plane(pairU) = reshape(mixedV(:, channel), pairCount, tileCount);
    output(:, channel, :) = reshape(plane, pixelCount, 1, tileCount);
end
end

function output = shadowInverseStage(input, pairU, pairV, rgbKeys, ...
        keyUV, keyVU, streamU, streamV)
pixelCount = size(input, 1);
tileCount = size(input, 3);
pairCount = size(pairU, 1);
mixedU = zeros(pairCount * tileCount, 3, 'uint8');
mixedV = zeros(pairCount * tileCount, 3, 'uint8');
for channel = 1:3
    plane = reshape(input(:, channel, :), pixelCount, tileCount);
    mixedU(:, channel) = plane(pairV(:));
    mixedV(:, channel) = plane(pairU(:));
end
V = pgcinwhcl.subtractMod256(mixedV, ...
    pgcinwhcl.nonlinearF(mixedU, keyVU), streamV);
U = pgcinwhcl.subtractMod256(mixedU, ...
    pgcinwhcl.nonlinearF(V, keyUV), streamU);
rawU = pgcinwhcl.rgbLiftInverse(U, rgbKeys);
rawV = pgcinwhcl.rgbLiftInverse(V, rgbKeys);
output = zeros(size(input), 'uint8');
for channel = 1:3
    plane = zeros(pixelCount, tileCount, 'uint8');
    plane(pairU) = reshape(rawU(:, channel), pairCount, tileCount);
    plane(pairV) = reshape(rawV(:, channel), pairCount, tileCount);
    output(:, channel, :) = reshape(plane, pixelCount, 1, tileCount);
end
end

function digest = genericControlDigest(session, schedule, keyTable)
bytes = zeros(0, 1, 'uint8');
for stage = 0:schedule.stageCount - 1
    controls = genericStageKeys(session, schedule, keyTable, stage);
    bytes = [bytes; controls.rgbKeys(:); controls.keyUV(:); ...
        controls.keyVU(:); controls.streamU(:); controls.streamV(:)]; %#ok<AGROW>
end
digest = hexDigest(bytes);
end

function valid = matchingValid(schedule, tileSize)
pixelCount = tileSize ^ 2;
valid = true;
for stage = 1:schedule.stageCount
    vertices = [schedule.pairU(:, :, stage); schedule.pairV(:, :, stage)];
    for tile = 1:size(vertices, 2)
        offset = uint32((tile - 1) * pixelCount);
        local = vertices(:, tile) - offset;
        valid = valid && numel(unique(local)) == pixelCount ...
            && all(local >= 1 & local <= pixelCount);
    end
end
end

function rate = finalSupportRate(schedule, tileSize)
pixelCount = tileSize ^ 2;
tileCount = size(schedule.stageIndices, 1);
support = false(pixelCount, pixelCount, tileCount);
for tile = 1:tileCount
    support(:, :, tile) = eye(pixelCount) > 0;
end
for stage = 1:schedule.stageCount
    for tile = 1:tileCount
        offset = (tile - 1) * pixelCount;
        pairU = double(schedule.pairU(:, tile, stage)) - offset;
        pairV = double(schedule.pairV(:, tile, stage)) - offset;
        unionRows = support(pairU, :, tile) | support(pairV, :, tile);
        nextSupport = false(pixelCount, pixelCount);
        nextSupport(pairU, :) = unionRows;
        nextSupport(pairV, :) = unionRows;
        support(:, :, tile) = nextSupport;
    end
end
supportSize = sum(support, 2);
rate = mean(supportSize(:) == pixelCount);
end

function percent = byteDifferencePercent(reference, candidate)
percent = 100 * nnz(reference ~= candidate) / numel(reference);
end

function digest = hexDigest(bytes)
digest = lower(reshape(dec2hex(pgcinwhcl.sha256(bytes), 2).', 1, []));
end

function image = makeTestImage(height, width, seed)
[column, row] = meshgrid(0:width - 1, 0:height - 1);
red = mod(17 * row + 31 * column + seed, 256);
green = mod(13 * row + 47 * column + 3 * seed, 256);
blue = mod(29 * row + 19 * column + 5 * seed, 256);
image = uint8(cat(3, red, green, blue));
end

function writeSummary(results, resultRoot, outputStem)
fileId = fopen(fullfile(resultRoot, [outputStem '.txt']), 'w');
assert(fileId >= 0, 'Cannot write generic audit summary.');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'algorithm=%s\n', results.algorithm);
fprintf(fileId, 'tileSize=%d\n', results.tileSize);
fprintf(fileId, 'tileCount=%d\n', results.tileCount);
fprintf(fileId, 'imageSeed=%d\n', results.imageSeed);
fprintf(fileId, 'nonceHex=%s\n', results.nonceHex);
fprintf(fileId, 'baselineRoundTrip=%d\n', results.baselineRoundTrip);
fprintf(fileId, 'genericRoundTrip=%d\n', results.genericRoundTrip);
fprintf(fileId, 'matchingValid=%d\n', results.matchingValid);
fprintf(fileId, 'baselineSupportRate=%.12g\n', results.baselineSupportRate);
fprintf(fileId, 'genericSupportRate=%.12g\n', results.genericSupportRate);
fprintf(fileId, 'cipherDifferencePercent=%.12g\n', ...
    results.cipherDifferencePercent);
fprintf(fileId, 'scheduleDigest=%s\n', results.scheduleDigest);
fprintf(fileId, 'controlDigest=%s\n', results.controlDigest);
end
