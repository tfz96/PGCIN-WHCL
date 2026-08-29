function schedule = buildSchedule(cfg, ~, tileCount, state)
%BUILDSCHEDULE Build certified matchings with fixed per-tile gear headers.

tileSize = cfg.tileSize;
stageCount = 2 * log2(tileSize) + 1;
pixelCount = tileSize ^ 2;
contactCount = pixelCount - 1;
pairCount = pixelCount / 2;
statesPerTile = stageCount + 1;
headerIndices = 1:statesPerTile:size(state.Zs, 1);
header = pgcinwhcl.selectGearState(state, headerIndices);
stageIndices = zeros(tileCount, stageCount);
for stage = 1:stageCount
    stageIndices(:, stage) = headerIndices(:) + stage;
end
baseCenter = pgcinwhcl.baseCenters(tileSize);
[tableWordsU, tableWordsV, tableContactsU, tableContactsV] = ...
    pgcinwhcl.contactMatchingTable(tileSize);
pairU = zeros(pairCount, tileCount, stageCount, 'uint32');
pairV = zeros(pairCount, tileCount, stageCount, 'uint32');
contactU = zeros(pairCount, tileCount, stageCount, 'uint16');
contactV = zeros(pairCount, tileCount, stageCount, 'uint16');
carrierU = false(pairCount, tileCount, stageCount);
centers = zeros(stageCount, tileCount, 'uint16');
tileOffsets = uint32((0:tileCount - 1) * pixelCount);
unit = double(header.topologyUnit(:)).';
offset = double(header.topologyOffset(:)).';
carrier = uint16(header.carrierWord(:)).';
% The fixed header preserves the common-conjugacy coverage certificate.
for stage = 1:stageCount
    center = mod(unit * baseCenter(stage) + 2 * offset, contactCount);
    centers(stage, :) = uint16(center);
    selection = center + 1;
    pairU(:, :, stage) = uint32(bitxor(tableWordsU(:, selection), carrier) + 1) ...
        + tileOffsets;
    pairV(:, :, stage) = uint32(bitxor(tableWordsV(:, selection), carrier) + 1) ...
        + tileOffsets;
    contactU(:, :, stage) = tableContactsU(:, selection);
    contactV(:, :, stage) = tableContactsV(:, selection);
    carrierU(1, :, stage) = true;
end
schedule = struct('stageCount', stageCount, 'pairCount', pairCount, ...
    'state', state, 'stageIndices', stageIndices, 'centers', centers, ...
    'pairU', pairU, 'pairV', pairV, ...
    'contactU', contactU, 'contactV', contactV, 'carrierU', carrierU);
end
