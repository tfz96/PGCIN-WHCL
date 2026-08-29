function output = addMod256(varargin)
%ADDMOD256 Add byte arrays modulo 256.

sumValue = uint16(varargin{1});
for index = 2:nargin
    sumValue = sumValue + uint16(varargin{index});
end
output = uint8(mod(sumValue, 256));
end

