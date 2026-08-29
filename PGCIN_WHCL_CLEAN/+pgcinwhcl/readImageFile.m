function image = readImageFile(path)
%READIMAGEFILE Read a grayscale or RGB image as RGB uint8.

validateattributes(path, {'char', 'string'}, {'scalartext'});
[image, colorMap] = imread(char(path));
if ~isempty(colorMap)
    image = im2uint8(ind2rgb(image, colorMap));
elseif ismatrix(image)
    image = repmat(image, 1, 1, 3);
elseif size(image, 3) > 3
    image = image(:, :, 1:3);
end
if ~isa(image, 'uint8')
    image = im2uint8(image);
end
assert(ndims(image) == 3 && size(image, 3) == 3, ...
    'The selected file must contain a grayscale or RGB image.');
end
