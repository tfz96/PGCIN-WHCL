function states = chdm4States(cfg, count)
%CHDM4STATES Execute the selected 4D-CHDM recurrence.

validateattributes(count, {'numeric'}, {'scalar', 'integer', 'positive'});
validateattributes(cfg.chaosInitialState, {'double'}, ...
    {'vector', 'numel', 4, 'finite'});
state = reshape(cfg.chaosInitialState, 1, 4);
parameter = [30, 20, 12, 14.5];
modulus = [1, 2, 3, 4];
assert(all(state > 0) && all(state < modulus), ...
    '4D-CHDM initial states must lie inside their open modulus domains.');
states = zeros(count, 4);
writeIndex = 0;
for iteration = 1:cfg.burnIn + count
    x1 = state(1);
    x2 = state(2);
    x3 = state(3);
    x4 = state(4);
    state(1) = mod(parameter(1) * sin(x1) ...
        + 7 * x2 * (x3 - x4) ^ 2 ...
        + 3 * x3 * x4 ^ 2 + 4 * x4 + 0.4, modulus(1));
    state(2) = mod(parameter(2) * (x2 + 10) ^ 3 ...
        + 5 * cos(x3) + 4 * x3 * x4 + 0.6, modulus(2));
    state(3) = mod(parameter(3) * (x3 + 8) ^ 2 ...
        + x4 + 0.8, modulus(3));
    state(4) = mod(parameter(4) * (x4 + 6) ^ 2 + 1, modulus(4));
    if iteration > cfg.burnIn
        writeIndex = writeIndex + 1;
        states(writeIndex, :) = state;
    end
end
end
