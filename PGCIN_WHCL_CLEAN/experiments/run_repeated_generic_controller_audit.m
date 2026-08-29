function results = run_repeated_generic_controller_audit()
%RUNREPEATEDGENERICCONTROLLERAUDIT Repeat the generic shadow audit.

experimentRoot = fileparts(mfilename('fullpath'));
resultRoot = resolve_experiment_result_root(experimentRoot);
addpath(fileparts(experimentRoot));

nonceBases = uint8([0, 48, 96]);
imageSeeds = [1901, 2011, 2121];
caseCount = numel(nonceBases);
rows = repmat(struct( ...
    'caseIndex', 0, ...
    'imageSeed', 0, ...
    'nonceHex', '', ...
    'baselineRoundTrip', false, ...
    'genericRoundTrip', false, ...
    'matchingValid', false, ...
    'baselineSupportRate', 0, ...
    'genericSupportRate', 0, ...
    'cipherDifferencePercent', 0), caseCount, 1);

for caseIndex = 1:caseCount
    nonce = uint8(mod(double(nonceBases(caseIndex)) + (0:15), 256));
    outputTag = sprintf('repeat_%02d', caseIndex);
    single = run_generic_controller_audit(nonce, imageSeeds(caseIndex), ...
        outputTag);
    rows(caseIndex).caseIndex = caseIndex;
    rows(caseIndex).imageSeed = single.imageSeed;
    rows(caseIndex).nonceHex = single.nonceHex;
    rows(caseIndex).baselineRoundTrip = single.baselineRoundTrip;
    rows(caseIndex).genericRoundTrip = single.genericRoundTrip;
    rows(caseIndex).matchingValid = single.matchingValid;
    rows(caseIndex).baselineSupportRate = single.baselineSupportRate;
    rows(caseIndex).genericSupportRate = single.genericSupportRate;
    rows(caseIndex).cipherDifferencePercent = single.cipherDifferencePercent;
end

assert(all([rows.baselineRoundTrip]) && all([rows.genericRoundTrip]), ...
    'Repeated generic controller round trip failed.');
assert(all([rows.matchingValid]) && all([rows.genericSupportRate] == 1), ...
    'Repeated generic controller structural gate failed.');

tableResult = struct2table(rows);
results = struct();
results.algorithm = 'PGCIN-WHCL';
results.caseCount = caseCount;
results.rows = rows;
results.cipherDifferenceMin = min(tableResult.cipherDifferencePercent);
results.cipherDifferenceMedian = median(tableResult.cipherDifferencePercent);
results.cipherDifferenceMax = max(tableResult.cipherDifferencePercent);

writetable(tableResult, fullfile(resultRoot, ...
    'G_generic_controller_repeated.csv'));
save(fullfile(resultRoot, 'G_generic_controller_repeated.mat'), ...
    'results', 'tableResult', '-v7');
writeSummary(results, resultRoot);
fprintf('PGCIN-WHCL repeated generic controller audit completed.\n');
end

function writeSummary(results, resultRoot)
fileId = fopen(fullfile(resultRoot, ...
    'G_generic_controller_repeated.txt'), 'w');
assert(fileId >= 0, 'Cannot write repeated generic audit summary.');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'algorithm=%s\n', results.algorithm);
fprintf(fileId, 'caseCount=%d\n', results.caseCount);
fprintf(fileId, 'cipherDifferenceMin=%.12g\n', ...
    results.cipherDifferenceMin);
fprintf(fileId, 'cipherDifferenceMedian=%.12g\n', ...
    results.cipherDifferenceMedian);
fprintf(fileId, 'cipherDifferenceMax=%.12g\n', ...
    results.cipherDifferenceMax);
end
