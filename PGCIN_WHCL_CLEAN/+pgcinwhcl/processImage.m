function [output, stageImages, addressOutput] = ...
    processImage(input, cfg, session, encryptDirection)
%PROCESSIMAGE Apply the PGCIN-WHCL network in bounded tile batches.

tileSize = cfg.tileSize;
tileRows = size(input, 1) / tileSize;
tileCols = size(input, 2) / tileSize;
assert(tileRows == floor(tileRows) && tileCols == floor(tileCols), ...
    'Input dimensions must be divisible by tileSize.');
tileCount = tileRows * tileCols;
assert(uint64(tileCount) == session.tileCount, ...
    'Session tile count does not match the input.');
stageCount = 2 * log2(tileSize) + 1;
statesPerTile = stageCount + 1;
state = pgcinwhcl.generateStates(cfg, session, tileCount);
keyTable = pgcinwhcl.deriveRoundKeyTable(cfg, session);

current = reshape(input, tileSize, tileRows, tileSize, tileCols, 3);
current = permute(current, [1, 3, 5, 2, 4]);
current = reshape(current, tileSize ^ 2, 3, tileCount);
captureStages = nargout > 1;
captureAddress = nargout > 2;
if captureStages
    stageCurrent = cell(1, stageCount);
    for stageIndex = 1:stageCount
        stageCurrent{stageIndex} = zeros(size(current), 'uint8');
    end
end
if captureAddress
    addressCurrent = current;
end
batchSize = min(cfg.tileBatchSize, tileCount);
for firstTile = 1:batchSize:tileCount
    lastTile = min(firstTile + batchSize - 1, tileCount);
    tileRange = firstTile:lastTile;
    firstState = (firstTile - 1) * statesPerTile + 1;
    lastState = lastTile * statesPerTile;
    batchState = pgcinwhcl.selectGearState(state, firstState:lastState);
    schedule = pgcinwhcl.buildSchedule(cfg, session, ...
        numel(tileRange), batchState);
    batch = current(:, :, tileRange);
    if captureAddress
        addressBatch = batch;
    end
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
            schedule.contactV(:, :, stage), schedule.carrierU(:, :, stage), ...
            stageGear, keyTable, session, stage - 1};
        if encryptDirection
            batch = pgcinwhcl.forwardStage(batch, arguments{:});
        else
            batch = pgcinwhcl.inverseStage(batch, arguments{:});
        end
        if captureStages && encryptDirection
            stageCurrent{stage}(:, :, tileRange) = batch;
        end
        if captureAddress && encryptDirection
            addressBatch = addressOnlyStage(addressBatch, ...
                schedule.pairU(:, :, stage), schedule.pairV(:, :, stage));
        end
    end
    current(:, :, tileRange) = batch;
    if captureAddress
        addressCurrent(:, :, tileRange) = addressBatch;
    end
end

output = reshape(current, tileSize, tileSize, 3, tileRows, tileCols);
output = permute(output, [1, 4, 2, 5, 3]);
output = reshape(output, size(input));
if captureStages
    stageImages = cell(1, stageCount);
    for stageIndex = 1:stageCount
        stageImages{stageIndex} = restoreImage(stageCurrent{stageIndex}, ...
            tileSize, tileRows, tileCols);
    end
else
    stageImages = {};
end
if captureAddress
    addressOutput = restoreImage(addressCurrent, tileSize, tileRows, tileCols);
else
    addressOutput = [];
end
end

function output = addressOnlyStage(input, pairU, pairV)
output = input;
for channel = 1:3
    plane = reshape(input(:, channel, :), size(input, 1), size(input, 3));
    swapped = plane;
    swapped(pairV) = plane(pairU);
    swapped(pairU) = plane(pairV);
    output(:, channel, :) = reshape(swapped, size(input, 1), 1, size(input, 3));
end
end

function output = restoreImage(current, tileSize, tileRows, tileCols)
output = reshape(current, tileSize, tileSize, 3, tileRows, tileCols);
output = permute(output, [1, 4, 2, 5, 3]);
output = reshape(output, tileSize * tileRows, tileSize * tileCols, 3);
end
