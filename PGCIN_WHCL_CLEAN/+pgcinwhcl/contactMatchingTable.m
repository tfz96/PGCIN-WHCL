function [wordsU, wordsV, contactsU, contactsV] = ...
    contactMatchingTable(tileSize)
%CONTACTMATCHINGTABLE Cache every carrier-completed contact involution.

persistent cachedTileSize cachedWordsU cachedWordsV cachedContactsU cachedContactsV;
if isempty(cachedTileSize) || cachedTileSize ~= tileSize
    pixelCount = tileSize ^ 2;
    contactCount = pixelCount - 1;
    pairCount = pixelCount / 2;
    inverseTwo = (contactCount + 1) / 2;
    cachedWordsU = zeros(pairCount, contactCount, 'uint16');
    cachedWordsV = zeros(pairCount, contactCount, 'uint16');
    cachedContactsU = zeros(pairCount, contactCount, 'uint16');
    cachedContactsV = zeros(pairCount, contactCount, 'uint16');
    for center = 0:contactCount - 1
        fixedContact = mod(center * inverseTwo, contactCount);
        cachedWordsU(1, center + 1) = 0;
        cachedWordsV(1, center + 1) = uint16(fixedContact + 1);
        cachedContactsU(1, center + 1) = uint16(fixedContact);
        cachedContactsV(1, center + 1) = uint16(fixedContact);
        writeIndex = 2;
        for contact = 0:contactCount - 1
            mate = mod(center - contact, contactCount);
            if contact < mate
                cachedWordsU(writeIndex, center + 1) = uint16(contact + 1);
                cachedWordsV(writeIndex, center + 1) = uint16(mate + 1);
                cachedContactsU(writeIndex, center + 1) = uint16(contact);
                cachedContactsV(writeIndex, center + 1) = uint16(mate);
                writeIndex = writeIndex + 1;
            end
        end
        assert(writeIndex == pairCount + 1, ...
            'Contact involution did not form a perfect matching.');
    end
    cachedTileSize = tileSize;
end
wordsU = cachedWordsU;
wordsV = cachedWordsV;
contactsU = cachedContactsU;
contactsV = cachedContactsV;
end

