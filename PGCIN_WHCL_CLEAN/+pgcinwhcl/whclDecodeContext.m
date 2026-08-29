function meshClock = whclDecodeContext(params, sunTooth, planetTooth, ...
    ringTooth, phaseClock)
%WHCLDECODECONTEXT Recover the mesh clock from its four CRT coordinates.

residues = {sunTooth, planetTooth, ringTooth, phaseClock};
moduli = uint64([params.Zs, params.Zp, params.Zr, params.phaseModulus]);
referenceSize = size(sunTooth);
for coordinate = 1:numel(residues)
    value = residues{coordinate};
    validateattributes(value, {'numeric'}, ...
        {'real', 'finite', 'integer', 'nonnegative'});
    if ~isequal(size(value), referenceSize)
        error('pgcinwhcl:CoordinateSizeMismatch', ...
            'All WHCL coordinates must have identical sizes.');
    end
    value = uint64(value);
    if any(value >= moduli(coordinate), 'all')
        error('pgcinwhcl:CoordinateOutOfRange', ...
            'A WHCL coordinate lies outside its residue domain.');
    end
    residues{coordinate} = value;
end

period = uint64(params.period);
meshClock = zeros(referenceSize, 'uint64');
for coordinate = 1:numel(moduli)
    partialPeriod = idivide(period, moduli(coordinate), 'floor');
    inverse = modularInverse(mod(partialPeriod, moduli(coordinate)), ...
        moduli(coordinate));
    coefficient = mod(partialPeriod .* inverse, period);
    term = mod(coefficient .* residues{coordinate}, period);
    meshClock = mod(meshClock + term, period);
end
end

function inverse = modularInverse(value, modulus)
[divisor, coefficient] = gcd(double(value), double(modulus));
if divisor ~= 1
    error('pgcinwhcl:NonCoprimeModuli', ...
        'WHCL CRT moduli must be pairwise coprime.');
end
inverse = uint64(mod(coefficient, double(modulus)));
end
