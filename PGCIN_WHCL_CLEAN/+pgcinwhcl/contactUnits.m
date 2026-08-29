function units = contactUnits(tileSize)
%CONTACTUNITS Return the multiplicative units of the contact ring.

persistent cachedTileSize cachedUnits;
if isempty(cachedTileSize) || cachedTileSize ~= tileSize
    contactCount = tileSize ^ 2 - 1;
    unitValues = 1:contactCount - 1;
    cachedUnits = uint16(unitValues(gcd(unitValues, contactCount) == 1));
    cachedTileSize = tileSize;
end
units = cachedUnits;
end
