function session = deriveSession(cfg, syntheticIV, tileCount)
%DERIVESESSION Derive a capacity-checked WHCL session.

validateattributes(syntheticIV, {'uint8'}, {'vector', 'numel', 32});
validateattributes(tileCount, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'integer', 'nonnegative'});
validateattributes(cfg.masterKey, {'uint8'}, {'vector', 'numel', 32});
spec = pgcinwhcl.algorithmSpec();
assert(strcmp(cfg.algorithm, spec.algorithm), ...
    'PGCIN-WHCL algorithm identity is inconsistent.');
assert(isequal(uint8(cfg.roundDomain(:)).', spec.roundDomain), ...
    'PGCIN-WHCL round domain does not match the algorithm version.');
assert(isequal(uint8(cfg.sessionDomain(:)).', spec.sessionDomain), ...
    'PGCIN-WHCL session domain does not match the algorithm version.');

contextDomain = uint8(cfg.sessionDomain(:));
message = [contextDomain; uint8(cfg.tileSize); syntheticIV(:)];
digest = pgcinwhcl.hmacSha256(cfg.masterKey, message);
period = uint64(256 * (cfg.tileSize - 1) * (cfg.tileSize + 1) ...
    * (3 * cfg.tileSize + 1));
origin = uint64(typecast(uint8(digest(1:8)), 'uint64'));
rawStride = uint64(typecast(uint8(digest(9:16)), 'uint64'));
stride = mod(rawStride, period);
if gcd(stride, period) ~= 1
    stride = stride + 1;
    while gcd(stride, period) ~= 1
        stride = mod(stride + 1, period);
    end
end

params = pgcinwhcl.whclParameters(cfg.tileSize, origin, stride, ...
    uint64(tileCount));
session = params;
session.syntheticIV = syntheticIV(:).';
session.sessionDigest = digest;
session.algorithm = spec.algorithm;
session.contextDomain = contextDomain(:).';
session.roundDomain = spec.roundDomain;
end
