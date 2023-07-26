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
        if (_metadata.length < 37) return "";

        // Get the first data offset - upcast to avoid overflow (same for other offset)
        uint256 _firstOffset = uint8(_metadata[32 + 4]);

        // Parse the id's to find _id, stop when next offset == 0 or current = first offset
        for (uint256 _i = 32; _metadata[_i + 4] != bytes1(0) && _i < _firstOffset * 32; _i += 5) {
            uint256 _currentOffset = uint256(uint8(_metadata[_i + 4]));

            // _id found?
            if (bytes4(_metadata[_i:_i + 4]) == _id) {
                // Are we at the end of the lookup table (either at the start of data's or next offset is 0/in the padding)
                // If not, only return until from this offset to the begining of the next offset
                uint256 _end = (_i + 9 >= _firstOffset * 32 || _metadata[_i + 9] == 0)
                    ? _metadata.length
                    : uint256(uint8(_metadata[_i + 9])) * 32;

                return _metadata[_currentOffset * 32:_end];
            }
        }
    }
}
