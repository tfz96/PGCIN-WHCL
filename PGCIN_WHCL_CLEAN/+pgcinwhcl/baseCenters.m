function centers = baseCenters(tileSize)
%BASECENTERS Return the certified contact-center and clock increments.

coordinateBits = log2(tileSize);
assert(coordinateBits == floor(coordinateBits), ...
    'tileSize must be a power of two.');
contactCount = tileSize ^ 2 - 1;
centers = zeros(2 * coordinateBits + 1, 1);
for stage = 1:2 * coordinateBits
    centers(stage) = mod(2 ^ (stage - 1), contactCount);
end
centers(end) = 1;
end

