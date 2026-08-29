function runtimeConfig = runtimeConfigFromMetadata(cfg, meta)
%RUNTIMECONFIGFROMMETADATA Reconstruct the IV-bound runtime configuration.

metadataConfig = pgcinwhcl.resolveMetadataConfig(cfg, meta);
runtimeConfig = pgcinwhcl.applySyntheticIV(metadataConfig, meta.syntheticIV);
end
