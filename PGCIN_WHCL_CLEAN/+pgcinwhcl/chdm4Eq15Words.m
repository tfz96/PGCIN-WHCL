function words = chdm4Eq15Words(states)
%CHDM4EQ15WORDS Apply the source paper's Eq. (15) to CHDM state rows.

validateattributes(states, {'double'}, {'2d', 'ncols', 4, 'finite'});
scale = 1e9;
halfWordModulus = 2 ^ 16;
first = mod(floor((states(:, 1) + 3) * scale), halfWordModulus);
second = mod(floor((states(:, 2) + 3) * scale), halfWordModulus);
words = bitor(bitshift(uint32(first), 16), uint32(second));
end
