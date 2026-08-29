function selected = selectGearState(state, indices)
%SELECTGEARSTATE Select matching rows from every gear-state field.

selected = struct();
names = fieldnames(state);
for fieldIndex = 1:numel(names)
    name = names{fieldIndex};
    selected.(name) = state.(name)(indices, :);
end
end
