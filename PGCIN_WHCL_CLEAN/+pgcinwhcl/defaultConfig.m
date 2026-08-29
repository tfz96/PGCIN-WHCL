function cfg = defaultConfig()
%DEFAULTCONFIG Return the single PGCIN-WHCL configuration.

cfg = struct();
cfg.tileSize = 16;
cfg.chaosDriver = 'chdm4';
cfg.chaosPrecision = 'double';
cfg.chaosExtraction = 'eq15-uint32';
cfg.burnIn = 1000;
cfg.tileBatchSize = 2048;
cfg.masterKey = uint8([41 117 203 8 94 231 16 155 ...
    72 186 35 249 121 4 213 88 169 52 240 109 ...
    11 196 67 224 143 30 178 81 250 99 14 205]);
spec = pgcinwhcl.algorithmSpec();
cfg.algorithm = spec.algorithm;
cfg.controlLayer = 'willis-hunting-joint-control-lattice';
cfg.roundDomain = spec.roundDomain;
cfg.sessionDomain = spec.sessionDomain;
cfg.nonce = spec.defaultNonce;
cfg.autoNonce = true;
end
