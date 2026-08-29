function output = rgbLiftInverse(input, keys)
%RGBLIFTINVERSE Invert nonlinear triangular RGB lifting.

Rmix = input(:, 1);
Gmix = input(:, 2);
Bmix = input(:, 3);
B = pgcinwhcl.subtractMod256(Bmix, pgcinwhcl.nonlinearF(Rmix, keys(:, 3)));
G = pgcinwhcl.subtractMod256(Gmix, pgcinwhcl.nonlinearF(B, keys(:, 2)));
R = pgcinwhcl.subtractMod256(Rmix, pgcinwhcl.nonlinearF(G, keys(:, 1)));
output = [R, G, B];
end
