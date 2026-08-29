function [rgbKeys, keyUV, keyVU, streamU, streamV] = deriveStageKeys( ...
    gear, contactU, contactV, carrierU, keyTable, session, stageIndex)
%DERIVESTAGEKEYS Combine gear-contact and WHCL stage controls.

pairCount = size(contactU, 1);
tileSize = double(gear.Zp(1)) - 1;
event = (0:pairCount - 1).';
residues = pgcinwhcl.contactResidues(tileSize);
packedU = reshape(residues(double(contactU) + 1), size(contactU));
packedV = reshape(residues(double(contactV) + 1), size(contactV));
sunU = uint8(packedU);
sunV = uint8(packedV);
planetU = uint8(bitshift(packedU, -8));
planetV = uint8(bitshift(packedV, -8));
ringU = uint8(bitshift(packedU, -16));
ringV = uint8(bitshift(packedV, -16));

tileValue = double(gear.tileTweak(:)).';
tileLow = uint8(mod(tileValue, 256));
tileHigh = uint8(mod(floor(tileValue / 256), 256));
tileUpper = uint8(mod(floor(tileValue / 65536), 256));
tileTop = uint8(mod(floor(tileValue / 16777216), 256));
phaseS = bitxor(uint8(mod(double(gear.phiS(:)).' ...
    + event * double(gear.omegaS(:)).', 256)), bitxor(tileLow, tileTop));
phaseR = bitxor(uint8(mod(double(gear.phiR(:)).' ...
    + event * double(gear.omegaR(:)).', 256)), bitxor(tileHigh, tileUpper));
phaseC = bitxor(uint8(mod(double(gear.phiC(:)).' ...
    + event * double(gear.omegaC(:)).', 256)), ...
    bitxor(bitxor(tileLow, tileHigh), bitxor(tileUpper, tileTop)));
carrierMask = uint8(carrierU) .* uint8(255);

rgbS = bitxor(phaseS, bitxor(sunU, sunV));
rgbR = bitxor(phaseR, bitxor(ringU, ringV));
rgbC = bitxor(phaseC, bitxor(bitxor(planetU, planetV), carrierMask));
omegaS = gear.omegaS(:).';
omegaR = gear.omegaR(:).';
omegaC = gear.omegaC(:).';
baseControls = cat(3, rgbS, rgbR, rgbC, ...
    bitxor(bitxor(omegaS, sunV), phaseC), ...
    bitxor(bitxor(omegaR, ringV), phaseS), ...
    bitxor(bitxor(omegaC, planetV), phaseR), ...
    bitxor(bitxor(omegaR, ringU), phaseC), ...
    bitxor(bitxor(omegaC, planetU), phaseR), ...
    bitxor(bitxor(omegaS, sunU), phaseS), ...
    bitxor(rgbS, planetV), bitxor(rgbR, sunU), ...
    bitxor(rgbC, ringV), bitxor(rgbC, sunV), ...
    bitxor(rgbS, ringU), bitxor(rgbR, planetU));
baseMasks = lookupMasks(keyTable, baseControls);

tileIndex = uint64(double(gear.tileTweak(:)).');
basePhase = uint8(gear.basePhase(:)).';
whclOmegaC = uint8(gear.omegaC(:)).';
meshDrive = uint8(gear.meshDrive(:)).';
whclControls = pgcinwhcl.whclControlBytes(session, tileIndex, stageIndex, ...
    basePhase, whclOmegaC, meshDrive, contactU, contactV, carrierU);
whclMasks = lookupMasks(keyTable, whclControls);
controls = bitxor(bitxor(baseControls, baseMasks), whclMasks);
rgbKeys = reshape(controls(:, :, 1:3), [], 3);
keyUV = reshape(controls(:, :, 4:6), [], 3);
keyVU = reshape(controls(:, :, 7:9), [], 3);
streamU = reshape(controls(:, :, 10:12), [], 3);
streamV = reshape(controls(:, :, 13:15), [], 3);
end

function masks = lookupMasks(keyTable, controls)
if numel(controls) < 1024
    masks = pgcinwhcl.keyedByteMasks(keyTable, controls);
else
    masks = pgcinwhcl.keyedByteMasksFast(keyTable, controls);
end
end
