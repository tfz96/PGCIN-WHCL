function output = inverseStage(input, pairU, pairV, contactU, contactV, ...
    carrierU, gear, keyTable, session, stageIndex)
%INVERSESTAGE Invert one WHCL-controlled cross-write stage.

pixelCount = size(input, 1);
tileCount = size(input, 3);
pairCount = size(pairU, 1);
[rgbKeys, keyUV, keyVU, streamU, streamV] = pgcinwhcl.deriveStageKeys( ...
    gear, contactU, contactV, carrierU, keyTable, session, stageIndex);
mixedU = zeros(pairCount * tileCount, 3, 'uint8');
mixedV = zeros(pairCount * tileCount, 3, 'uint8');
for channel = 1:3
    plane = reshape(input(:, channel, :), pixelCount, tileCount);
    mixedU(:, channel) = plane(pairV(:));
    mixedV(:, channel) = plane(pairU(:));
end
V = pgcinwhcl.subtractMod256(mixedV, pgcinwhcl.nonlinearF(mixedU, keyVU), streamV);
U = pgcinwhcl.subtractMod256(mixedU, pgcinwhcl.nonlinearF(V, keyUV), streamU);
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
