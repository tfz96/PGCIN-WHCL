function value = imageEntropy(image)
%IMAGEENTROPY Compute Shannon entropy over all RGB byte values.

validateattributes(image, {'uint8'}, {'nonempty'});
counts = accumarray(double(image(:)) + 1, 1, [256 1]);
probability = counts / numel(image);
probability = probability(probability > 0);
value = -sum(probability .* log2(probability));
end
