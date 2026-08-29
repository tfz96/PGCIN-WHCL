function pgcinwhcl_app
%PGCINWHCL_APP Open the PGCIN-WHCL image file tool.

root = fileparts(mfilename('fullpath'));
addpath(root);
fig = uifigure('Name', 'PGCIN-WHCL Image Tool', ...
    'Position', [100 100 460 250], 'Resize', 'off');
uilabel(fig, 'Text', 'PGCIN-WHCL', ...
    'FontSize', 22, 'FontWeight', 'bold', ...
    'Position', [30 195 300 30]);
uilabel(fig, 'Text', 'Image encryption and decryption', ...
    'Position', [32 170 300 22]);
uibutton(fig, 'push', 'Text', 'Encrypt image', ...
    'Position', [32 112 180 42], 'ButtonPushedFcn', @encryptCallback);
uibutton(fig, 'push', 'Text', 'Decrypt image', ...
    'Position', [248 112 180 42], 'ButtonPushedFcn', @decryptCallback);
status = uilabel(fig, 'Text', 'Ready', ...
    'Position', [32 48 396 26], 'FontColor', [0.2 0.2 0.2]);

    function encryptCallback(~, ~)
        try
            [file, folder] = uigetfile( ...
                {'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', 'Image files'}, ...
                'Select image to encrypt');
            if isequal(file, 0), return; end
            key = requestKey();
            if isempty(key), return; end
            [nonce, cancelled] = requestNonce();
            if cancelled, return; end
            [baseName, ~, ~] = fileparts(file);
            [outFile, outFolder] = uiputfile('*.png', ...
                'Save encrypted image', fullfile(folder, [baseName '_encrypted.png']));
            if isequal(outFile, 0), return; end
            imagePath = fullfile(folder, file);
            outputPath = fullfile(outFolder, outFile);
            [outFolderPart, outName] = fileparts(outputPath);
            metaPath = fullfile(outFolderPart, [outName '_meta.mat']);
            status.Text = 'Encrypting...';
            drawnow;
            image = pgcinwhcl.readImageFile(imagePath);
            cfg = pgcinwhcl.defaultConfig();
            cfg.masterKey = key;
            if ~isempty(nonce)
                cfg = pgcinwhcl.withNonce(cfg, nonce);
            end
            [cipher, meta] = pgcinwhcl.encryptImage(image, cfg);
            imwrite(cipher, outputPath);
            save(metaPath, 'meta', '-mat');
            status.Text = ['Saved: ' outFile];
            uialert(fig, sprintf('Encryption complete.\n\nImage: %s\nMetadata: %s', ...
                outputPath, metaPath), 'Complete', 'Icon', 'success');
        catch exception
            status.Text = 'Encryption failed';
            uialert(fig, exception.message, 'Encryption failed', 'Icon', 'error');
        end
    end

    function decryptCallback(~, ~)
        try
            [cipherFile, cipherFolder] = uigetfile('*.png', 'Select ciphertext image');
            if isequal(cipherFile, 0), return; end
            [metaFile, metaFolder] = uigetfile('*.mat', ...
                'Select matching metadata MAT file', cipherFolder);
            if isequal(metaFile, 0), return; end
            key = requestKey();
            if isempty(key), return; end
            [baseName, ~, ~] = fileparts(cipherFile);
            [outFile, outFolder] = uiputfile('*.png', 'Save decrypted image', ...
                fullfile(cipherFolder, [baseName '_decrypted.png']));
            if isequal(outFile, 0), return; end
            outputPath = fullfile(outFolder, outFile);
            status.Text = 'Decrypting...';
            drawnow;
            pgcinwhcl.decryptFile(fullfile(cipherFolder, cipherFile), ...
                fullfile(metaFolder, metaFile), outputPath, key);
            status.Text = ['Saved: ' outFile];
            uialert(fig, sprintf('Decryption complete.\n\nImage: %s', outputPath), ...
                'Complete', 'Icon', 'success');
        catch exception
            status.Text = 'Decryption failed';
            uialert(fig, exception.message, 'Decryption failed', 'Icon', 'error');
        end
    end

    function key = requestKey()
        answer = inputdlg( ...
            {'Key: 64 hex characters or arbitrary text'}, ...
            'PGCIN-WHCL key', [1 56], {''});
        if isempty(answer)
            key = [];
            return;
        end
        text = strtrim(answer{1});
        if isempty(text)
            error('Key cannot be empty.');
        end
        if ~isempty(regexp(text, '^[0-9A-Fa-f]{64}$', 'once'))
            key = hexToBytes(text);
        else
            key = pgcinwhcl.sha256(uint8(text));
        end
    end

    function [nonce, cancelled] = requestNonce()
        cancelled = false;
        choice = questdlg('Select nonce mode.', 'Nonce', ...
            'Random', 'Fixed hex', 'Cancel', 'Random');
        switch choice
            case 'Random'
                nonce = [];
            case 'Fixed hex'
                answer = inputdlg({'Nonce: 32 hex characters'}, ...
                    'Fixed nonce', [1 56], {''});
                if isempty(answer)
                    cancelled = true;
                    nonce = [];
                    return;
                end
                text = strtrim(answer{1});
                if isempty(regexp(text, '^[0-9A-Fa-f]{32}$', 'once'))
                    error('Fixed nonce must contain exactly 32 hex characters.');
                end
                nonce = hexToBytes(text);
            otherwise
                cancelled = true;
                nonce = [];
        end
    end

    function bytes = hexToBytes(text)
        values = uint8(sscanf(text, '%2x').');
        bytes = values(:).';
    end
end
