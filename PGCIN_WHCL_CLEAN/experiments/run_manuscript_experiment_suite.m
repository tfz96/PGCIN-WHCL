function manifest = run_manuscript_experiment_suite(mode, runId)
%RUN_MANUSCRIPT_EXPERIMENT_SUITE Run final-code paper experiments reproducibly.
%
% manifest = run_manuscript_experiment_suite('smoke')
% manifest = run_manuscript_experiment_suite('core')
% manifest = run_manuscript_experiment_suite('full')
%
% Each invocation writes to experiments/runs/<runId>. Existing canonical
% results are never deleted or overwritten. The production +pgcinwhcl
% package and all experiment parameters remain unchanged.

if nargin < 1 || isempty(mode)
    mode = 'smoke';
end
if nargin < 2
    runId = '';
end
mode = validatestring(lower(char(string(mode))), {'smoke', 'core', 'full'});

paths = resolveSuitePaths(runId);
oldResultRoot = getenv('PGCIN_WHCL_RESULT_ROOT');
environmentCleanup = onCleanup(@() restoreEnvironment(oldResultRoot));
setenv('PGCIN_WHCL_RESULT_ROOT', paths.resultRoot);
addpath(paths.cleanRoot, genpath(paths.experimentRoot));

sourceManifest = collectSourceManifest(paths);
sourceDigest = aggregateSourceDigest(sourceManifest);
datasetManifest = collectDatasetManifest(paths);
environment = collectEnvironment(paths);

manifest = struct();
manifest.algorithm = 'PGCIN-WHCL';
manifest.mode = mode;
manifest.runId = paths.runId;
manifest.status = 'RUNNING';
manifest.startUtc = utcTimestamp();
manifest.endUtc = '';
manifest.elapsedSeconds = NaN;
manifest.sourceDigestSha256 = sourceDigest;
manifest.environment = environment;
manifest.parameters = declaredParameters();
manifest.paths = paths;
manifest.sourceManifest = sourceManifest;
manifest.datasetManifest = datasetManifest;
manifest.steps = emptyStepRecords();
suiteTimer = tic;
writeManifestCheckpoint(manifest, paths);

analyzer = runCodeAnalyzer(sourceManifest, paths);
manifest.codeAnalyzer = analyzer;
manifest.steps = [manifest.steps; analyzer.step];
writeManifestCheckpoint(manifest, paths);
if ~analyzer.pass
    manifest = appendSkippedSteps(manifest, suiteStepDefinitions(mode, paths), ...
        'Code Analyzer did not pass.');
    manifest.status = 'FAIL';
    manifest.endUtc = utcTimestamp();
    manifest.elapsedSeconds = toc(suiteTimer);
    writeFinalManifest(manifest, paths);
    message = sprintf('Code Analyzer reported %d issue(s).', ...
        analyzer.issueCount);
    throw(MException('PGCINWHCL:CodeAnalyzerFailed', message));
end

definitions = suiteStepDefinitions(mode, paths);
for index = 1:numel(definitions)
    definition = definitions(index);
    [record, result] = runSuiteStep(definition, paths);
    manifest.steps = [manifest.steps; record];
    if ~isempty(result)
        manifest.stepResults.(definition.name) = result;
    end
    writeManifestCheckpoint(manifest, paths);
end

statuses = string({manifest.steps.status});
if any(statuses == "FAIL")
    manifest.status = 'FAIL';
else
    manifest.status = 'PASS';
end
manifest.endUtc = utcTimestamp();
manifest.elapsedSeconds = toc(suiteTimer);
writeFinalManifest(manifest, paths);

fprintf('PGCIN-WHCL manuscript experiment suite %s: %s\n', ...
    manifest.status, paths.runRoot);
clear environmentCleanup
if strcmp(manifest.status, 'FAIL')
    throw(MException('PGCINWHCL:ManuscriptSuiteFailed', ...
        'One or more required manuscript experiment steps failed.'));
end
end

function paths = resolveSuitePaths(requestedRunId)
scriptRoot = fileparts(mfilename('fullpath'));
experimentRoot = scriptRoot;
cleanRoot = fileparts(experimentRoot);
projectRoot = fileparts(cleanRoot);
if isempty(requestedRunId)
    baseRunId = ['run_' char(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyyMMdd_HHmmss_SSS')) 'Z'];
else
    baseRunId = char(string(requestedRunId));
    assert(~isempty(regexp(baseRunId, '^[A-Za-z0-9][A-Za-z0-9_-]*$', 'once')), ...
        'runId may contain only letters, digits, underscore, and hyphen.');
end
runsRoot = fullfile(experimentRoot, 'runs');
ensureDirectory(runsRoot);
runId = baseRunId;
suffix = 1;
while exist(fullfile(runsRoot, runId), 'dir')
    suffix = suffix + 1;
    runId = sprintf('%s_%02d', baseRunId, suffix);
end
runRoot = fullfile(runsRoot, runId);
paths = struct('projectRoot', projectRoot, 'cleanRoot', cleanRoot, ...
    'experimentRoot', experimentRoot, 'runsRoot', runsRoot, ...
    'runId', runId, 'runRoot', runRoot, ...
    'resultRoot', fullfile(runRoot, 'results'), ...
    'logRoot', fullfile(runRoot, 'logs'), ...
    'manifestRoot', fullfile(runRoot, 'manifest'), ...
    'kodakRoot', resolveKodakRoot(projectRoot));
ensureDirectory(paths.resultRoot);
ensureDirectory(paths.logRoot);
ensureDirectory(paths.manifestRoot);
end

function kodakRoot = resolveKodakRoot(projectRoot)
kodakRoot = fullfile(projectRoot, 'matlab', 'data', 'kodak');
assert(isfolder(kodakRoot), 'Kodak-24 directory not found: %s', kodakRoot);
end

function definitions = suiteStepDefinitions(mode, paths)
base = [ ...
    stepDefinition('clean_gate_start', @run_pgcinwhcl_clean_gate, ...
        @validateCleanGate, true, 'Core API and metadata gate'), ...
    stepDefinition('structural_baseline', @run_final_structural_baseline, ...
        @validateStructuralBaseline, true, 'Matching, WHCL, and round trip'), ...
    stepDefinition('dependency_baseline', @run_dependency_locality_baseline, ...
        @validateDependencyBaseline, true, 'Dependency and error locality'), ...
    stepDefinition('gear_control', @run_gear_control_audit, ...
        @validateGearControl, true, 'Gear and WHCL intervention evidence'), ...
    stepDefinition('generic_controller', @run_generic_controller_audit, ...
        @validateGenericController, true, 'Generic-equivalence boundary'), ...
    stepDefinition('clean_gate_end', @run_pgcinwhcl_clean_gate, ...
        @validateCleanGate, true, 'Post-experiment clean gate')];

coreExtra = [ ...
    stepDefinition('repeated_dependency', @run_repeated_dependency_campaign, ...
        @validateRepeatedDependency, true, 'Repeated dependency campaign'), ...
    stepDefinition('repeated_generic_controller', ...
        @run_repeated_generic_controller_audit, ...
        @validateRepeatedGeneric, true, 'Repeated generic control boundary')];

fullExtra = [ ...
    stepDefinition('empirical_baseline', @run_empirical_performance_baseline, ...
        @validateEmpiricalBaseline, true, 'Kodak and weak-input diagnostics'), ...
    stepDefinition('submission_supplement', @run_submission_supplement, ...
        @validateSubmissionSupplement, true, 'Kodak sensitivity and bursts'), ...
    stepDefinition('attack_surface', @run_attack_surface_supplement, ...
        @validateAttackSurface, true, 'Unauthenticated attack boundaries'), ...
    stepDefinition('feedback_tradeoff', ...
        @() runIsolatedExperiment('run_feedback_tradeoff_control', ...
        'feedback_tradeoff_control.mat', paths), ...
        @validateFeedbackTradeoff, true, ...
        'Matched index-only and ciphertext-feedback payload control'), ...
    stepDefinition('repeated_performance', ...
        @() runIsolatedExperiment('run_repeated_performance_campaign', ...
        'repeated_performance_campaign.mat', paths), ...
        @validateRepeatedPerformance, true, 'Warm paired timing campaign'), ...
    stepDefinition('large_scale_performance', ...
        @() runIsolatedExperiment('run_large_scale_performance_supplement', ...
        'large_scale_performance_supplement.mat', paths), ...
        @validateLargeScalePerformance, true, 'Larger batch timing')];

switch mode
    case 'smoke'
        definitions = base;
    case 'core'
        definitions = [base(1:5), coreExtra, base(6)];
    case 'full'
        definitions = [base(1:5), coreExtra, fullExtra, base(6)];
end
end

function definition = stepDefinition(name, runner, validator, required, description)
definition = struct('name', name, 'runner', runner, ...
    'validator', validator, 'required', required, ...
    'description', description);
end

function [record, result] = runSuiteStep(definition, paths)
record = newStepRecord(definition.name, definition.description, ...
    definition.required);
record.startUtc = utcTimestamp();
before = snapshotFiles(paths.runRoot);
timer = tic;
result = [];
try
    result = definition.runner();
    definition.validator(result);
    record.status = 'PASS';
catch exception
    record.status = 'FAIL';
    record.errorIdentifier = exception.identifier;
    record.errorMessage = exception.message;
    record.errorReportFile = writeErrorReport(exception, definition.name, paths);
end
record.elapsedSeconds = toc(timer);
record.endUtc = utcTimestamp();
after = snapshotFiles(paths.runRoot);
record.outputFiles = setdiff(after, before, 'stable');
record.outputCount = numel(record.outputFiles);
end

function analyzer = runCodeAnalyzer(sourceManifest, paths)
definition = struct('name', 'code_analyzer', ...
    'description', 'MATLAB R2024a Code Analyzer', 'required', true);
step = newStepRecord(definition.name, definition.description, true);
step.startUtc = utcTimestamp();
timer = tic;
issues = repmat(struct('file', '', 'id', '', 'message', '', ...
    'line', NaN, 'column', NaN), 0, 1);
try
    for fileIndex = 1:numel(sourceManifest)
        report = checkcode(sourceManifest(fileIndex).absolutePath, ...
            '-struct', '-id');
        for issueIndex = 1:numel(report)
            issue = struct();
            issue.file = sourceManifest(fileIndex).path;
            issue.id = report(issueIndex).id;
            issue.message = report(issueIndex).message;
            issue.line = firstNumeric(report(issueIndex).line);
            issue.column = firstNumeric(report(issueIndex).column);
            issues(end + 1) = issue; %#ok<AGROW>
        end
    end
    pass = isempty(issues);
    if pass
        step.status = 'PASS';
    else
        step.status = 'FAIL';
        step.errorIdentifier = 'PGCIN-WHCL:CodeAnalyzerIssues';
        step.errorMessage = sprintf('%d Code Analyzer issue(s).', numel(issues));
    end
catch exception
    pass = false;
    step.status = 'FAIL';
    step.errorIdentifier = exception.identifier;
    step.errorMessage = exception.message;
    step.errorReportFile = writeErrorReport(exception, definition.name, paths);
end
step.elapsedSeconds = toc(timer);
step.endUtc = utcTimestamp();
issueTable = struct2table(issues);
issuePath = fullfile(paths.manifestRoot, 'code_analyzer_issues.csv');
writetable(issueTable, issuePath);
step.outputFiles = string(relativePath(issuePath, paths.runRoot));
step.outputCount = 1;
analyzer = struct('pass', pass, 'fileCount', numel(sourceManifest), ...
    'issueCount', numel(issues), 'issues', issues, 'step', step);
end

function manifest = appendSkippedSteps(manifest, definitions, reason)
for index = 1:numel(definitions)
    definition = definitions(index);
    record = newStepRecord(definition.name, definition.description, ...
        definition.required);
    record.status = 'SKIP';
    record.errorMessage = reason;
    manifest.steps(end + 1) = record;
end
end

function record = newStepRecord(name, description, required)
record = struct('name', name, 'description', description, ...
    'required', logical(required), 'status', 'PENDING', ...
    'startUtc', '', 'endUtc', '', 'elapsedSeconds', NaN, ...
    'outputFiles', strings(0, 1), 'outputCount', 0, ...
    'errorIdentifier', '', 'errorMessage', '', 'errorReportFile', '');
end

function records = emptyStepRecords()
records = repmat(newStepRecord('', '', true), 0, 1);
end

function validateCleanGate(result)
assert(isstruct(result) && result.tileRoundTrip && result.whcl ...
    && result.autoNonce, 'Clean gate returned an incomplete result.');
end

function validateStructuralBaseline(result)
assert(all(result.structure.matchingAllValid) ...
    && all(result.structure.finalFullSupportRate == 1), ...
    'Structural matching or support validation failed.');
assert(all(result.reconstruction.crtPass) ...
    && all(result.reconstruction.uniqueContextPass) ...
    && all(result.reconstruction.willisPass) ...
    && all(result.reconstruction.capacityPass), ...
    'WHCL reconstruction validation failed.');
assert(all(result.roundTrip.roundTripPass) ...
    && all(result.roundTrip.fixedCipherRepeatPass), ...
    'Round trip or fixed-cipher repetition failed.');
end

function validateDependencyBaseline(result)
assert(all(result.fixedSession.outsideTouchedMacroblockBytes == 0), ...
    'Fixed-session dependency escaped the touched macroblock.');
assert(all(result.payloadLocality.outsideTouchedMacroblockPixels == 0) ...
    && all(result.payloadLocality.affectedMacroblockCount == 1), ...
    'Payload-error locality validation failed.');
required = ["plaintextBit", "masterKeyBit", "nonceBit"];
assert(all(ismember(required, string(result.apiSensitivity.perturbation))), ...
    'API sensitivity cases are incomplete.');
end

function validateRepeatedDependency(result)
assert(result.D1.outsideMax == 0 && result.D3.outsideMax == 0, ...
    'Repeated dependency locality failed.');
assert(result.D1.rows > 0 && result.D2.rows > 0 && result.D3.rows > 0, ...
    'Repeated dependency result is empty.');
end

function validateEmpiricalBaseline(result)
assert(height(result.naturalImages) == 24, ...
    'Natural-image diagnostics did not cover Kodak-24.');
assert(all(result.weakInputs.fixedNonceRepeatPass) ...
    && all(result.weakInputs.roundTripPass), ...
    'Weak-input validation failed.');
assert(height(result.performance) == 3, ...
    'Baseline timing cases are incomplete.');
end

function validateSubmissionSupplement(result)
assert(result.D2.imageCount == 24 && result.D2.rows == 216, ...
    'Kodak sensitivity campaign is incomplete.');
assert(result.D3.rows > 0 && result.D3.outsideMax == 0, ...
    'Kodak burst-locality campaign failed.');
end

function validateAttackSurface(result)
assert(result.maskReuse.rows > 0 && result.macroblockManipulation.rows > 0, ...
    'Attack-surface campaign is empty.');
assert(result.macroblockManipulation.decryptCompletionRate == 1 ...
    && result.macroblockManipulation.outsideMaximum == 0, ...
    'Documented macroblock manipulation boundary was not reproduced.');
end

function validateFeedbackTradeoff(result)
order = result.orderIndependence;
assert(height(order) == 3 ...
    && all(order.cipherMatchesProduction) && all(order.exactRoundTrip), ...
    'Macroblock-order validation failed.');

tradeoff = result.feedbackTradeoff;
assert(isequal(string(tradeoff.controller), ...
    ["index-only"; "ciphertext-feedback"]) ...
    && all(tradeoff.definedXorPerPayloadByte == 1) ...
    && isequal(tradeoff.definedPredecessorPayloadReads, [0; 15]) ...
    && isequal(tradeoff.definedMaximumTransitiveCoreTileSupport, [1; 16]) ...
    && isequal(tradeoff.definedSelectedCoreTileCiphertextsRequired, [1; 2]) ...
    && isequal(tradeoff.measuredReverseOnePassCompleted, [true; false]) ...
    && isequal(tradeoff.measuredReverseOnePassMatchesForward, [true; false]) ...
    && all(tradeoff.measuredExactRoundTrip) ...
    && all(tradeoff.measuredSelectedCoreTileUnwrapExact), ...
    'Matched payload-dependency trade-off was not reproduced.');

damage = result.damageSupport;
assert(height(damage) == 4 ...
    && isequal(string(damage.controller), ...
    ["index-only"; "ciphertext-feedback"; ...
    "index-only"; "ciphertext-feedback"]) ...
    && isequal(string(damage.scenario), ...
    ["interior-with-successor"; "interior-with-successor"; ...
    "terminal"; "terminal"]) ...
    && all(damage.decryptCompleted) && ~any(damage.exactRecovery) ...
    && isequal(damage.affectedMacroblockCount, [1; 2; 1; 1]) ...
    && isequal(damage.changedPixels, [256; 512; 256; 256]) ...
    && all(damage.outsideExpectedPixels == 0), ...
    'Payload-wrapper error support was not reproduced.');

timing = result.timing;
trials = result.timingTrials;
assert(height(timing) == 24 && all(timing.trialCount == 10) ...
    && all(timing.warmupCount == 2) ...
    && all(timing.indexedMedianMs > 0) ...
    && all(timing.feedbackMedianMs > 0) ...
    && all(isfinite(timing.medianPairedRatio)) ...
    && height(trials) == 240 ...
    && all(isfinite(trials.pairedDeltaMs)) ...
    && all(isfinite(trials.pairedRatio)) ...
    && nnz(trials.executionOrder == "indexed-first") == 120 ...
    && nnz(trials.executionOrder == "feedback-first") == 120, ...
    'Matched payload-wrapper timing campaign is incomplete.');
end

function validateGearControl(result)
variants = result.variants;
assert(all([variants.exactRoundTrip]) && all([variants.matchingValid]) ...
    && all([variants.fullSupportRate] == 1), ...
    'Gear-control variants lost reversibility or structure.');
assert(all([variants(2:end).cipherChangedPercent] > 0), ...
    'A gear/WHCL intervention did not alter ciphertext.');
end

function validateGenericController(result)
assert(result.baselineRoundTrip && result.genericRoundTrip ...
    && result.matchingValid && result.baselineSupportRate == 1 ...
    && result.genericSupportRate == 1, ...
    'Generic-controller boundary validation failed.');
end

function validateRepeatedGeneric(result)
rows = result.rows;
assert(all([rows.baselineRoundTrip]) && all([rows.genericRoundTrip]) ...
    && all([rows.matchingValid]) && all([rows.genericSupportRate] == 1), ...
    'Repeated generic-controller validation failed.');
end

function validateRepeatedPerformance(result)
tableResult = result.tableResult;
assert(height(tableResult) == 12 && all(tableResult.trialCount == 7) ...
    && all(tableResult.warmupCount == 2), ...
    'Repeated timing campaign is incomplete.');
assert(all(isfinite(tableResult.encryptMedianMs)) ...
    && all(isfinite(tableResult.decryptMedianMs)) ...
    && all(tableResult.encryptMedianMs > 0) ...
    && all(tableResult.decryptMedianMs > 0), ...
    'Repeated timing contains invalid values.');
end

function validateLargeScalePerformance(result)
tableResult = result.tableResult;
assert(height(tableResult) == 4 && all(tableResult.trialCount == 5) ...
    && all(tableResult.warmupCount == 2), ...
    'Large-scale timing campaign is incomplete.');
assert(all(isfinite(tableResult.encryptMedianMs)) ...
    && all(isfinite(tableResult.decryptMedianMs)) ...
    && all(tableResult.encryptMedianMs > 0) ...
    && all(tableResult.decryptMedianMs > 0), ...
    'Large-scale timing contains invalid values.');
end

function result = runIsolatedExperiment(functionName, resultFile, paths)
matlabExecutable = fullfile(matlabroot, 'bin', 'matlab.exe');
if ~isfile(matlabExecutable)
    matlabExecutable = fullfile(matlabroot, 'bin', 'matlab');
end
assert(isfile(matlabExecutable), 'Cannot locate the MATLAB executable.');
commandText = sprintf([ ...
    'setenv(''PGCIN_WHCL_RESULT_ROOT'',''%s'');' ...
    'addpath(''%s'');addpath(genpath(''%s''));%s;'], ...
    matlabQuote(paths.resultRoot), matlabQuote(paths.cleanRoot), ...
    matlabQuote(paths.experimentRoot), functionName);
logPath = fullfile(paths.logRoot, [functionName '.txt']);
shellCommand = sprintf('"%s" -batch "%s" > "%s" 2>&1', ...
    matlabExecutable, commandText, logPath);
[status, output] = system(shellCommand);
if status ~= 0
    error('PGCINWHCL:IsolatedExperimentFailed', ...
        'Isolated experiment %s failed: %s', functionName, strtrim(output));
end
resultPath = fullfile(paths.resultRoot, resultFile);
assert(isfile(resultPath), ...
    'Isolated experiment did not produce its result file: %s', resultFile);
loaded = load(resultPath, 'results');
assert(isfield(loaded, 'results'), ...
    'Isolated experiment result file is incomplete: %s', resultFile);
result = loaded.results;
end

function output = matlabQuote(input)
output = strrep(char(input), '''', '''''');
end

function sourceManifest = collectSourceManifest(paths)
files = [dir(fullfile(paths.cleanRoot, '*.m')); ...
    dir(fullfile(paths.cleanRoot, '+pgcinwhcl', '*.m')); ...
    dir(fullfile(paths.experimentRoot, '*.m'))];
absolutePaths = strings(numel(files), 1);
for index = 1:numel(files)
    absolutePaths(index) = string(fullfile(files(index).folder, files(index).name));
end
[~, order] = sort(lower(absolutePaths));
files = files(order);
sourceManifest = repmat(struct('path', '', 'absolutePath', '', ...
    'bytes', uint64(0), 'sha256', ''), numel(files), 1);
for index = 1:numel(files)
    path = fullfile(files(index).folder, files(index).name);
    sourceManifest(index).path = relativePath(path, paths.cleanRoot);
    sourceManifest(index).absolutePath = path;
    sourceManifest(index).bytes = uint64(files(index).bytes);
    sourceManifest(index).sha256 = fileSha256(path);
end
end

function digest = aggregateSourceDigest(sourceManifest)
lines = strings(numel(sourceManifest), 1);
for index = 1:numel(sourceManifest)
    lines(index) = string(sourceManifest(index).path) + sprintf('\t') ...
        + string(sourceManifest(index).sha256) + newline;
end
digestBytes = pgcinwhcl.sha256(uint8(char(join(lines, ''))));
digest = lower(reshape(dec2hex(digestBytes, 2).', 1, []));
end

function datasetManifest = collectDatasetManifest(paths)
files = dir(fullfile(paths.kodakRoot, '*.png'));
[~, order] = sort({files.name});
files = files(order);
datasetManifest = repmat(struct('name', '', 'bytes', uint64(0), ...
    'sha256', ''), numel(files), 1);
for index = 1:numel(files)
    path = fullfile(files(index).folder, files(index).name);
    datasetManifest(index).name = files(index).name;
    datasetManifest(index).bytes = uint64(files(index).bytes);
    datasetManifest(index).sha256 = fileSha256(path);
end
end

function environment = collectEnvironment(paths)
environment = struct();
environment.matlabVersion = version;
environment.matlabRelease = version('-release');
environment.computer = computer;
environment.architecture = computer('arch');
environment.hostName = getenv('COMPUTERNAME');
environment.operatingSystem = char(java.lang.System.getProperty('os.name'));
environment.operatingSystemVersion = char( ...
    java.lang.System.getProperty('os.version'));
environment.timeZone = char(datetime('now', 'TimeZone', 'local', ...
    'Format', 'XXX'));
environment.sourceRoot = paths.cleanRoot;
environment.kodakRoot = paths.kodakRoot;
try
    environment.logicalCoreCount = feature('numcores');
catch
    environment.logicalCoreCount = NaN;
end
assert(strcmp(environment.matlabRelease, '2024a'), ...
    'The manuscript experiment suite requires MATLAB R2024a.');
assert(numel(dir(fullfile(paths.kodakRoot, '*.png'))) == 24, ...
    'The manuscript experiment suite requires the complete Kodak-24 corpus.');
end

function parameters = declaredParameters()
cfg = pgcinwhcl.defaultConfig();
parameters = struct();
parameters.defaultTileSize = cfg.tileSize;
parameters.stageCountAtDefault = 2 * log2(cfg.tileSize) + 1;
parameters.defaultTileBatchSize = cfg.tileBatchSize;
parameters.chaosDriver = cfg.chaosDriver;
parameters.chaosPrecision = cfg.chaosPrecision;
parameters.chaosExtraction = cfg.chaosExtraction;
parameters.burnIn = cfg.burnIn;
parameters.nonceBytes = 16;
parameters.masterKeyBytes = numel(cfg.masterKey);
parameters.repeatedTimingCases = [4, 2; 16, 2; 16, 16; 16, 64];
parameters.repeatedTimingBatchCount = 3;
parameters.repeatedTimingTrialCount = 7;
parameters.repeatedTimingWarmupCount = 2;
parameters.largeScaleCases = [16, 256; 16, 1024];
parameters.largeScaleBatchCount = 2;
parameters.largeScaleTrialCount = 5;
parameters.largeScaleWarmupCount = 2;
parameters.memoryStatement = ['memory() values are before/after process ' ...
    'diagnostics, not peak-memory measurements'];
parameters.protocol = experimentProtocol();
end

function protocol = experimentProtocol()
protocol = struct();
protocol.structural = struct('tileSizes', [4 8 16 32 64], ...
    'contextTileSize', 16, 'contextTileCount', 16, ...
    'fixedNonceHex', bytesToHex(uint8(0:15)), ...
    'roundTripSeeds', [504 508 516 532 564]);
protocol.dependencyBaseline = struct('tileSize', 16, ...
    'imageSide', 64, 'fixedSessionSeed', 1201, ...
    'apiSeed', 1302, 'payloadSeed', 1403, ...
    'noncesHex', {cellstr([string(bytesToHex(uint8(0:15))); ...
    string(bytesToHex(uint8(16:31))); string(bytesToHex(uint8(32:47)))])});
protocol.repeatedDependency = struct('tileSize', 16, ...
    'seedsD1', [2101 2102 2103], 'seedsD2', [2201 2202 2203], ...
    'seedsD3', [2301 2302 2303], ...
    'observedStages', 1:9, 'perturbation', 'one plaintext bit');
protocol.empirical = struct('dataset', 'Kodak-24', 'tileSize', 16, ...
    'naturalImageNonceHex', bytesToHex(uint8(64:79)), ...
    'weakInputNonceHex', bytesToHex(uint8(80:95)), ...
    'weakInputs', {{'allZero', 'all255', 'checkerboard', ...
    'rowGradient', 'columnGradient'}});
protocol.submission = struct('dataset', 'Kodak-24', 'tileSize', 16, ...
    'sensitivityNoncesHex', {cellstr([ ...
    string(bytesToHex(uint8(16:31))); string(bytesToHex(uint8(48:63))); ...
    string(bytesToHex(uint8(80:95)))])}, ...
    'perturbations', {{'plaintextBit', 'masterKeyBit', 'nonceBit'}}, ...
    'burstImageCount', 8, ...
    'burstNoncesHex', {cellstr([string(bytesToHex(uint8(112:127))); ...
    string(bytesToHex(uint8(144:159)))])});
protocol.attackSurface = struct('imageCount', 8, 'tileSize', 16, ...
    'maskReuseNoncesHex', {cellstr([string(bytesToHex(uint8(16:31))); ...
    string(bytesToHex(uint8(80:95)))])}, ...
    'baselineNonceHex', bytesToHex(uint8(112:127)), ...
    'donorNonceHex', bytesToHex(uint8(144:159)), ...
    'cases', {{'crossSessionReplay', 'withinCipherSwap'}});
protocol.feedbackTradeoff = struct('tileSize', 16, ...
    'validationTileCount', 16, ...
    'timingTileCounts', [16 64 256 1024], ...
    'campaignCount', 2, 'replicateCount', 3, ...
    'trialCount', 10, 'warmupCount', 2, ...
    'matchedOperation', 'one XOR per payload byte', ...
    'interpretation', ['analysis-only payload wrappers; timing does not ' ...
    'claim complete-algorithm speedup']);
protocol.gearControl = struct('tileSize', 16, 'tileCount', 4, ...
    'imageSeed', 902, 'nonceHex', bytesToHex(uint8(0:15)), ...
    'variants', {{'baseline', 'header-frozen', ...
    'gear-phase-frozen', 'whcl-input-frozen'}});
protocol.genericController = struct('tileSize', 16, 'tileCount', 4, ...
    'imageSeeds', [1901 2011 2121], ...
    'nonceBases', [0 48 96], 'caseCount', 3);
protocol.repeatedPerformance = struct('cases', ...
    [4 2; 16 2; 16 16; 16 64], 'batchCount', 3, ...
    'trialCount', 7, 'warmupCount', 2, 'paired', true);
protocol.largeScalePerformance = struct('cases', [16 256; 16 1024], ...
    'batchCount', 2, 'trialCount', 5, 'warmupCount', 2, ...
    'paired', true);
end

function files = snapshotFiles(root)
listing = dir(fullfile(root, '**', '*'));
listing = listing(~[listing.isdir]);
files = strings(numel(listing), 1);
for index = 1:numel(listing)
    files(index) = string(relativePath(fullfile(listing(index).folder, ...
        listing(index).name), root));
end
files = sort(files);
end

function path = writeErrorReport(exception, stepName, paths)
path = fullfile(paths.logRoot, [stepName '_error.txt']);
fileId = fopen(path, 'w');
if fileId >= 0
    cleanup = onCleanup(@() fclose(fileId));
    fprintf(fileId, '%s\n', getReport(exception, 'extended', ...
        'hyperlinks', 'off'));
end
path = relativePath(path, paths.runRoot);
end

function writeManifestCheckpoint(manifest, paths)
save(fullfile(paths.manifestRoot, 'in_progress.mat'), 'manifest', '-v7');
writeStepTable(manifest.steps, fullfile(paths.manifestRoot, ...
    'experiment_status.csv'));
writeSourceTable(manifest.sourceManifest, fullfile(paths.manifestRoot, ...
    'source_sha256.csv'));
writeDatasetTable(manifest.datasetManifest, fullfile(paths.manifestRoot, ...
    'dataset_sha256.csv'));
end

function writeFinalManifest(manifest, paths)
artifactManifest = collectArtifactManifest(paths);
manifest.artifactManifest = artifactManifest;
writeArtifactTable(artifactManifest, fullfile(paths.manifestRoot, ...
    'artifact_sha256.csv'));
writeManifestCheckpoint(manifest, paths);
temporaryMat = fullfile(paths.manifestRoot, 'run_manifest.tmp.mat');
finalMat = fullfile(paths.manifestRoot, 'run_manifest.mat');
save(temporaryMat, 'manifest', '-v7');
movefile(temporaryMat, finalMat, 'f');

temporaryJson = fullfile(paths.manifestRoot, 'run_manifest.tmp.json');
finalJson = fullfile(paths.manifestRoot, 'run_manifest.json');
json = jsonencode(jsonSafeManifest(manifest), 'PrettyPrint', true);
fileId = fopen(temporaryJson, 'w', 'n', 'UTF-8');
assert(fileId >= 0, 'Cannot write final experiment manifest JSON.');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', json);
clear cleanup
movefile(temporaryJson, finalJson, 'f');
end

function output = jsonSafeManifest(manifest)
output = manifest;
if isfield(output, 'stepResults')
    output = rmfield(output, 'stepResults');
end
output.sourceManifest = rmfield(output.sourceManifest, 'absolutePath');
end

function writeStepTable(steps, path)
count = numel(steps);
names = strings(count, 1);
descriptions = strings(count, 1);
required = false(count, 1);
statuses = strings(count, 1);
starts = strings(count, 1);
ends = strings(count, 1);
elapsed = NaN(count, 1);
outputs = strings(count, 1);
outputCount = zeros(count, 1);
identifiers = strings(count, 1);
messages = strings(count, 1);
reports = strings(count, 1);
for index = 1:count
    names(index) = string(steps(index).name);
    descriptions(index) = string(steps(index).description);
    required(index) = steps(index).required;
    statuses(index) = string(steps(index).status);
    starts(index) = string(steps(index).startUtc);
    ends(index) = string(steps(index).endUtc);
    elapsed(index) = steps(index).elapsedSeconds;
    outputs(index) = string(strjoin(cellstr(steps(index).outputFiles), ';'));
    outputCount(index) = steps(index).outputCount;
    identifiers(index) = string(steps(index).errorIdentifier);
    messages(index) = string(steps(index).errorMessage);
    reports(index) = string(steps(index).errorReportFile);
end
tableResult = table(names, descriptions, required, statuses, starts, ends, ...
    elapsed, outputs, outputCount, identifiers, messages, reports, ...
    'VariableNames', {'name', 'description', 'required', 'status', ...
    'startUtc', 'endUtc', 'elapsedSeconds', 'outputFiles', ...
    'outputCount', 'errorIdentifier', 'errorMessage', 'errorReportFile'});
writetable(tableResult, path);
end

function writeSourceTable(sourceManifest, path)
tableResult = struct2table(rmfield(sourceManifest, 'absolutePath'));
writetable(tableResult, path);
end

function writeDatasetTable(datasetManifest, path)
tableResult = struct2table(datasetManifest);
writetable(tableResult, path);
end

function artifactManifest = collectArtifactManifest(paths)
roots = {paths.resultRoot, paths.logRoot};
artifactManifest = repmat(struct('path', '', 'bytes', uint64(0), ...
    'sha256', ''), 0, 1);
for rootIndex = 1:numel(roots)
    files = dir(fullfile(roots{rootIndex}, '**', '*'));
    files = files(~[files.isdir]);
    for fileIndex = 1:numel(files)
        path = fullfile(files(fileIndex).folder, files(fileIndex).name);
        row = struct('path', relativePath(path, paths.runRoot), ...
            'bytes', uint64(files(fileIndex).bytes), ...
            'sha256', fileSha256(path));
        artifactManifest(end + 1) = row; %#ok<AGROW>
    end
end
if ~isempty(artifactManifest)
    [~, order] = sort(lower(string({artifactManifest.path})));
    artifactManifest = artifactManifest(order);
end
end

function writeArtifactTable(artifactManifest, path)
tableResult = struct2table(artifactManifest);
writetable(tableResult, path);
end

function digest = fileSha256(path)
fileId = fopen(path, 'r');
assert(fileId >= 0, 'Cannot read file for SHA-256: %s', path);
cleanup = onCleanup(@() fclose(fileId));
bytes = fread(fileId, inf, '*uint8').';
digestBytes = pgcinwhcl.sha256(bytes);
digest = lower(reshape(dec2hex(digestBytes, 2).', 1, []));
end

function value = firstNumeric(candidate)
if isempty(candidate)
    value = NaN;
elseif iscell(candidate)
    value = double(candidate{1});
else
    value = double(candidate(1));
end
end

function path = relativePath(path, root)
prefix = [root filesep];
if startsWith(path, prefix, 'IgnoreCase', true)
    path = path(numel(prefix) + 1:end);
end
path = strrep(path, filesep, '/');
end

function timestamp = utcTimestamp()
timestamp = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end

function hex = bytesToHex(bytes)
hex = lower(reshape(dec2hex(uint8(bytes), 2).', 1, []));
end

function ensureDirectory(path)
if ~exist(path, 'dir')
    [created, message] = mkdir(path);
    assert(created, 'Cannot create directory: %s', message);
end
end

function restoreEnvironment(resultRoot)
setenv('PGCIN_WHCL_RESULT_ROOT', resultRoot);
end
