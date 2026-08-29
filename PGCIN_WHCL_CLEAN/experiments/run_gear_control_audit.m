function results = run_gear_control_audit()
%RUNGEARCONTROLAUDIT Trace gear/WHCL causal participation in a shadow path.

experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = fileparts(experimentRoot);
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(cleanRoot);

tileSize = 16;
tileRows = 2;
tileCols = 2;
plain = makeTestImage(tileRows * tileSize, tileCols * tileSize, 902);
cfg = pgcinwhcl.defaultConfig();
cfg.tileSize = tileSize;
cfg = pgcinwhcl.withNonce(cfg, uint8(0:15));
[runtimeConfig, session, baselineState] = prepareRuntime(cfg, plain, tileRows * tileCols);
keyTable = pgcinwhcl.deriveRoundKeyTable(runtimeConfig, session);
baselineSchedule = pgcinwhcl.buildSchedule(runtimeConfig, session, ...
    tileRows * tileCols, baselineState);

variantNames = {'baseline', 'header-frozen', 'gear-phase-frozen', ...
    'whcl-input-frozen'};
variantCount = numel(variantNames);
rows = repmat(struct(), variantCount, 1);
baselineCipher = [];
for index = 1:variantCount
    variantName = variantNames{index};
    variantState = mutateState(baselineState, variantName, baselineSchedule);
    variantSchedule = pgcinwhcl.buildSchedule(runtimeConfig, session, ...
        tileRows * tileCols, variantState);
    cipher = processWithState(plain, runtimeConfig, session, variantState, true);
    recovered = processWithState(cipher, runtimeConfig, session, variantState, false);
    keyDigest = stageKeyDigest(variantState, variantSchedule, keyTable, session);
    scheduleChanged = ~isequal(baselineSchedule.pairU, variantSchedule.pairU) ...
        || ~isequal(baselineSchedule.pairV, variantSchedule.pairV) ...
        || ~isequal(baselineSchedule.contactU, variantSchedule.contactU) ...
        || ~isequal(baselineSchedule.contactV, variantSchedule.contactV);
    if index == 1
        baselineCipher = cipher;
    end
    rows(index).variant = variantName;
    rows(index).scheduleChanged = scheduleChanged;
    rows(index).stageKeyDigest = keyDigest;
    rows(index).cipherChangedPercent = byteDifferencePercent(baselineCipher, cipher);
    rows(index).exactRoundTrip = isequal(plain, recovered);
    rows(index).matchingValid = matchingValid(variantSchedule, tileSize);
    rows(index).fullSupportRate = finalSupportRate(variantSchedule, tileSize);
end

results = struct();
results.algorithm = 'PGCIN-WHCL';
results.tileSize = tileSize;
results.tileCount = tileRows * tileCols;
results.variants = rows;
results.stateLineage = traceStateLineage(baselineState, baselineSchedule, ...
    keyTable, session);

tableResult = struct2table(rows);
writetable(tableResult, fullfile(resultRoot, 'G_gear_control_audit.csv'));
save(fullfile(resultRoot, 'G_gear_control_audit.mat'), 'results', ...
    'tableResult', '-v7');
writeSummary(results, resultRoot);
fprintf('PGCIN-WHCL gear control audit completed.\n');
end

function [runtimeConfig, session, state] = prepareRuntime(cfg, plain, tileCount)
syntheticIV = pgcinwhcl.deriveSyntheticIV(plain, cfg);
runtimeConfig = pgcinwhcl.applySyntheticIV(cfg, syntheticIV);
session = pgcinwhcl.deriveSession(runtimeConfig, syntheticIV, tileCount);
state = pgcinwhcl.generateStates(runtimeConfig, session, tileCount);
end

function state = mutateState(state, variantName, schedule)
statesPerTile = double(schedule.stageCount) + 1;
tileCount = size(schedule.stageIndices, 1);
switch variantName
    case 'baseline'
        return
    case 'header-frozen'
        headerRows = 1:statesPerTile:size(state.Zs, 1);
        sourceRow = headerRows(1);
        for row = headerRows(2:end)
            state.topologyUnit(row, :) = state.topologyUnit(sourceRow, :);
            state.topologyOffset(row, :) = state.topologyOffset(sourceRow, :);
            state.carrierWord(row, :) = state.carrierWord(sourceRow, :);
        end
    case 'gear-phase-frozen'
        state.omegaS(:) = uint8(0);
        state.omegaR(:) = uint8(0);
        state.omegaC(:) = uint8(0);
        state.phiS(:) = uint8(0);
        state.phiR(:) = uint8(0);
        state.phiC(:) = uint8(0);
        state.basePhase(:) = uint8(0);
        state.meshDrive(:) = uint8(1);
    case 'whcl-input-frozen'
        state.basePhase(:) = uint8(0);
        state.meshDrive(:) = uint8(1);
        state.omegaC(:) = uint8(0);
    otherwise
        error('Unknown gear audit variant: %s', variantName);
end
assert(size(state.Zs, 1) == tileCount * statesPerTile, ...
    'Gear audit state size is inconsistent.');
end

function output = processWithState(input, cfg, session, state, encryptDirection)
tileSize = cfg.tileSize;
tileRows = size(input, 1) / tileSize;
tileCols = size(input, 2) / tileSize;
tileCount = tileRows * tileCols;
stageCount = 2 * log2(tileSize) + 1;
assert(size(input, 3) == 3 && tileRows == floor(tileRows) ...
    && tileCols == floor(tileCols), 'Shadow input dimensions are invalid.');
assert(uint64(tileCount) == session.tileCount, ...
    'Shadow session tile count mismatch.');
current = reshape(input, tileSize, tileRows, tileSize, tileCols, 3);
current = permute(current, [1, 3, 5, 2, 4]);
current = reshape(current, tileSize ^ 2, 3, tileCount);
keyTable = pgcinwhcl.deriveRoundKeyTable(cfg, session);
schedule = pgcinwhcl.buildSchedule(cfg, session, tileCount, state);
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
        current = pgcinwhcl.forwardStage(current, arguments{:});
    else
        current = pgcinwhcl.inverseStage(current, arguments{:});
    end
end
output = reshape(current, tileSize, tileSize, 3, tileRows, tileCols);
output = permute(output, [1, 4, 2, 5, 3]);
output = reshape(output, size(input));
end

function digest = stageKeyDigest(state, schedule, keyTable, session)
bytes = zeros(0, 1, 'uint8');
for stage = 1:schedule.stageCount
    stageGear = pgcinwhcl.selectGearState(schedule.state, ...
        schedule.stageIndices(:, stage));
    [rgbKeys, keyUV, keyVU, streamU, streamV] = pgcinwhcl.deriveStageKeys( ...
        stageGear, schedule.contactU(:, :, stage), ...
        schedule.contactV(:, :, stage), schedule.carrierU(:, :, stage), ...
        keyTable, session, stage - 1);
    bytes = [bytes; rgbKeys(:); keyUV(:); keyVU(:); streamU(:); streamV(:)]; %#ok<AGROW>
end
digest = hexDigest(bytes);
assert(~isempty(state), 'State must not be empty.');
end

function trace = traceStateLineage(state, schedule, keyTable, session)
stage = 1;
stageGear = pgcinwhcl.selectGearState(schedule.state, ...
    schedule.stageIndices(:, stage));
[rgbKeys, keyUV, keyVU, streamU, streamV] = pgcinwhcl.deriveStageKeys( ...
    stageGear, schedule.contactU(:, :, stage), ...
    schedule.contactV(:, :, stage), schedule.carrierU(:, :, stage), ...
    keyTable, session, stage - 1);
trace = struct();
trace.topologyHeaderDigest = hexDigest(uint8([ ...
    typecast(schedule.pairU(:), 'uint8'); typecast(schedule.pairV(:), 'uint8')]));
trace.contactDigest = hexDigest(uint8([ ...
    typecast(schedule.contactU(:), 'uint8'); typecast(schedule.contactV(:), 'uint8')]));
trace.gearPhaseDigest = hexDigest(uint8([stageGear.phiS(:); ...
    stageGear.phiR(:); stageGear.phiC(:); stageGear.omegaS(:); ...
    stageGear.omegaR(:); stageGear.omegaC(:)]));
trace.fiveControlDigest = hexDigest(uint8([rgbKeys(:); keyUV(:); ...
    keyVU(:); streamU(:); streamV(:)]));
trace.stageCount = schedule.stageCount;
trace.tileCount = size(schedule.stageIndices, 1);
trace.stateRows = size(state.Zs, 1);
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

function writeSummary(results, resultRoot)
fileId = fopen(fullfile(resultRoot, 'G_gear_control_audit.txt'), 'w');
assert(fileId >= 0, 'Cannot write gear audit summary.');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'algorithm=%s\n', results.algorithm);
fprintf(fileId, 'tileSize=%d\n', results.tileSize);
fprintf(fileId, 'tileCount=%d\n', results.tileCount);
for index = 1:numel(results.variants)
    item = results.variants(index);
    fprintf(fileId, 'variant=%s scheduleChanged=%d cipherChangedPercent=%.12g ', ...
        item.variant, item.scheduleChanged, item.cipherChangedPercent);
    fprintf(fileId, 'exactRoundTrip=%d matchingValid=%d fullSupportRate=%.12g\n', ...
        item.exactRoundTrip, item.matchingValid, item.fullSupportRate);
end
end
