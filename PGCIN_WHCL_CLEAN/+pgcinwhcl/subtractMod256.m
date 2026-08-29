function output = subtractMod256(minuend, varargin)
%SUBTRACTMOD256 Subtract byte arrays modulo 256.

value = int16(minuend);
for index = 1:numel(varargin)
    value = value - int16(varargin{index});
end
output = uint8(mod(value, 256));
end

