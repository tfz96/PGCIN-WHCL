function params = whclParameters(tileSize, origin, stride, tileCount)
%WHCLPARAMETERS Validate and construct a supported WHCL session domain.

if nargin < 2
    origin = uint64(0);
end
if nargin < 3
    stride = uint64(1);
end
if nargin < 4
    tileCount = uint64(0);
end

validateattributes(tileSize, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'integer', '>=', 4, '<=', 64});
coordinateBits = log2(double(tileSize));
if coordinateBits ~= floor(coordinateBits)
    error('pgcinwhcl:UnsupportedTileSize', ...
        'tileSize must be a power of two in the supported range 4:64.');
end
validateattributes(origin, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'integer', 'nonnegative'});
validateattributes(stride, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'integer', 'nonnegative'});
validateattributes(tileCount, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'integer', 'nonnegative'});

Zs = uint64(tileSize - 1);
Zp = uint64(tileSize + 1);
Zr = uint64(3 * tileSize + 1);
phaseModulus = uint64(256);
period = phaseModulus * Zs * Zp * Zr;
stageCount = uint64(2 * coordinateBits + 1);
origin = mod(uint64(origin), period);
stride = mod(uint64(stride), period);
tileCount = uint64(tileCount);

if gcd(stride, period) ~= 1
    error('pgcinwhcl:NonUnitStride', ...
        'WHCL stride must be a unit modulo the context period.');
end
if period > uint64(intmax('uint32'))
    error('pgcinwhcl:UnsupportedPeriod', ...
        'Supported WHCL periods must fit uint32 for safe uint64 products.');
end

maxTileCount = idivide(period, stageCount, 'floor');
if tileCount > maxTileCount
    error('pgcinwhcl:SessionCapacityExceeded', ...
        'tileCount*stageCount exceeds the no-repeat WHCL session capacity.');
end

params = struct();
params.tileSize = uint16(tileSize);
params.coordinateBits = uint8(coordinateBits);
params.stageCount = uint8(stageCount);
params.Zs = uint16(Zs);
params.Zp = uint16(Zp);
params.Zr = uint16(Zr);
params.phaseModulus = uint16(phaseModulus);
params.period = period;
params.origin = origin;
params.stride = stride;
params.tileCount = tileCount;
params.maxTileCount = maxTileCount;
end
