function cfg = resolveMetadataConfig(cfg, meta)
%RESOLVEMETADATACONFIG Reconstruct the algorithm and nonce from metadata.

spec = pgcinwhcl.algorithmSpec();
assert(strcmp(meta.algorithm, spec.algorithm), ...
    'PGCIN-WHCL metadata algorithm identity is invalid.');
cfgAlgorithm = cfg.algorithm;
cfg.algorithm = spec.algorithm;
cfg.roundDomain = spec.roundDomain;
cfg.sessionDomain = spec.sessionDomain;
assert(isfield(meta, 'publicNonce'), ...
    'PGCIN-WHCL public nonce metadata is missing.');
validateattributes(meta.publicNonce, {'uint8'}, {'vector', 'numel', 16});
if strcmp(cfgAlgorithm, spec.algorithm) && isfield(cfg, 'autoNonce') ...
        && ~cfg.autoNonce
    validateattributes(cfg.nonce, {'uint8'}, {'vector', 'numel', 16});
    assert(isequal(cfg.nonce(:).', meta.publicNonce(:).'), ...
        'PGCIN-WHCL public nonce metadata does not match the configuration.');
end
cfg.nonce = meta.publicNonce(:).';
cfg.autoNonce = false;
end
