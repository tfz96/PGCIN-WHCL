function context = whclContexts(params, tileIndex, stageIndex, ...
    basePhase, omegaC, meshDrive)
%WHCLCONTEXTS Generate directly indexed Willis-Hunting contexts.

validateParams(params);
validateattributes(tileIndex, {'numeric'}, ...
    {'real', 'finite', 'integer', 'nonnegative'});
validateattributes(stageIndex, {'numeric'}, ...
    {'real', 'finite', 'integer', 'nonnegative'});
if ~isequal(size(tileIndex), size(stageIndex))
    error('pgcinwhcl:IndexSizeMismatch', ...
        'tileIndex and stageIndex must have identical sizes.');
end

tileIndex = uint64(tileIndex);
stageIndex = uint64(stageIndex);
stageCount = uint64(params.stageCount);
if any(tileIndex >= params.maxTileCount, 'all') ...
        || (params.tileCount > 0 && any(tileIndex >= params.tileCount, 'all'))
    error('pgcinwhcl:InvalidTileIndex', ...
        'tileIndex lies outside the declared or supported session domain.');
end
if any(stageIndex >= stageCount, 'all')
    error('pgcinwhcl:InvalidStageIndex', ...
        'stageIndex must be less than the WHCL stage count.');
end

globalIndex = tileIndex .* stageCount + stageIndex;
if any(globalIndex >= params.period, 'all')
    error('pgcinwhcl:ContextCapacityExceeded', ...
        'The requested context index reaches or exceeds the WHCL period.');
end

basePhase = expandByteInput(basePhase, size(globalIndex), 'basePhase');
omegaC = expandByteInput(omegaC, size(globalIndex), 'omegaC');
meshDrive = expandByteInput(meshDrive, size(globalIndex), 'meshDrive');
if any(mod(meshDrive, uint64(2)) ~= 1, 'all')
    error('pgcinwhcl:EvenMeshDrive', ...
        'meshDrive must be odd to certify full relative-phase period.');
end

period = params.period;
meshClock = mod(params.origin + mod(params.stride .* globalIndex, period), ...
    period);
Zs = uint64(params.Zs);
Zr = uint64(params.Zr);
phaseModulus = uint64(params.phaseModulus);
omegaS = mod(omegaC + Zr .* meshDrive, phaseModulus);
omegaR = mod(omegaC + phaseModulus ...
    - mod(Zs .* meshDrive, phaseModulus), phaseModulus);
phiS = mod(basePhase + omegaS .* meshClock, phaseModulus);
phiR = mod(basePhase + omegaR .* meshClock, phaseModulus);
phiC = mod(basePhase + omegaC .* meshClock, phaseModulus);

velocityResidual = mod(int64(params.Zs) ...
    .* (int64(omegaS) - int64(omegaC)) ...
    + int64(params.Zr) .* (int64(omegaR) - int64(omegaC)), 256);
phaseResidual = mod(int64(params.Zs) ...
    .* (int64(phiS) - int64(phiC)) ...
    + int64(params.Zr) .* (int64(phiR) - int64(phiC)), 256);

context = struct();
context.globalIndex = globalIndex;
context.meshClock = meshClock;
context.sunTooth = uint16(mod(meshClock, uint64(params.Zs)));
context.planetTooth = uint16(mod(meshClock, uint64(params.Zp)));
context.ringTooth = uint16(mod(meshClock, uint64(params.Zr)));
context.phaseClock = uint8(mod(meshClock, phaseModulus));
context.omegaS = uint8(omegaS);
context.omegaR = uint8(omegaR);
context.omegaC = uint8(omegaC);
context.phiS = uint8(phiS);
context.phiR = uint8(phiR);
context.phiC = uint8(phiC);
context.velocityWillisResidual = velocityResidual;
context.phaseWillisResidual = phaseResidual;
end

function values = expandByteInput(values, outputSize, argumentName)
validateattributes(values, {'numeric'}, ...
    {'real', 'finite', 'integer', 'nonnegative', '<=', 255}, ...
    mfilename, argumentName);
if isscalar(values)
    values = repmat(uint64(values), outputSize);
elseif isequal(size(values), outputSize)
    values = uint64(values);
else
    error('pgcinwhcl:ControlSizeMismatch', ...
        '%s must be scalar or match the context index size.', argumentName);
end
end

function validateParams(params)
required = {'stageCount', 'Zs', 'Zp', 'Zr', 'phaseModulus', ...
    'period', 'origin', 'stride', 'tileCount', 'maxTileCount'};
if ~isstruct(params) || ~all(isfield(params, required))
    error('pgcinwhcl:InvalidParameters', ...
        'params must be produced by pgcinwhcl.whclParameters.');
end
end
