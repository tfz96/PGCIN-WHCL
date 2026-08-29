function digest = hmacSha256(key, message)
%HMACSHA256 Compute an HMAC-SHA-256 byte vector with the Java runtime.

validateattributes(key, {'uint8'}, {'vector', 'nonempty'});
validateattributes(message, {'uint8'}, {'vector'});
mac = javaMethod('getInstance', 'javax.crypto.Mac', 'HmacSHA256');
keySpec = javaObject('javax.crypto.spec.SecretKeySpec', ...
    typecast(key(:), 'int8'), 'HmacSHA256');
mac.init(keySpec);
rawDigest = mac.doFinal(typecast(message(:), 'int8'));
digest = reshape(typecast(rawDigest, 'uint8'), 1, []);
end
