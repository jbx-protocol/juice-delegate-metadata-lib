// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @notice Library to parse and create delegate metadata
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
 */
library JBDelegateMetadataLib {
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
    function getMetadata(bytes4 _id, bytes calldata _metadata) internal pure returns (bytes memory _targetMetadata) {
        // Either no metadata or empty one with only one selector (32+4+1)
        if (_metadata.length < MIN_METADATA_LENGTH) return "";

        // Get the first data offset - upcast to avoid overflow (same for other offset)
        uint256 _firstOffset = uint8(_metadata[RESERVED_SIZE + ID_SIZE]);

        // Parse the id's to find _id, stop when next offset == 0 or current = first offset
        for (uint256 _i = RESERVED_SIZE; _metadata[_i + ID_SIZE] != bytes1(0) && _i < _firstOffset * WORD_SIZE; _i += TOTAL_ID_SIZE) {
            uint256 _currentOffset = uint256(uint8(_metadata[_i + ID_SIZE]));

            // _id found?
            if (bytes4(_metadata[_i:_i + ID_SIZE]) == _id) {
                // Are we at the end of the lookup table (either at the start of data's or next offset is 0/in the padding)
                // If not, only return until from this offset to the begining of the next offset
                uint256 _end = (_i + NEXT_DELEGATE_OFFSET >= _firstOffset * WORD_SIZE || _metadata[_i + NEXT_DELEGATE_OFFSET] == 0)
                    ? _metadata.length
                    : uint256(uint8(_metadata[_i + NEXT_DELEGATE_OFFSET])) * WORD_SIZE;

                return _metadata[_currentOffset * WORD_SIZE:_end];
            }
        }
    }
}
