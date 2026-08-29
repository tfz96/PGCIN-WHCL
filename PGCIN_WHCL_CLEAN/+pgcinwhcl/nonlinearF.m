function output = nonlinearF(input, key)
%NONLINEARF Apply a keyed AES S-box lookup.

indices = double(bitxor(input, key)) + 1;
box = pgcinwhcl.aesSbox();
output = reshape(box(indices), size(input));
end

