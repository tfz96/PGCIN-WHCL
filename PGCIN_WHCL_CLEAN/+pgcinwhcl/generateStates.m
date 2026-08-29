function [state, info] = generateStates(cfg, ~, tileCount)
%GENERATESTATES Generate the PGCIN-WHCL gear state.

coordinateBits = log2(cfg.tileSize);
stageCount = 2 * coordinateBits + 1;
statesPerTile = stageCount + 1;
assert(strcmp(cfg.chaosDriver, 'chdm4') ...
    && strcmp(cfg.chaosExtraction, 'eq15-uint32') ...
    && strcmpi(char(cfg.chaosPrecision), 'double'), ...
    'PGCIN-WHCL requires the double-precision 4D-CHDM Eq. (15) path.');
chaosStates = pgcinwhcl.chdm4States(cfg, 6 * tileCount);
words = pgcinwhcl.chdm4Eq15Words(chaosStates);
sequence = double(words) / 2 ^ 32;
initial = pgcinwhcl.projectState(reshape(sequence, 6, []).', cfg.tileSize);
initial.tileTweak = uint32((0:tileCount - 1).');
state = pgcinwhcl.evolveStates(initial, cfg.tileSize, false);

% Only these two initial controls are not already present in the evolved state.
% Keep the same tile-major row layout as the evolved state fields.
state.basePhase = repeatRows(initial.phiC, statesPerTile);
state.meshDrive = repeatRows(initial.meshDrive, statesPerTile);

info = struct('mode', 'continuousGear', 'chaosValueCount', 6 * tileCount, ...
    'chaosValuesPerTile', 6, 'statesPerTile', statesPerTile, ...
    'tileCount', tileCount, 'stageCount', stageCount);
end

function values = repeatRows(initialValues, statesPerTile)
matrix = repmat(initialValues(:).', statesPerTile, 1);
values = matrix(:);
end
