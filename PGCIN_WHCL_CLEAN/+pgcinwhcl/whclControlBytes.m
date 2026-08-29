function controls = whclControlBytes(session, tileIndex, stageIndex, ...
    basePhase, omegaC, meshDrive, contactU, contactV, carrierU)
%WHCLCONTROLBYTES Generate only the WHCL selector lanes used by the hot path.

[pairCount, tileCount] = size(contactU);
assert(isequal(size(contactV), [pairCount, tileCount]) ...
    && isequal(size(carrierU), [pairCount, tileCount]), ...
    'WHCL edge-control arrays must have identical sizes.');

tileIndex = uint64(tileIndex(:)).';
basePhase = uint64(basePhase(:)).';
omegaC = uint64(omegaC(:)).';
meshDrive = uint64(meshDrive(:)).';
assert(numel(tileIndex) == tileCount && numel(basePhase) == tileCount ...
    && numel(omegaC) == tileCount && numel(meshDrive) == tileCount, ...
    'WHCL tile controls must provide one value per tile.');
assert(isscalar(stageIndex) && stageIndex >= 0 ...
    && uint64(stageIndex) < uint64(session.stageCount), ...
    'WHCL stage index lies outside the session domain.');
assert(all(tileIndex < session.tileCount, 'all') ...
    && all(mod(meshDrive, uint64(2)) == 1, 'all'), ...
    'WHCL tile index or mesh drive is invalid.');

globalIndex = tileIndex .* uint64(session.stageCount) + uint64(stageIndex);
period = session.period;
meshClock = mod(session.origin + mod(session.stride .* globalIndex, period), ...
    period);
phaseModulus = uint64(session.phaseModulus);
Zs = uint64(session.Zs);
Zr = uint64(session.Zr);
omegaS = mod(omegaC + Zr .* meshDrive, phaseModulus);
omegaR = mod(omegaC + phaseModulus ...
    - mod(Zs .* meshDrive, phaseModulus), phaseModulus);
phiS = mod(basePhase + omegaS .* meshClock, phaseModulus);
phiR = mod(basePhase + omegaR .* meshClock, phaseModulus);
phiC = mod(basePhase + omegaC .* meshClock, phaseModulus);

sun = uint8(mod(meshClock, uint64(session.Zs)));
planet = uint8(mod(meshClock, uint64(session.Zp)));
ring = uint8(mod(meshClock, uint64(session.Zr)));
phaseClock = uint8(mod(meshClock, phaseModulus));
phiS = uint8(phiS);
phiR = uint8(phiR);
phiC = uint8(phiC);
omegaS = uint8(omegaS);
omegaR = uint8(omegaR);
omegaC = uint8(omegaC);

tileControls = cat(3, sun, planet, ring, phaseClock, phiS, phiR, phiC);
controls = zeros(pairCount, tileCount, 15, 'uint8');
controls(:, :, 1:7) = repmat(tileControls, pairCount, 1, 1);
edgeU = uint8(mod(double(contactU), 256));
edgeV = uint8(mod(double(contactV), 256));
carrier = uint8(carrierU) .* uint8(255);
controls(:, :, 8) = bitxor(controls(:, :, 1), edgeU);
controls(:, :, 9) = bitxor(controls(:, :, 2), edgeV);
controls(:, :, 10) = bitxor(controls(:, :, 3), carrier);
controls(:, :, 11) = bitxor(controls(:, :, 5), omegaS);
controls(:, :, 12) = bitxor(controls(:, :, 6), omegaR);
controls(:, :, 13) = bitxor(controls(:, :, 7), omegaC);
controls(:, :, 14) = bitxor(controls(:, :, 4), edgeU);
controls(:, :, 15) = bitxor(bitxor(controls(:, :, 1), ...
    controls(:, :, 3)), edgeV);
end
