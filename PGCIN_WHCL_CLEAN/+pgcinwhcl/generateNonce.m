function nonce = generateNonce()
%GENERATENONCE Generate a 128-bit public nonce from the JVM CSPRNG.

persistent generator
if isempty(generator)
    generator = java.security.SecureRandom();
end
nonce = reshape(typecast(generator.generateSeed(16), 'uint8'), 1, []);
end
