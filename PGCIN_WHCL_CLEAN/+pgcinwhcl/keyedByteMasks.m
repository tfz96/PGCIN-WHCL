function masks = keyedByteMasks(keyTable, selectors)
%KEYEDBYTEMASKS Expand a 256-bit session key through structural selectors.

validateattributes(keyTable, {'uint8'}, {'size', [256, 15]});
validateattributes(selectors, {'uint8'}, {'3d'});
[pairCount, tileCount, laneCount] = size(selectors);
assert(laneCount == size(keyTable, 2), 'Selector lane count is inconsistent.');

laneOffset = reshape(0:256:256 * (laneCount - 1), 1, 1, laneCount);
indices = double(selectors) + laneOffset + 1;
masks = reshape(keyTable(indices), pairCount, tileCount, laneCount);
end
