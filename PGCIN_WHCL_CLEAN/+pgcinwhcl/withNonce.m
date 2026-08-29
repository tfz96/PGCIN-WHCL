function cfg = withNonce(cfg, nonce)
%WITHNONCE Select an explicit nonce for reproducible encryption.

validateattributes(nonce, {'uint8'}, {'vector', 'numel', 16});
cfg.nonce = nonce(:).';
cfg.autoNonce = false;
end
