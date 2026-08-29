function results = run_feedback_tradeoff_control()
%RUN_FEEDBACK_TRADEOFF_CONTROL Compare matched payload-dependency wrappers.

experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = fileparts(experimentRoot);
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(cleanRoot);

tileSize = 16;
tileRows = 4;
tileColumns = 4;
plain = makeTestImage(tileRows * tileSize, ...
    tileColumns * tileSize, 8601);
cfg = pgcinwhcl.defaultConfig();
cfg.tileSize = tileSize;
cfg = pgcinwhcl.withNonce(cfg, uint8(192:207));
[coreCipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
assert(isequal(plain, pgcinwhcl.decryptImage(coreCipher, cfg, meta)), ...
    'Production baseline round trip failed.');

runtimeConfig = pgcinwhcl.applySyntheticIV(cfg, meta.syntheticIV);
tileCount = tileRows * tileColumns;
session = pgcinwhcl.deriveSession(runtimeConfig, ...
    meta.syntheticIV, tileCount);

orderTable = runOrderIndependence(plain, coreCipher, ...
    runtimeConfig, session, tileSize);
[tradeoffTable, damageTable] = runFeedbackTradeoff(plain, coreCipher, ...
    runtimeConfig, session, tileSize);
[timingTable, timingTrials] = runPairedWrapperTiming(tileSize);

writetable(orderTable, fullfile(resultRoot, ...
    'C1_payload_order_independence.csv'));
writetable(tradeoffTable, fullfile(resultRoot, ...
    'C2_payload_dependency_control.csv'));
writetable(damageTable, fullfile(resultRoot, ...
    'C3_payload_error_support.csv'));
writetable(timingTrials, fullfile(resultRoot, ...
    'C4_feedback_paired_timing_trials.csv'));
writetable(timingTable, fullfile(resultRoot, ...
    'C5_feedback_paired_timing_summary.csv'));

results = struct();
results.algorithm = 'PGCIN-WHCL';
results.controlType = 'analysis-only matched XOR wrappers';
results.matlabVersion = version;
results.timestamp = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
results.orderIndependence = orderTable;
results.feedbackTradeoff = tradeoffTable;
results.damageSupport = damageTable;
results.timingTrials = timingTrials;
results.timing = timingTable;
save(fullfile(resultRoot, 'feedback_tradeoff_control.mat'), ...
    'results', '-v7');
fprintf('PGCIN-WHCL feedback trade-off control completed.\n');
end

function tableResult = runOrderIndependence(plain, coreCipher, ...
        cfg, session, tileSize)
tileCount = double(session.tileCount);
forwardOrder = 1:tileCount;
reverseOrder = tileCount:-1:1;
scrambledOrder = mod((0:tileCount - 1) * 5, tileCount) + 1;
names = ["forward"; "reverse"; "scrambled"];
orders = {forwardOrder, reverseOrder, scrambledOrder};
encryptExact = false(3, 1);
decryptExact = false(3, 1);
for orderIndex = 1:numel(orders)
    candidateCipher = processInTileOrder(plain, cfg, session, ...
        true, orders{orderIndex});
    encryptExact(orderIndex) = isequal(candidateCipher, coreCipher);
    recovered = processInTileOrder(coreCipher, cfg, session, ...
        false, orders{orderIndex});
    decryptExact(orderIndex) = isequal(recovered, plain);
end
tableResult = table(names, repmat(tileSize, 3, 1), ...
    repmat(tileCount, 3, 1), encryptExact, decryptExact, ...
    'VariableNames', {'tileOrder', 'tileSize', 'tileCount', ...
    'cipherMatchesProduction', 'exactRoundTrip'});
assert(all(encryptExact) && all(decryptExact), ...
    'Changing the macroblock processing order changed the core result.');
end

function [tableResult, damageTable] = runFeedbackTradeoff(plain, coreCipher, ...
        cfg, session, tileSize)
coreTiles = imageToTiles(coreCipher, tileSize);
tileCount = size(coreTiles, 3);
masks = indexedMasks(size(coreTiles));
reverseOrder = tileCount:-1:1;

indexedCipher = indexedWrap(coreTiles, masks);
indexedReverse = indexedWrapInOrder(coreTiles, masks, reverseOrder);
feedbackCipher = feedbackWrap(coreTiles, masks(:, :, 1));
[feedbackReverse, feedbackReverseCompleted] = feedbackWrapInOrder( ...
    coreTiles, masks(:, :, 1), reverseOrder);
assert(isequal(indexedCipher, indexedReverse), ...
    'Index-only wrapper changed under reverse processing order.');

indexedCore = indexedUnwrap(indexedCipher, masks);
feedbackCore = feedbackUnwrap(feedbackCipher, masks(:, :, 1));
indexedRecovered = pgcinwhcl.processImage(tilesToImage( ...
    indexedCore, size(coreCipher), tileSize), cfg, session, false);
feedbackRecovered = pgcinwhcl.processImage(tilesToImage( ...
    feedbackCore, size(coreCipher), tileSize), cfg, session, false);

selectedTile = min(floor(tileCount / 2) + 2, tileCount);
indexedSelectedExact = isequal(bitxor(indexedCipher(:, :, selectedTile), ...
    masks(:, :, selectedTile)), coreTiles(:, :, selectedTile));
feedbackSelectedExact = isequal(bitxor( ...
    feedbackCipher(:, :, selectedTile), ...
    feedbackCipher(:, :, selectedTile - 1)), ...
    coreTiles(:, :, selectedTile));

controller = ["index-only"; "ciphertext-feedback"];
controllerTileCount = repmat(tileCount, 2, 1);
definedXorPerPayloadByte = ones(2, 1);
definedPredecessorPayloadReads = [0; tileCount - 1];
definedMaximumTransitiveCoreTileSupport = [1; tileCount];
definedSelectedCoreTileCiphertextsRequired = [1; 2];
measuredReverseOnePassCompleted = [true; feedbackReverseCompleted];
measuredReverseOnePassMatchesForward = [isequal(indexedReverse, indexedCipher); ...
    isequal(feedbackReverse, feedbackCipher)];
measuredExactRoundTrip = [isequal(indexedRecovered, plain); ...
    isequal(feedbackRecovered, plain)];
measuredSelectedCoreTileUnwrapExact = [indexedSelectedExact; ...
    feedbackSelectedExact];
tableResult = table(controller, controllerTileCount, ...
    definedXorPerPayloadByte, definedPredecessorPayloadReads, ...
    definedMaximumTransitiveCoreTileSupport, ...
    definedSelectedCoreTileCiphertextsRequired, ...
    measuredReverseOnePassCompleted, ...
    measuredReverseOnePassMatchesForward, measuredExactRoundTrip, ...
    measuredSelectedCoreTileUnwrapExact);

assert(all(measuredExactRoundTrip) ...
    && all(measuredSelectedCoreTileUnwrapExact), ...
    'A matched wrapper failed exact recovery.');
assert(measuredReverseOnePassCompleted(1) ...
    && ~measuredReverseOnePassCompleted(2) ...
    && measuredReverseOnePassMatchesForward(1) ...
    && ~measuredReverseOnePassMatchesForward(2), ...
    'The expected processing-order distinction was not reproduced.');

tileRows = size(coreCipher, 1) / tileSize;
interiorTile = 2 * tileRows - 1;
errorTiles = [interiorTile, tileCount];
scenarioNames = ["interior-with-successor", "terminal"];
damageRows = repmat(struct(), 2 * numel(errorTiles), 1);
writeIndex = 0;
for scenarioIndex = 1:numel(errorTiles)
    errorTile = errorTiles(scenarioIndex);
    for feedbackMode = [false, true]
        if feedbackMode
            controllerName = "ciphertext-feedback";
            damaged = feedbackCipher;
        else
            controllerName = "index-only";
            damaged = indexedCipher;
        end
        damaged(7, 2, errorTile) = bitxor( ...
            damaged(7, 2, errorTile), uint8(1));
        damage = damageMetrics(damaged, masks, feedbackMode, plain, ...
            coreCipher, cfg, session, tileSize, errorTile);
        writeIndex = writeIndex + 1;
        [tileRow, tileColumn] = tileGridPosition(errorTile, tileRows);
        damageRows(writeIndex).controller = controllerName;
        damageRows(writeIndex).scenario = scenarioNames(scenarioIndex);
        damageRows(writeIndex).damagedCipherTile = errorTile;
        damageRows(writeIndex).damagedTileRow = tileRow;
        damageRows(writeIndex).damagedTileColumn = tileColumn;
        damageRows(writeIndex).sequenceSuccessorTile = ...
            min(errorTile + 1, tileCount) * (errorTile < tileCount);
        damageRows(writeIndex).decryptCompleted = true;
        damageRows(writeIndex).exactRecovery = damage.exactRecovery;
        damageRows(writeIndex).affectedMacroblockCount = ...
            damage.affectedMacroblockCount;
        damageRows(writeIndex).affectedMacroblockIndices = ...
            damage.affectedMacroblockIndices;
        damageRows(writeIndex).changedPixels = damage.changedPixels;
        damageRows(writeIndex).outsideExpectedPixels = ...
            damage.outsideExpectedPixels;
    end
end
damageTable = struct2table(damageRows(1:writeIndex));
assert(isequal(damageTable.affectedMacroblockCount, [1; 2; 1; 1]) ...
    && isequal(damageTable.changedPixels, [256; 512; 256; 256]) ...
    && all(damageTable.outsideExpectedPixels == 0) ...
    && ~any(damageTable.exactRecovery), ...
    'The expected feedback/locality trade-off was not reproduced.');
end

function metrics = damageMetrics(damaged, masks, feedbackMode, ...
        plain, coreCipher, cfg, session, tileSize, errorTile)
if feedbackMode
    damagedCoreTiles = feedbackUnwrap(damaged, masks(:, :, 1));
    allowedTiles = errorTile:min(errorTile + 1, size(damaged, 3));
else
    damagedCoreTiles = indexedUnwrap(damaged, masks);
    allowedTiles = errorTile;
end
damagedCore = tilesToImage(damagedCoreTiles, size(coreCipher), tileSize);
recovered = pgcinwhcl.processImage(damagedCore, cfg, session, false);
difference = any(recovered ~= plain, 3);
allowed = tileMask(size(difference), tileSize, allowedTiles);
[affectedCount, affectedIndices] = countAffectedTiles(difference, tileSize);
metrics = struct('changedPixels', nnz(difference), ...
    'affectedMacroblockCount', affectedCount, ...
    'affectedMacroblockIndices', join(string(affectedIndices), ';'), ...
    'exactRecovery', isequal(recovered, plain), ...
    'outsideExpectedPixels', nnz(difference & ~allowed));
end

function [tableResult, trialTable] = runPairedWrapperTiming(tileSize)
tileCounts = [16, 64, 256, 1024];
campaignCount = 2;
replicateCount = 3;
trialCount = 10;
warmupCount = 2;
targetBytes = 8 * 2 ^ 20;
rows = repmat(struct(), ...
    numel(tileCounts) * campaignCount * replicateCount, 1);
trialRows = repmat(struct(), ...
    numel(tileCounts) * campaignCount * replicateCount * trialCount, 1);
writeIndex = 0;
trialWriteIndex = 0;
for campaignIndex = 1:campaignCount
    for caseIndex = 1:numel(tileCounts)
        tileCount = tileCounts(caseIndex);
        for replicateIndex = 1:replicateCount
        seed = 9000 + 1000 * campaignIndex + 100 * caseIndex ...
            + replicateIndex;
        input = syntheticTiles(tileSize, tileCount, seed);
        masks = indexedMasks(size(input));
        repeatCount = max(1, ceil(targetBytes / numel(input)));
        for warmupIndex = 1:warmupCount
            repeatIndexed(input, masks, repeatCount);
            repeatFeedback(input, masks(:, :, 1), repeatCount);
        end
        indexedMs = zeros(trialCount, 1);
        feedbackMs = zeros(trialCount, 1);
        executionOrder = strings(trialCount, 1);
        for trialIndex = 1:trialCount
            if mod(trialIndex, 2) == 1
                executionOrder(trialIndex) = "indexed-first";
                indexedMs(trialIndex) = measureRepeated( ...
                    @() repeatIndexed(input, masks, repeatCount), ...
                    repeatCount);
                feedbackMs(trialIndex) = measureRepeated( ...
                    @() repeatFeedback(input, masks(:, :, 1), ...
                    repeatCount), repeatCount);
            else
                executionOrder(trialIndex) = "feedback-first";
                feedbackMs(trialIndex) = measureRepeated( ...
                    @() repeatFeedback(input, masks(:, :, 1), ...
                    repeatCount), repeatCount);
                indexedMs(trialIndex) = measureRepeated( ...
                    @() repeatIndexed(input, masks, repeatCount), ...
                    repeatCount);
            end
            trialWriteIndex = trialWriteIndex + 1;
            trialRows(trialWriteIndex).tileSize = tileSize;
            trialRows(trialWriteIndex).tileCount = tileCount;
            trialRows(trialWriteIndex).campaignIndex = campaignIndex;
            trialRows(trialWriteIndex).replicateIndex = replicateIndex;
            trialRows(trialWriteIndex).seed = seed;
            trialRows(trialWriteIndex).bytesPerInvocation = numel(input);
            trialRows(trialWriteIndex).timedTotalBytes = ...
                numel(input) * repeatCount;
            trialRows(trialWriteIndex).repeatCount = repeatCount;
            trialRows(trialWriteIndex).trialIndex = trialIndex;
            trialRows(trialWriteIndex).executionOrder = ...
                executionOrder(trialIndex);
            trialRows(trialWriteIndex).indexedMs = indexedMs(trialIndex);
            trialRows(trialWriteIndex).feedbackMs = feedbackMs(trialIndex);
            trialRows(trialWriteIndex).pairedDeltaMs = ...
                feedbackMs(trialIndex) - indexedMs(trialIndex);
            trialRows(trialWriteIndex).pairedRatio = ...
                feedbackMs(trialIndex) / indexedMs(trialIndex);
        end
        writeIndex = writeIndex + 1;
        rows(writeIndex).tileSize = tileSize;
        rows(writeIndex).tileCount = tileCount;
        rows(writeIndex).campaignIndex = campaignIndex;
        rows(writeIndex).replicateIndex = replicateIndex;
        rows(writeIndex).seed = seed;
        rows(writeIndex).xorPerPayloadByte = 1;
        rows(writeIndex).bytesPerInvocation = numel(input);
        rows(writeIndex).timedTotalBytes = numel(input) * repeatCount;
        rows(writeIndex).repeatCount = repeatCount;
        rows(writeIndex).trialCount = trialCount;
        rows(writeIndex).warmupCount = warmupCount;
        rows(writeIndex).indexedMedianMs = median(indexedMs);
        rows(writeIndex).indexedIQRMs = iqr(indexedMs);
        rows(writeIndex).feedbackMedianMs = median(feedbackMs);
        rows(writeIndex).feedbackIQRMs = iqr(feedbackMs);
        rows(writeIndex).medianPairedDeltaMs = ...
            median(feedbackMs - indexedMs);
        rows(writeIndex).medianPairedRatio = ...
            median(feedbackMs ./ indexedMs);
        rows(writeIndex).feedbackSlowerTrialCount = ...
            nnz(feedbackMs > indexedMs);
        rows(writeIndex).feedbackFasterTrialCount = ...
            nnz(feedbackMs < indexedMs);
        end
    end
end
tableResult = struct2table(rows(1:writeIndex));
trialTable = struct2table(trialRows(1:trialWriteIndex));
assert(height(tableResult) == numel(tileCounts) * campaignCount ...
    * replicateCount ...
    && all(tableResult.trialCount == trialCount) ...
    && all(tableResult.warmupCount == warmupCount) ...
    && all(tableResult.indexedMedianMs > 0) ...
    && all(tableResult.feedbackMedianMs > 0) ...
    && height(trialTable) == numel(tileCounts) * campaignCount ...
    * replicateCount * trialCount ...
    && all(isfinite(trialTable.pairedRatio)) ...
    && all(trialTable.executionOrder(1:2:end) == "indexed-first") ...
    && all(trialTable.executionOrder(2:2:end) == "feedback-first"), ...
    'Feedback wrapper timing campaign is incomplete.');
end

function elapsedMs = measureRepeated(operation, repeatCount)
timer = tic;
operation();
elapsedMs = 1000 * toc(timer) / repeatCount;
end

function output = repeatIndexed(input, masks, repeatCount)
output = input;
for repeatIndex = 1:repeatCount
    output = indexedWrapLoop(input, masks);
end
end

function output = repeatFeedback(input, firstMask, repeatCount)
output = input;
for repeatIndex = 1:repeatCount
    output = feedbackWrap(input, firstMask);
end
end

function output = indexedWrap(input, masks)
output = bitxor(input, masks);
end

function output = indexedWrapInOrder(input, masks, order)
output = zeros(size(input), 'uint8');
for orderIndex = 1:numel(order)
    tileIndex = order(orderIndex);
    output(:, :, tileIndex) = bitxor( ...
        input(:, :, tileIndex), masks(:, :, tileIndex));
end
end

function output = indexedWrapLoop(input, masks)
output = zeros(size(input), 'uint8');
for tileIndex = 1:size(input, 3)
    output(:, :, tileIndex) = bitxor( ...
        input(:, :, tileIndex), masks(:, :, tileIndex));
end
end

function output = indexedUnwrap(input, masks)
output = bitxor(input, masks);
end

function output = feedbackWrap(input, firstMask)
output = zeros(size(input), 'uint8');
output(:, :, 1) = bitxor(input(:, :, 1), firstMask);
for tileIndex = 2:size(input, 3)
    output(:, :, tileIndex) = bitxor( ...
        input(:, :, tileIndex), output(:, :, tileIndex - 1));
end
end

function [output, completed] = feedbackWrapInOrder(input, firstMask, order)
output = zeros(size(input), 'uint8');
available = false(1, size(input, 3));
for orderIndex = 1:numel(order)
    tileIndex = order(orderIndex);
    if tileIndex == 1
        output(:, :, tileIndex) = bitxor(input(:, :, tileIndex), firstMask);
        available(tileIndex) = true;
    elseif available(tileIndex - 1)
        output(:, :, tileIndex) = bitxor(input(:, :, tileIndex), ...
            output(:, :, tileIndex - 1));
        available(tileIndex) = true;
    end
end
completed = all(available);
end

function output = feedbackUnwrap(input, firstMask)
output = zeros(size(input), 'uint8');
output(:, :, 1) = bitxor(input(:, :, 1), firstMask);
output(:, :, 2:end) = bitxor(input(:, :, 2:end), ...
    input(:, :, 1:end - 1));
end

function masks = indexedMasks(arraySize)
pixelIndex = reshape(uint32(0:arraySize(1) - 1), [], 1, 1);
channelIndex = reshape(uint32(0:arraySize(2) - 1), 1, [], 1);
tileIndex = reshape(uint32(0:arraySize(3) - 1), 1, 1, []);
masks = uint8(mod(73 * pixelIndex + 109 * channelIndex ...
    + 151 * tileIndex + 29, 256));
end

function tiles = syntheticTiles(tileSize, tileCount, seed)
value = reshape(uint32(0:tileSize ^ 2 * 3 * tileCount - 1), ...
    tileSize ^ 2, 3, tileCount);
tiles = uint8(mod(37 * value + uint32(seed), 256));
end

function output = processInTileOrder(input, cfg, session, ...
        encryptDirection, order)
tileSize = cfg.tileSize;
tileRows = size(input, 1) / tileSize;
tileColumns = size(input, 2) / tileSize;
tileCount = tileRows * tileColumns;
assert(numel(order) == tileCount ...
    && isequal(sort(order), 1:tileCount), ...
    'Tile order must be a permutation of all macroblock indices.');
stageCount = 2 * log2(tileSize) + 1;
statesPerTile = stageCount + 1;
state = pgcinwhcl.generateStates(cfg, session, tileCount);
keyTable = pgcinwhcl.deriveRoundKeyTable(cfg, session);
current = imageToTiles(input, tileSize);
for orderIndex = 1:numel(order)
    tileIndex = order(orderIndex);
    stateRange = (tileIndex - 1) * statesPerTile + (1:statesPerTile);
    tileState = pgcinwhcl.selectGearState(state, stateRange);
    schedule = pgcinwhcl.buildSchedule(cfg, session, 1, tileState);
    tile = current(:, :, tileIndex);
    if encryptDirection
        stageRange = 1:stageCount;
    else
        stageRange = stageCount:-1:1;
    end
    for stage = stageRange
        stageGear = pgcinwhcl.selectGearState(schedule.state, ...
            schedule.stageIndices(:, stage));
        arguments = {schedule.pairU(:, :, stage), ...
            schedule.pairV(:, :, stage), schedule.contactU(:, :, stage), ...
            schedule.contactV(:, :, stage), ...
            schedule.carrierU(:, :, stage), stageGear, keyTable, ...
            session, stage - 1};
        if encryptDirection
            tile = pgcinwhcl.forwardStage(tile, arguments{:});
        else
            tile = pgcinwhcl.inverseStage(tile, arguments{:});
        end
    end
    current(:, :, tileIndex) = tile;
end
output = tilesToImage(current, size(input), tileSize);
end

function tiles = imageToTiles(input, tileSize)
tileRows = size(input, 1) / tileSize;
tileColumns = size(input, 2) / tileSize;
tiles = reshape(input, tileSize, tileRows, ...
    tileSize, tileColumns, 3);
tiles = permute(tiles, [1, 3, 5, 2, 4]);
tiles = reshape(tiles, tileSize ^ 2, 3, tileRows * tileColumns);
end

function output = tilesToImage(tiles, imageSize, tileSize)
tileRows = imageSize(1) / tileSize;
tileColumns = imageSize(2) / tileSize;
channelCount = size(tiles, 2);
output = reshape(tiles, tileSize, tileSize, channelCount, ...
    tileRows, tileColumns);
output = permute(output, [1, 4, 2, 5, 3]);
output = reshape(output, imageSize(1), imageSize(2), channelCount);
end

function mask = tileMask(imageSize, tileSize, tileIndices)
tileRows = imageSize(1) / tileSize;
tileColumns = imageSize(2) / tileSize;
maskTiles = false(tileSize ^ 2, 1, tileRows * tileColumns);
maskTiles(:, 1, tileIndices) = true;
mask = tilesToImage(maskTiles, [imageSize, 1], tileSize);
mask = logical(mask(:, :, 1));
end

function [count, indices] = countAffectedTiles(mask, tileSize)
tileRows = size(mask, 1) / tileSize;
tileColumns = size(mask, 2) / tileSize;
tiles = reshape(mask, tileSize, tileRows, ...
    tileSize, tileColumns);
tiles = permute(tiles, [1, 3, 2, 4]);
tiles = reshape(tiles, tileSize ^ 2, tileRows * tileColumns);
indices = find(any(tiles, 1));
count = numel(indices);
end

function [tileRow, tileColumn] = tileGridPosition(tileIndex, tileRows)
tileRow = mod(tileIndex - 1, tileRows) + 1;
tileColumn = floor((tileIndex - 1) / tileRows) + 1;
end

function image = makeTestImage(heightValue, widthValue, seed)
[column, row] = meshgrid(0:widthValue - 1, 0:heightValue - 1);
red = mod(17 * row + 31 * column + seed, 256);
green = mod(13 * row + 47 * column + 3 * seed, 256);
blue = mod(29 * row + 19 * column + 5 * seed, 256);
image = uint8(cat(3, red, green, blue));
end
