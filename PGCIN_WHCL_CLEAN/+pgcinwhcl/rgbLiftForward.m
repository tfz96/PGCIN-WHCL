function output = rgbLiftForward(input, keys)
%RGBLIFTFORWARD Apply nonlinear triangular RGB lifting.

R = input(:, 1);
G = input(:, 2);
B = input(:, 3);
Rmix = pgcinwhcl.addMod256(R, pgcinwhcl.nonlinearF(G, keys(:, 1)));
Gmix = pgcinwhcl.addMod256(G, pgcinwhcl.nonlinearF(B, keys(:, 2)));
Bmix = pgcinwhcl.addMod256(B, pgcinwhcl.nonlinearF(Rmix, keys(:, 3)));
output = [Rmix, Gmix, Bmix];
end
