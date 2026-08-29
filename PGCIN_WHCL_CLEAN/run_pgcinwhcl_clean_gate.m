function results = run_pgcinwhcl_clean_gate()
%RUNPGCINWHCLCLEANGATE Validate the clean PGCIN-WHCL package.

root = fileparts(mfilename('fullpath'));
addpath(root);
cfg = pgcinwhcl.defaultConfig();
fixedNonce = uint8(0:15);
cfg = pgcinwhcl.withNonce(cfg, fixedNonce);

results = struct();
results.tileRoundTrip = true;
for tileSize = [4, 8, 16, 32, 64]
    cfg.tileSize = tileSize;
    image = uint8(mod(reshape(0:(tileSize * tileSize * 3 - 1), ...
        tileSize, tileSize, 3), 256));
    [cipher, meta] = pgcinwhcl.encryptImage(image, cfg);
    recovered = pgcinwhcl.decryptImage(cipher, cfg, meta);
    assert(isequal(image, recovered), ...
        'Exact round trip failed for tile size %d.', tileSize);
end

cfg.tileSize = 16;
params = pgcinwhcl.whclParameters(16, uint64(7), uint64(1), uint64(20));
indices = uint64(0:19);
stageIndices = mod(indices, uint64(params.stageCount));
context = pgcinwhcl.whclContexts(params, indices, stageIndices, ...
    uint8(3), uint8(5), uint8(7));
decodedClock = pgcinwhcl.whclDecodeContext(params, context.sunTooth, ...
    context.planetTooth, context.ringTooth, context.phaseClock);
assert(isequal(decodedClock, context.meshClock), ...
    'WHCL CRT reconstruction failed.');
assert(all(context.velocityWillisResidual == 0, 'all') ...
    && all(context.phaseWillisResidual == 0, 'all'), ...
    'Willis residual gate failed.');
results.whcl = true;

autoCfg = pgcinwhcl.defaultConfig();
autoImage = uint8(reshape(mod(0:(16 * 16 * 3 - 1), 256), 16, 16, 3));
[autoCipher, autoMeta] = pgcinwhcl.encryptImage(autoImage, autoCfg);
assert(isequal(autoImage, pgcinwhcl.decryptImage(autoCipher, autoCfg, autoMeta)), ...
    'Automatic nonce round trip failed.');
assert(isfield(autoMeta, 'publicNonce') && numel(autoMeta.publicNonce) == 16, ...
    'Public nonce metadata is missing.');
results.autoNonce = true;

fprintf('PGCIN-WHCL clean gate passed.\\n');
end
