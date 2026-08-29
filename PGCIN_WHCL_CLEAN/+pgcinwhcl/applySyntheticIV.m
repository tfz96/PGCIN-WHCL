function runtimeConfig = applySyntheticIV(cfg, syntheticIV)
%APPLYSYNTHETICIV Bind the public synthetic IV to the chaos drive.

validateattributes(syntheticIV, {'uint8'}, {'vector', 'numel', 32});
runtimeConfig = cfg;
runtimeConfig.chaosInitialState = pgcinwhcl.deriveChaosInitialState(cfg, syntheticIV);
end
