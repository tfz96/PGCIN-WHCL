function [cipher, meta, trace] = traceEncryption(plain, cfg)
%TRACEENCRYPTION Encrypt once and collect display-only snapshots.
%
% The canonical production traversal now returns the optional true stage
% states and address diagnostic in the same pass. The address view remains
% a diagnostic shadow; it is not an independent production permutation.

validateattributes(plain, {'uint8'}, {'nonempty'});
assert(ndims(plain) == 3 && size(plain, 3) == 3, ...
    'Input must be an RGB uint8 image.');
[cipher, meta, traceData] = pgcinwhcl.encryptImage(plain, cfg);

trace = struct();
trace.plain = traceData.plain;
trace.permutation = traceData.permutation;
trace.permutationDifference = permutationDifference( ...
    traceData.plain, traceData.permutation);
trace.stageStates = traceData.stageStates;
trace.diffusion = trace.stageStates{1};
trace.cipher = cipher;
trace.stageEntropy = cellfun(@(image) pgcinwhcl.imageEntropy(image), ...
    trace.stageStates);
trace.entropy = [pgcinwhcl.imageEntropy(trace.plain), ...
    pgcinwhcl.imageEntropy(trace.permutation), ...
    pgcinwhcl.imageEntropy(trace.diffusion), ...
    pgcinwhcl.imageEntropy(trace.cipher)];
trace.originalSize = meta.originalSize;
trace.paddedSize = meta.paddedSize;
trace.labels = {'Plaintext (padded)', ...
    'Intra-block address permutation', 'Permutation difference', ...
    'First-stage diffusion', 'Ciphertext'};
end

function output = permutationDifference(reference, permuted)
delta = abs(double(reference) - double(permuted));
delta = min(4 * delta, 255);
output = uint8(delta);
end
