function output = forwardStage(input, pairU, pairV, contactU, contactV, ...
    carrierU, gear, keyTable, session, stageIndex)
%FORWARDSTAGE Apply one WHCL-controlled cross-write stage.

pixelCount = size(input, 1);
tileCount = size(input, 3);
pairCount = size(pairU, 1);
[rgbKeys, keyUV, keyVU, streamU, streamV] = pgcinwhcl.deriveStageKeys( ...
    gear, contactU, contactV, carrierU, keyTable, session, stageIndex);
rawU = zeros(pairCount * tileCount, 3, 'uint8');
rawV = zeros(pairCount * tileCount, 3, 'uint8');
for channel = 1:3
    plane = reshape(input(:, channel, :), pixelCount, tileCount);
    rawU(:, channel) = plane(pairU(:));
    rawV(:, channel) = plane(pairV(:));
end
U = pgcinwhcl.rgbLiftForward(rawU, rgbKeys);
V = pgcinwhcl.rgbLiftForward(rawV, rgbKeys);
mixedU = pgcinwhcl.addMod256(U, pgcinwhcl.nonlinearF(V, keyUV), streamU);
mixedV = pgcinwhcl.addMod256(V, pgcinwhcl.nonlinearF(mixedU, keyVU), streamV);
output = zeros(size(input), 'uint8');
for channel = 1:3
    plane = zeros(pixelCount, tileCount, 'uint8');
    plane(pairV) = reshape(mixedU(:, channel), pairCount, tileCount);
    plane(pairU) = reshape(mixedV(:, channel), pairCount, tileCount);
    output(:, channel, :) = reshape(plane, pixelCount, 1, tileCount);
end
end
