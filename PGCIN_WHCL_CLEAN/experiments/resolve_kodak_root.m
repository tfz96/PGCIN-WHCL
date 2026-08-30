function kodakRoot = resolve_kodak_root(projectRoot)
%RESOLVE_KODAK_ROOT Locate the user-provided Kodak-24 corpus.
kodakRoot = fullfile(projectRoot, 'matlab', 'data', 'kodak');
assert(isfolder(kodakRoot), 'Kodak-24 directory not found: %s', kodakRoot);
end
