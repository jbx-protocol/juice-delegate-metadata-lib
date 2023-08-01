// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {JBDelegateMetadataLib} from "./JBDelegateMetadataLib.sol";

/**
 * @notice Contract to create Juicebox delegate metadata
 *
 * @dev    Metadata are built as:
 *         - 32B of reserved space for the protocol
 *         - a lookup table `delegateId: offset`, defining the offset of the metadata for each delegate.
 *           The offset fits 1 bytes, the ID 4 bytes. This table is padded to 32B.
 *         - the metadata for each delegate, padded to 32B each
 *
 *            +-----------------------+ offset: 0
 *            | 32B reserved          |
 *            +-----------------------+ offset: 1 = end of first 32B
 *            | (delegate1 ID,offset1)|
 *            | (delegate2 ID,offset2)|
 *            | 0's padding           |
 *            +-----------------------+ offset: offset1 = 1 + number of words taken by the padded table
 *            | delegate 1 metadata1  |
 *            | 0's padding           |
 *            +-----------------------+ offset: offset2 = offset1 + number of words taken by the metadata1
 *            | delegate 2 metadata2  |
 *            | 0's padding           |
 *            +-----------------------+
 *
 *         This contract is intended to expose the library functions as a helper for frontends.
 */
contract JBDelegateMetadataHelper {
    // The various sizes used in bytes.
    uint256 constant ID_SIZE = 4;
    uint256 constant ID_OFFSET_SIZE = 1;
    uint256 constant WORD_SIZE = 32;

    // The size that a delegate takes in the lookup table (Identifier + Offset).
    uint256 constant TOTAL_ID_SIZE = ID_SIZE + ID_OFFSET_SIZE;

    // The amount of bytes to go forward to get to the offset of the next delegate (aka. the end of the offset of the current delegate).
    uint256 constant NEXT_DELEGATE_OFFSET = TOTAL_ID_SIZE + ID_SIZE;

    // 1 word (32B) is reserved for the protocol .
    uint256 constant RESERVED_SIZE = 1 * WORD_SIZE;
    uint256 constant MIN_METADATA_LENGTH = RESERVED_SIZE + ID_SIZE + ID_OFFSET_SIZE;

    /**
     * @notice Parse the metadata to find the metadata for a specific delegate
     *
     * @dev    Returns an empty bytes if no metadata is found
     *
     * @param  _id             The delegate id to find
     * @param  _metadata       The metadata to parse
     *
     * @return _targetMetadata The metadata for the delegate
     */
    function getMetadata(bytes4 _id, bytes calldata _metadata) public pure returns (bytes memory _targetMetadata) {
        return JBDelegateMetadataLib.getMetadata(_id, _metadata);
    }

    /**
     * @notice Create the metadatas for a list of delegates
     *
     * @dev    Intended for offchain use
     *
     * @param _ids             The list of delegate ids
     * @param _metadatas       The list of metadatas
     *
     * @return _metadata       The packed metadata for the delegates
     */
    function createMetadata(bytes4[] calldata _ids, bytes[] calldata _metadatas)
        public
        pure
        returns (bytes memory _metadata)
    {
        // add a first empty 32B for the protocol reserved word
        _metadata = abi.encodePacked(bytes32(0));

        // first offset for the data is after the first reserved word...
        uint256 _offset = 1;

        // ... and after the id/offset lookup table, rounding up to 32 bytes words if not a multiple
        _offset += ((_ids.length * TOTAL_ID_SIZE) - 1) / WORD_SIZE + 1;

        // For each id, add it to the lookup table with the next free offset, then increment the offset by the data length (rounded up)
        for (uint256 _i; _i < _ids.length; _i++) {
            _metadata = abi.encodePacked(_metadata, _ids[_i], bytes1(uint8(_offset)));
            _offset += _metadatas[_i].length / WORD_SIZE;

            // Overflowing a bytes1?
            require(_offset <= 2 ** 8, "JBXDelegateMetadataLib: metadata too long");
        }

        // Pad the table to a multiple of 32B
        uint256 _paddedLength =
            _metadata.length % WORD_SIZE == 0 ? _metadata.length : (_metadata.length / WORD_SIZE + 1) * WORD_SIZE;
        assembly {
            mstore(_metadata, _paddedLength)
        }

        // Add each metadata to the array, each padded to 32 bytes
        for (uint256 _i; _i < _metadatas.length; _i++) {
            _metadata = abi.encodePacked(_metadata, _metadatas[_i]);
            _paddedLength =
                _metadata.length % WORD_SIZE == 0 ? _metadata.length : (_metadata.length / WORD_SIZE + 1) * WORD_SIZE;

            assembly {
                mstore(_metadata, _paddedLength)
            }
        }
    }

    function addToMetadata(bytes4 _idToAdd, bytes calldata _dataToAdd, bytes calldata _originalMetadata) public pure returns (bytes memory _newMetadata) {
        // return JBDelegateMetadataLib.addToMetadata(_idToAdd, _dataToAdd, _originalMetadata);

        // Get the first data offset - upcast to avoid overflow (same for other offset)
        uint256 _firstOffset = uint8(_originalMetadata[RESERVED_SIZE + ID_SIZE]);

        // Move back to the beginning of the previous word (ie the last word of the table, as it can be padded)
        uint256 _lastWordOfTable = _firstOffset - 1;

        // The last offset stored in the table
        uint256 _lastOffset;

        uint256 _lastOffsetIndex;

        // The number of words taken by the last data stored
        uint256 _numberOfWordslastData;

        // Iterate to find the last entry of the table, _lastOffset - we start from the end as the first value encountered
        // will be the last offset
        for(uint256 _i = _firstOffset * WORD_SIZE - 1; _i > _lastWordOfTable * WORD_SIZE - 1; _i -= 1) {

            // If the byte is not 0, this is the last offset
            if (_originalMetadata[_i] != 0) {
                _lastOffset = uint8(_originalMetadata[_i]);
                _lastOffsetIndex = _i;

                // No rounding as this should be padded to 32B
                _numberOfWordslastData = (_originalMetadata.length - _lastOffset * WORD_SIZE) / WORD_SIZE;

                // Copy the reserved word and the table and remove the previous padding
                _newMetadata = _originalMetadata[0 : _lastOffsetIndex + 1];

                // Check if the new 5B are still fitting in this word
                if(_i + 5 >= _firstOffset * WORD_SIZE) {
                    // Increment every offset by 1 (as the table now takes one more word)
                    for (uint256 _j = RESERVED_SIZE + ID_SIZE; _j < _lastOffsetIndex + 1; _j += TOTAL_ID_SIZE) {
                        _newMetadata[_j] = bytes1(uint8(_originalMetadata[_j]) + 1);
                    }

                    _lastOffset++;
                }

                break;
            }
        }

        // Add the new entry after the last entry of the table, at _lastOffsetIndex

        // last offset + (length - lastoffsetIndex)
        _newMetadata = abi.encodePacked(_newMetadata, _idToAdd, bytes1(uint8(_lastOffset + _numberOfWordslastData)));

        // Pad as neede
        uint256 _paddedLength =
            _newMetadata.length % WORD_SIZE == 0 ? _newMetadata.length : (_newMetadata.length / WORD_SIZE + 1) * WORD_SIZE;
        assembly {
            mstore(_newMetadata, _paddedLength)
        }

        // Add existing data at the end
        _newMetadata = abi.encodePacked(_newMetadata, _originalMetadata[_firstOffset * WORD_SIZE : _originalMetadata.length]);

        // Pad as needed
        _paddedLength =
            _newMetadata.length % WORD_SIZE == 0 ? _newMetadata.length : (_newMetadata.length / WORD_SIZE + 1) * WORD_SIZE;

        assembly {
            mstore(_newMetadata, _paddedLength)
        }

        // Append new data at the end
        _newMetadata = abi.encodePacked(_newMetadata, _dataToAdd);

        // Pad again again as needed
        _paddedLength =
            _newMetadata.length % WORD_SIZE == 0 ? _newMetadata.length : (_newMetadata.length / WORD_SIZE + 1) * WORD_SIZE;

        assembly {
            mstore(_newMetadata, _paddedLength)
        }
    }
}
