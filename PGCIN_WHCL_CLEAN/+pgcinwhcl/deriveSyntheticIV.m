function syntheticIV = deriveSyntheticIV(plain, cfg)
%DERIVESYNTHETICIV Bind plaintext, geometry, and public nonce to the session.

spec = pgcinwhcl.algorithmSpec();
validateattributes(plain, {'uint8'}, {'nonempty'});
validateattributes(cfg.masterKey, {'uint8'}, {'vector', 'numel', 32});
validateattributes(cfg.nonce, {'uint8'}, {'vector', 'numel', 16});
algorithm = uint8(spec.algorithm);
tileSizeBytes = encodeUint32(uint32(cfg.tileSize));
sizeBytes = encodeUint32(uint32(size(plain)));
message = [spec.sivDomain(:); uint8(0); algorithm(:); uint8(0); ...
    spec.roundDomain(:); uint8(0); cfg.nonce(:); ...
    tileSizeBytes; sizeBytes; plain(:)];
syntheticIV = pgcinwhcl.hmacSha256(cfg.masterKey, message);
end

function bytes = encodeUint32(values)
values = uint32(values(:).');
bytes = reshape([uint8(bitshift(values, -24)); ...
    uint8(bitand(bitshift(values, -16), 255)); ...
    uint8(bitand(bitshift(values, -8), 255)); ...
    uint8(bitand(values, 255))], [], 1);
end
