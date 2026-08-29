function plain = decryptFile(cipherPath, metaPath, outputImagePath, masterKey)
%DECRYPTFILE Decrypt a ciphertext image using its metadata file.

validateattributes(cipherPath, {'char', 'string'}, {'scalartext'});
validateattributes(metaPath, {'char', 'string'}, {'scalartext'});
validateattributes(outputImagePath, {'char', 'string'}, {'scalartext'});
validateattributes(masterKey, {'uint8'}, {'vector', 'numel', 32});

[cipher, colorMap] = imread(char(cipherPath));
assert(isempty(colorMap) && isa(cipher, 'uint8') ...
    && ndims(cipher) == 3 && size(cipher, 3) == 3, ...
    'Ciphertext must be an RGB uint8 image.');
loaded = load(char(metaPath), 'meta');
assert(isfield(loaded, 'meta') && isstruct(loaded.meta), ...
    'The metadata MAT file is invalid.');

cfg = pgcinwhcl.defaultConfig();
cfg.masterKey = masterKey(:).';
cfg.tileSize = loaded.meta.tileSize;
plain = pgcinwhcl.decryptImage(cipher, cfg, loaded.meta);
imwrite(plain, char(outputImagePath));
end
