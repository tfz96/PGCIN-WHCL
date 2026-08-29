function [cfg, publicNonce, nonceSource] = resolveEncryptionConfig(cfg)
%RESOLVEENCRYPTIONCONFIG Resolve the public 128-bit nonce for encryption.

spec = pgcinwhcl.algorithmSpec();
assert(strcmp(cfg.algorithm, spec.algorithm) ...
    && isequal(uint8(cfg.roundDomain(:)).', spec.roundDomain) ...
    && isequal(uint8(cfg.sessionDomain(:)).', spec.sessionDomain), ...
    'PGCIN-WHCL configuration identity is inconsistent.');
validateattributes(cfg.autoNonce, {'logical'}, {'scalar'});
validateattributes(cfg.nonce, {'uint8'}, {'vector', 'numel', 16});
if cfg.autoNonce
    publicNonce = pgcinwhcl.generateNonce();
    nonceSource = 'secure-random-128';
else
    publicNonce = cfg.nonce(:).';
    nonceSource = 'caller-fixed-128';
end
cfg.nonce = publicNonce;
end
