function initialState = deriveChaosInitialState(cfg, syntheticIV)
%DERIVECHAOSINITIALSTATE Derive four CHDM states from the full session input.

validateattributes(cfg.masterKey, {'uint8'}, {'vector', 'numel', 32});
validateattributes(syntheticIV, {'uint8'}, {'vector', 'numel', 32});

domain = uint8('pgcinwhcl-chdm4-state-v1');
nonceBytes = canonicalNonceBytes(cfg.nonce);
modulus = [1, 2, 3, 4];
initialState = zeros(1, 4);
for stateIndex = 1:4
    message = [domain(:); uint8(0); uint8(stateIndex); ...
        nonceBytes(:); syntheticIV(:)];
    digest = pgcinwhcl.hmacSha256(cfg.masterKey, message);
    initialState(stateIndex) = digestToOpenUnit(digest) * modulus(stateIndex);
end
end

function bytes = canonicalNonceBytes(value)
if isa(value, 'double')
    validateattributes(value, {'double'}, {'scalar', 'finite'});
    word = typecast(value, 'uint64');
    hexWord = dec2hex(word, 16);
    bytes = uint8(sscanf(hexWord, '%2x').');
    return
end
validateattributes(value, {'uint8'}, {'vector', 'numel', 16});
bytes = value(:).';
end

function value = digestToOpenUnit(digest)
mantissa = 0;
for byteIndex = 1:6
    mantissa = mantissa * 256 + double(digest(byteIndex));
end
mantissa = mantissa * 32 + floor(double(digest(7)) / 8);
value = (mantissa + 1) / (2 ^ 53 + 2);
end
