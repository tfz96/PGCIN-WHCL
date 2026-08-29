function digest = sha256(bytes)
%SHA256 Return a SHA-256 digest as a row vector of uint8 values.

validateattributes(bytes, {'uint8'}, {'vector'});
messageDigest = javaMethod('getInstance', 'java.security.MessageDigest', ...
    'SHA-256');
rawDigest = messageDigest.digest(typecast(bytes(:), 'int8'));
digest = reshape(typecast(rawDigest, 'uint8'), 1, []);
end
