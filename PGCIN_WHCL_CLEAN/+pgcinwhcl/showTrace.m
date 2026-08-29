function figureHandle = showTrace(trace, showStages)
%SHOWTRACE Display the concise encryption trace.
% Set showStages=true to open the optional nine-stage diagnostic figure.

if nargin < 2
    showStages = false;
end

required = {'plain', 'permutation', 'permutationDifference', ...
    'diffusion', 'cipher', 'entropy', 'stageStates', 'stageEntropy'};
assert(isstruct(trace) && all(isfield(trace, required)), ...
    'Trace data is incomplete.');
figureHandle = figure('Name', 'PGCIN-WHCL diagnostic trace', ...
    'Color', 'w', 'NumberTitle', 'off');
images = {trace.plain, trace.permutation, trace.permutationDifference, ...
    trace.diffusion, trace.cipher};
labels = {'Plaintext (padded)', 'Intra-block address permutation', ...
    'Permutation difference (visual aid)', 'First-stage diffusion', ...
    'Ciphertext'};
for index = 1:5
    subplot(2, 3, index, 'Parent', figureHandle);
    imshow(images{index});
    axis image off;
    if index == 3
        title(labels{index}, 'Interpreter', 'none');
    elseif index <= 2
    title(sprintf('%s\nEntropy = %.6f bits/byte', ...
            labels{index}, trace.entropy(index)), 'Interpreter', 'none');
    else
        entropyIndex = index - 1;
        title(sprintf('%s\nEntropy = %.6f bits/byte', ...
            labels{index}, trace.entropy(entropyIndex)), 'Interpreter', 'none');
    end
end
subplot(2, 3, 6, 'Parent', figureHandle);
bar(trace.entropy, 'FaceColor', [0.20 0.45 0.75]);
ylim([0 8.1]);
xticks(1:4);
xticklabels({'Plain', 'Perm.', 'Stage 1', 'Cipher'});
ylabel('bits/byte');
title('Entropy comparison');
grid on;
sgtitle('Diagnostic address view versus complete synchronized diffusion');

if showStages
    % These are the actual outputs of each complete forwardStage call.
    % They are retained as an optional diagnostic, not a claim that entropy
    % should increase monotonically across reversible stages.
    stageFigure = figure('Name', 'PGCIN-WHCL true stage states', ...
        'Color', 'w', 'NumberTitle', 'off');
    for stage = 1:numel(trace.stageStates)
        subplot(3, 3, stage, 'Parent', stageFigure);
        imshow(trace.stageStates{stage});
        axis image off;
        title(sprintf('Stage %d\nEntropy = %.6f bits/byte', stage, ...
            trace.stageEntropy(stage)), 'Interpreter', 'none');
    end
    sgtitle(stageFigure, ...
        'Optional diagnostic: true synchronized stage states');
end
end
