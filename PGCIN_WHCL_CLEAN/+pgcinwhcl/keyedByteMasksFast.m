function masks = keyedByteMasksFast(keyTable, selectors)
%KEYEDBYTEMASKSFAST Apply trusted selector lanes without repeated validation.

persistent laneOffset
if isempty(laneOffset)
    laneOffset = reshape(uint16(0:256:256 * 14), 1, 1, 15);
end
indices = uint16(selectors) + laneOffset + uint16(1);
masks = reshape(keyTable(indices), size(selectors));
end
