function meta = encryptFile(inputPath, outputImagePath, metaPath, masterKey, nonce)
%ENCRYPTFILE Encrypt an image file and save the ciphertext plus metadata.

validateattributes(inputPath, {'char', 'string'}, {'scalartext'});
validateattributes(outputImagePath, {'char', 'string'}, {'scalartext'});
validateattributes(metaPath, {'char', 'string'}, {'scalartext'});
validateattributes(masterKey, {'uint8'}, {'vector', 'numel', 32});

image = pgcinwhcl.readImageFile(char(inputPath));
cfg = pgcinwhcl.defaultConfig();
cfg.masterKey = masterKey(:).';
if nargin >= 5 && ~isempty(nonce)
    cfg = pgcinwhcl.withNonce(cfg, nonce);
end

[cipher, meta] = pgcinwhcl.encryptImage(image, cfg);
imwrite(cipher, char(outputImagePath));
save(char(metaPath), 'meta', '-mat');
end
