function keyTable = deriveRoundKeyTable(cfg, session)
%DERIVEROUNDKEYTABLE Derive the keyed 15-lane selector table.

spec = pgcinwhcl.algorithmSpec();
assert(strcmp(cfg.algorithm, spec.algorithm) ...
    && strcmp(session.algorithm, spec.algorithm) ...
    && isequal(uint8(session.roundDomain(:)).', spec.roundDomain), ...
    'PGCIN-WHCL key-table context is inconsistent.');
validateattributes(session.sessionDigest, {'uint8'}, {'vector', 'numel', 32});
material = pgcinwhcl.hmacSha256(cfg.masterKey, ...
    [uint8(session.roundDomain(:)); session.syntheticIV(:); ...
    session.sessionDigest(:)]);
selector = uint8((0:255).');
lane = uint8(0:14);
inputOffset = uint8(mod(double(material(1)) + 17 * double(lane), 256));
outputMask = material(2:16);
box = pgcinwhcl.aesSbox();
indices = double(bitxor(selector, inputOffset)) + 1;
keyTable = bitxor(box(indices), outputMask);
end
