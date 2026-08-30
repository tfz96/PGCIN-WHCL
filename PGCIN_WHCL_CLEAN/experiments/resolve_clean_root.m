function cleanRoot = resolve_clean_root(experimentRoot)
%RESOLVE_CLEAN_ROOT Locate the production MATLAB package in this release.
cleanRoot = fileparts(experimentRoot);
assert(isfolder(cleanRoot), 'Production package not found: %s', cleanRoot);
end
