function results = run_final_structural_baseline()
%RUNFINALSTRUCTURALBASELINE Run clean-only S1/S2/R1 baseline experiments.

experimentRoot = fileparts(mfilename('fullpath'));
cleanRoot = resolve_clean_root(experimentRoot);
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(cleanRoot);

results = struct();
results.algorithm = 'PGCIN-WHCL';
results.matlabVersion = version;
results.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
results.sourceManifest = collectSourceManifest(cleanRoot);

results.structure = runStructureCoverage(cleanRoot, resultRoot);
results.reconstruction = runContextReconstruction(cleanRoot, resultRoot);
results.roundTrip = runRoundTripAndFrozenVector(cleanRoot, resultRoot);

save(fullfile(resultRoot, 'final_structural_baseline.mat'), 'results', '-v7');
writeManifest(results, resultRoot);
fprintf('PGCIN-WHCL clean S1/S2/R1 baseline completed.\n');
end

function tableResult = runStructureCoverage(~, resultRoot)
tileSizes = [4, 8, 16, 32, 64];
rowCount = numel(tileSizes);
tableResult = table('Size', [rowCount, 8], ...
    'VariableTypes', {'double', 'double', 'double', 'double', ...
    'double', 'double', 'logical', 'double'}, ...
    'VariableNames', {'tileSize', 'stageCount', 'pairwiseLowerBound', ...
    'boundGap', 'finalMinimumSupport', 'finalMaximumSupport', ...
    'matchingAllValid', 'finalFullSupportRate'});

for row = 1:rowCount
    tileSize = tileSizes(row);
    cfg = pgcinwhcl.defaultConfig();
    cfg.tileSize = tileSize;
    cfg = pgcinwhcl.withNonce(cfg, uint8(0:15));
    plain = makeTestImage(tileSize, tileSize, 100 + tileSize);
    [runtimeConfig, session, state] = prepareRuntime(cfg, plain, 1);
    schedule = pgcinwhcl.buildSchedule(runtimeConfig, session, 1, state);
    pixelCount = tileSize ^ 2;
    stageCount = schedule.stageCount;
    support = false(pixelCount, pixelCount);
    support(1:pixelCount + 1:end) = true;
    matchingAllValid = true;
    for stage = 1:stageCount
        pairU = double(schedule.pairU(:, 1, stage));
        pairV = double(schedule.pairV(:, 1, stage));
        vertices = [pairU; pairV];
        matchingAllValid = matchingAllValid ...
            && numel(unique(vertices)) == pixelCount ...
            && all(vertices >= 1 & vertices <= pixelCount);
        unionRows = support(pairU, :) | support(pairV, :);
        nextSupport = false(pixelCount, pixelCount);
        nextSupport(pairU, :) = unionRows;
        nextSupport(pairV, :) = unionRows;
        support = nextSupport;
    end
    supportSize = sum(support, 2);
    tableResult.tileSize(row) = tileSize;
    tableResult.stageCount(row) = stageCount;
    tableResult.pairwiseLowerBound(row) = 2 * log2(tileSize);
    tableResult.boundGap(row) = stageCount - tableResult.pairwiseLowerBound(row);
    tableResult.finalMinimumSupport(row) = min(supportSize);
    tableResult.finalMaximumSupport(row) = max(supportSize);
    tableResult.matchingAllValid(row) = matchingAllValid;
    tableResult.finalFullSupportRate(row) = mean(supportSize == pixelCount);
    assert(matchingAllValid, 'S1 perfect matching failed for B=%d.', tileSize);
    assert(tableResult.finalFullSupportRate(row) == 1, ...
        'S1 full graph support failed for B=%d.', tileSize);
end

writetable(tableResult, fullfile(resultRoot, 'S1_structure_coverage.csv'));
save(fullfile(resultRoot, 'S1_structure_coverage.mat'), 'tableResult', '-v7');
end

function tableResult = runContextReconstruction(~, resultRoot)
tileSize = 16;
tileRows = 4;
tileCols = 4;
plain = makeTestImage(tileRows * tileSize, tileCols * tileSize, 216);
cfg = pgcinwhcl.defaultConfig();
cfg.tileSize = tileSize;
cfg = pgcinwhcl.withNonce(cfg, uint8(0:15));
[~, meta] = pgcinwhcl.encryptImage(plain, cfg);
runtimeConfig = pgcinwhcl.runtimeConfigFromMetadata(cfg, meta);
tileCount = tileRows * tileCols;
session = pgcinwhcl.deriveSession(runtimeConfig, meta.syntheticIV, tileCount);
state = pgcinwhcl.generateStates(runtimeConfig, session, tileCount);
stageCount = double(session.stageCount);
statesPerTile = stageCount + 1;
contextCount = tileCount * stageCount;
meshClocks = zeros(contextCount, 1, 'uint64');
decodedClocks = zeros(contextCount, 1, 'uint64');
velocityResidual = zeros(contextCount, 1);
phaseResidual = zeros(contextCount, 1);
writeIndex = 1;
for tileIndex = 0:tileCount - 1
    for stageIndex = 0:stageCount - 1
        stateRow = tileIndex * statesPerTile + stageIndex + 1;
        gear = pgcinwhcl.selectGearState(state, stateRow);
        context = pgcinwhcl.whclContexts(session, uint64(tileIndex), ...
            uint64(stageIndex), gear.basePhase, gear.omegaC, gear.meshDrive);
        decoded = pgcinwhcl.whclDecodeContext(session, context.sunTooth, ...
            context.planetTooth, context.ringTooth, context.phaseClock);
        meshClocks(writeIndex) = context.meshClock;
        decodedClocks(writeIndex) = decoded;
        velocityResidual(writeIndex) = double(context.velocityWillisResidual);
        phaseResidual(writeIndex) = double(context.phaseWillisResidual);
        writeIndex = writeIndex + 1;
    end
end
crtPass = isequal(meshClocks, decodedClocks);
uniquePass = numel(unique(meshClocks)) == contextCount;
willisPass = all(velocityResidual == 0) && all(phaseResidual == 0);
capacityPass = uint64(tileCount) <= session.maxTileCount;
tableResult = table(tileSize, tileCount, stageCount, contextCount, ...
    double(session.period), double(session.maxTileCount), crtPass, ...
    uniquePass, willisPass, capacityPass, ...
    'VariableNames', {'tileSize', 'tileCount', 'stageCount', ...
    'contextCount', 'period', 'maxTileCount', 'crtPass', ...
    'uniqueContextPass', 'willisPass', 'capacityPass'});
assert(crtPass && uniquePass && willisPass && capacityPass, ...
    'S2 WHCL reconstruction baseline failed.');
writetable(tableResult, fullfile(resultRoot, 'S2_context_reconstruction.csv'));
save(fullfile(resultRoot, 'S2_context_reconstruction.mat'), ...
    'tableResult', 'meshClocks', 'decodedClocks', '-v7');
end

function tableResult = runRoundTripAndFrozenVector(~, resultRoot)
tileSizes = [4, 8, 16, 32, 64];
rowCount = numel(tileSizes);
tableResult = table('Size', [rowCount, 5], ...
    'VariableTypes', {'double', 'double', 'double', 'logical', 'logical'}, ...
    'VariableNames', {'tileSize', 'height', 'width', ...
    'roundTripPass', 'fixedCipherRepeatPass'});
fixedCipher = [];
fixedMeta = struct();
fixedPlain = [];
for row = 1:rowCount
    tileSize = tileSizes(row);
    height = tileSize + 3;
    width = tileSize + 5;
    plain = makeTestImage(height, width, 500 + tileSize);
    cfg = pgcinwhcl.defaultConfig();
    cfg.tileSize = tileSize;
    cfg = pgcinwhcl.withNonce(cfg, uint8(0:15));
    [cipher, meta] = pgcinwhcl.encryptImage(plain, cfg);
    recovered = pgcinwhcl.decryptImage(cipher, cfg, meta);
    [repeatCipher, repeatMeta] = pgcinwhcl.encryptImage(plain, cfg);
    roundTripPass = isequal(plain, recovered);
    fixedCipherRepeatPass = isequal(cipher, repeatCipher) ...
        && isequal(meta.syntheticIV, repeatMeta.syntheticIV) ...
        && isequal(meta.publicNonce, repeatMeta.publicNonce);
    tableResult.tileSize(row) = tileSize;
    tableResult.height(row) = height;
    tableResult.width(row) = width;
    tableResult.roundTripPass(row) = roundTripPass;
    tableResult.fixedCipherRepeatPass(row) = fixedCipherRepeatPass;
    assert(roundTripPass && fixedCipherRepeatPass, ...
        'R1 fixed round trip vector failed for B=%d.', tileSize);
    if tileSize == 16
        fixedCipher = cipher;
        fixedMeta = meta;
        fixedPlain = plain;
    end
end

save(fullfile(resultRoot, 'R1_frozen_vector_B16.mat'), ...
    'fixedPlain', 'fixedCipher', 'fixedMeta', '-v7');
writetable(tableResult, fullfile(resultRoot, 'R1_round_trip.csv'));
save(fullfile(resultRoot, 'R1_round_trip.mat'), 'tableResult', '-v7');
end

function [runtimeConfig, session, state] = prepareRuntime(cfg, plain, tileCount)
syntheticIV = pgcinwhcl.deriveSyntheticIV(plain, cfg);
runtimeConfig = pgcinwhcl.applySyntheticIV(cfg, syntheticIV);
session = pgcinwhcl.deriveSession(runtimeConfig, syntheticIV, tileCount);
state = pgcinwhcl.generateStates(runtimeConfig, session, tileCount);
end

function image = makeTestImage(height, width, seed)
[column, row] = meshgrid(0:width - 1, 0:height - 1);
red = mod(17 * row + 31 * column + seed, 256);
green = mod(13 * row + 47 * column + 3 * seed, 256);
blue = mod(29 * row + 19 * column + 5 * seed, 256);
image = uint8(cat(3, red, green, blue));
end

function manifest = collectSourceManifest(cleanRoot)
files = [dir(fullfile(cleanRoot, '*.m')); ...
    dir(fullfile(cleanRoot, '+pgcinwhcl', '*.m'))];
manifest = repmat(struct('path', '', 'sha256', ''), numel(files), 1);
for index = 1:numel(files)
    if files(index).isdir
        continue
    end
    filePath = fullfile(files(index).folder, files(index).name);
    fileId = fopen(filePath, 'r');
    assert(fileId >= 0, 'Cannot read source file: %s', filePath);
    cleanup = onCleanup(@() fclose(fileId));
    bytes = fread(fileId, inf, '*uint8').';
    digest = pgcinwhcl.sha256(bytes);
    manifest(index).path = strrep(filePath, [cleanRoot filesep], '');
    manifest(index).sha256 = lower(reshape(dec2hex(digest, 2).', 1, []));
end
end

function writeManifest(results, resultRoot)
manifestPath = fullfile(resultRoot, 'MANIFEST.txt');
fileId = fopen(manifestPath, 'w');
assert(fileId >= 0, 'Cannot write baseline manifest.');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'algorithm=%s\n', results.algorithm);
fprintf(fileId, 'matlabVersion=%s\n', results.matlabVersion);
fprintf(fileId, 'timestamp=%s\n', results.timestamp);
fprintf(fileId, 'sourceFileCount=%d\n', numel(results.sourceManifest));
for index = 1:numel(results.sourceManifest)
    fprintf(fileId, 'source.%03d.path=%s\n', index, ...
        results.sourceManifest(index).path);
    fprintf(fileId, 'source.%03d.sha256=%s\n', index, ...
        results.sourceManifest(index).sha256);
end
fprintf(fileId, 'S1=passed\nS2=passed\nR1=passed\n');
end
