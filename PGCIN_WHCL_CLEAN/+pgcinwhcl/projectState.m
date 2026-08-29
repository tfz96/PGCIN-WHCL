function state = projectState(values, tileSize)
%PROJECTSTATE Project chaotic values onto the planetary-gear state.

validateattributes(values, {'double'}, {'2d', 'ncols', 6, '>=', 0, '<', 1});
coordinateBits = log2(tileSize);
assert(coordinateBits == floor(coordinateBits), ...
    'tileSize must be a power of two.');
rowCount = size(values, 1);
pixelCount = tileSize ^ 2;
contactCount = pixelCount - 1;

Zs = uint16(tileSize - 1);
Zp = uint16(tileSize + 1);
Zr = uint16(3 * tileSize + 1);
units = pgcinwhcl.contactUnits(tileSize);
unitIndex = 1 + floor(values(:, 1) * numel(units));
selectedUnit = reshape(units(unitIndex), rowCount, 1);

topologyOffset = floor(values(:, 2) * contactCount);
carrierWord = floor(values(:, 3) * pixelCount);
drive = int64(1 + 2 * floor(values(:, 3) * 128));
omegaC64 = int64(floor(values(:, 4) * 256));
contactClock = int64(floor(values(:, 5) * 65536));
basePhase = int64(floor(values(:, 6) * 256));
omegaS64 = mod(omegaC64 + int64(Zr) .* drive, 256);
omegaR64 = mod(omegaC64 - int64(Zs) .* drive, 256);
phiS64 = mod(basePhase + omegaS64 .* contactClock, 256);
phiR64 = mod(basePhase + omegaR64 .* contactClock, 256);
phiC64 = mod(basePhase + omegaC64 .* contactClock, 256);
willisResidual = mod(int64(Zs) .* (omegaS64 - omegaC64) ...
    + int64(Zr) .* (omegaR64 - omegaC64), 256);
phaseWillisResidual = mod(int64(Zs) .* (phiS64 - phiC64) ...
    + int64(Zr) .* (phiR64 - phiC64), 256);

state = struct();
state.Zs = repmat(Zs, rowCount, 1);
state.Zp = repmat(Zp, rowCount, 1);
state.Zr = repmat(Zr, rowCount, 1);
state.meshDrive = uint8(drive);
state.omegaS = uint8(omegaS64);
state.omegaR = uint8(omegaR64);
state.omegaC = uint8(omegaC64);
state.phiS = uint8(phiS64);
state.phiR = uint8(phiR64);
state.phiC = uint8(phiC64);
state.contactClock = uint16(contactClock);
state.topologyUnit = uint16(selectedUnit);
state.topologyOffset = uint16(topologyOffset);
state.carrierWord = uint16(carrierWord);
state.willisResidual = willisResidual;
state.phaseWillisResidual = phaseWillisResidual;
end
