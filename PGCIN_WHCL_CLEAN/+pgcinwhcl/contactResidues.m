function packed = contactResidues(tileSize)
%CONTACTRESIDUES Cache packed sun, planet, and ring coordinates.

persistent cachedTileSize cachedPacked;
if isempty(cachedTileSize) || cachedTileSize ~= tileSize
    labels = (0:tileSize ^ 2 - 2).';
    sun = uint32(mod(labels, tileSize - 1));
    planet = uint32(mod(labels, tileSize + 1));
    ring = uint32(mod(labels, 3 * tileSize + 1));
    cachedPacked = sun + bitshift(planet, 8) + bitshift(ring, 16);
    cachedTileSize = tileSize;
end
packed = cachedPacked;
end

