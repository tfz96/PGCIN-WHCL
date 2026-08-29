function state = evolveStates(initial, tileSize, includeDiagnostics)
%EVOLVESTATES Expand one initial state per tile along one meshing clock.

if nargin < 3
    includeDiagnostics = true;
end

tileCount = numel(initial.Zs);
increments = pgcinwhcl.baseCenters(tileSize);
stageCount = numel(increments);
statesPerTile = stageCount + 1;
pixelCount = tileSize ^ 2;
contactCount = pixelCount - 1;

omegaS = double(initial.omegaS(:)).';
omegaR = double(initial.omegaR(:)).';
omegaC = double(initial.omegaC(:)).';
clock = zeros(statesPerTile, tileCount, 'uint16');
phiS = zeros(statesPerTile, tileCount, 'uint8');
phiR = zeros(statesPerTile, tileCount, 'uint8');
phiC = zeros(statesPerTile, tileCount, 'uint8');
clock(1, :) = initial.contactClock(:).';
phiS(1, :) = initial.phiS(:).';
phiR(1, :) = initial.phiR(:).';
phiC(1, :) = initial.phiC(:).';
for stage = 1:stageCount
    tick = increments(stage);
    clock(stage + 1, :) = uint16(mod(double(clock(stage, :)) + tick, 65536));
    phiS(stage + 1, :) = uint8(mod(double(phiS(stage, :)) + tick * omegaS, 256));
    phiR(stage + 1, :) = uint8(mod(double(phiR(stage, :)) + tick * omegaR, 256));
    phiC(stage + 1, :) = uint8(mod(double(phiC(stage, :)) + tick * omegaC, 256));
end

relativeRC = double(initial.phiR(:)) - double(initial.phiC(:));
tileTweak = double(initial.tileTweak(:));
tileLow = mod(tileTweak, 256);
tileHigh = mod(floor(tileTweak / 256), 256);
tileUpper = mod(floor(tileTweak / 65536), 256);
tileTop = mod(floor(tileTweak / 16777216), 256);
unitSeed = 1 + mod(double(initial.topologyUnit(:)) - 1 ...
    + double(initial.meshDrive(:)) + relativeRC + tileLow ...
    + double(initial.Zp(:)) .* tileHigh ...
    + double(initial.Zr(:)) .* tileUpper ...
    + double(initial.Zs(:)) .* tileTop, contactCount);
units = pgcinwhcl.contactUnits(tileSize);
domainUnit = reshape(double(units(1 + mod(floor(unitSeed) - 1, ...
    numel(units)))), tileCount, 1);
topologyUnit = mod(double(initial.topologyUnit(:)) .* domainUnit, contactCount);
contactIndex = mod(double(initial.contactClock(:)), contactCount);
topologyOffset = mod(double(initial.topologyOffset(:)) + contactIndex ...
    + double(initial.Zs(:)) .* double(initial.phiC(:)) ...
    + double(initial.Zp(:)) .* double(initial.phiR(:)) ...
    + double(initial.Zs(:)) .* tileLow ...
    + double(initial.Zr(:)) .* tileHigh ...
    + double(initial.Zp(:)) .* tileUpper ...
    + double(initial.Zs(:)) .* tileTop, contactCount);
carrierWord = mod(double(initial.carrierWord(:)) ...
    + double(initial.phiC(:)) - double(initial.phiR(:)) ...
    + double(initial.Zp(:)) .* tileLow ...
    + double(initial.Zs(:)) .* tileHigh ...
    + double(initial.Zr(:)) .* tileUpper + tileTop, pixelCount);

state = struct();
state.Zs = repeatRows(initial.Zs, statesPerTile);
state.Zp = repeatRows(initial.Zp, statesPerTile);
state.Zr = repeatRows(initial.Zr, statesPerTile);
state.omegaS = repeatRows(initial.omegaS, statesPerTile);
state.omegaR = repeatRows(initial.omegaR, statesPerTile);
state.omegaC = repeatRows(initial.omegaC, statesPerTile);
state.phiS = phiS(:);
state.phiR = phiR(:);
state.phiC = phiC(:);
state.topologyUnit = repeatRows(uint16(topologyUnit), statesPerTile);
state.topologyOffset = repeatRows(uint16(topologyOffset), statesPerTile);
state.carrierWord = repeatRows(uint16(carrierWord), statesPerTile);
state.tileTweak = repeatRows(initial.tileTweak, statesPerTile);
if includeDiagnostics
    state.meshDrive = repeatRows(initial.meshDrive, statesPerTile);
    state.contactClock = clock(:);
    state.willisResidual = repeatRows(initial.willisResidual, statesPerTile);
    state.phaseWillisResidual = mod(int64(state.Zs) ...
        .* (int64(state.phiS) - int64(state.phiC)) ...
        + int64(state.Zr) .* (int64(state.phiR) - int64(state.phiC)), 256);
    state.stageIndex = repmat(uint8((0:stageCount).'), tileCount, 1);
    state.meshIncrement = repmat(uint16([0; increments]), tileCount, 1);
end
end

function values = repeatRows(initialValues, statesPerTile)
matrix = repmat(initialValues(:).', statesPerTile, 1);
values = matrix(:);
end

