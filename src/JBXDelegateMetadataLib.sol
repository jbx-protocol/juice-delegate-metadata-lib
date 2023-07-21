// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @notice Library to parse and create delegate metadata
 *
 * @dev    Metadata are defined as:
 *         - 32B of reserved space for the protocol
 *         - an array of tuples (delegateId, offset), defining the offset of the metadata for each delegate.
 *           The offset fits 1 bytes, the ID 4 bytes. This array is padded to 32B.
 *         - the metadata for each delegate, padded to 32B each
 *
 *            +-----------------------+ offset: 0
 *            | 32B reserved          |
 *            +-----------------------+ offset: 1 = end of first 32B
 *            | (delegate1 ID,offset1)|
 *            | (delegate2 ID,offset2)|
 *            | 0's padding           |
 *            +-----------------------+ offset: offset1 = 1 + number of words taken by the padded array
 *            | delegate 1 metadata1  |
 *            | 0's padding           |
 *            +-----------------------+ offset: offset2 = offset1 + number of words taken by the metadata1
 *            | delegate 2 metadata2  |
 *            | 0's padding           |
 *            +-----------------------+
 */
library JBXDelegateMetadataLib {
event Test(uint);
event Test(bytes4);
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
    function getMetadata(bytes4 _id, bytes calldata _metadata) internal returns(bytes memory _targetMetadata) {
        // Either no metadata or empty one with only one selector (32+4+1)
        if(_metadata.length < 37) return '';

        // Get the first data offset - upcast to avoid overflow (same for other offset)
        uint256 _firstOffset = uint8(_metadata[32+4]);

        // Parse the id's to find _id, stop when next offset == 0 or current = first offset
        for(uint256 _i = 32; _metadata[_i+4] != bytes1(0) && _i < _firstOffset * 32; _i += 5) {

            uint256 _currentOffset = uint256(uint8(_metadata[_i + 4]));

            // _id found?
            if(bytes4(_metadata[_i:_i+4]) == _id) {

                // Are we at the end of the ids/offset array (either at the start of data's or next offset is 0/in the padding)
                if(_i + 5 == _firstOffset * 32 || _metadata[_i + 9] == 0)
                    return _metadata[_currentOffset * 32 : _metadata.length];

                // If not, only return until from this offset to the begining of the next offset
                return _metadata[_currentOffset * 32 : uint256(uint8(_metadata[_i + 9])) * 32];
            }
        }
        emit Test(69696969);
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
    function createMetadata(bytes4[] calldata _ids, bytes[] calldata _metadatas) internal pure returns(bytes memory _metadata) {
        // add a first empty 32B
        _metadata = abi.encodePacked(bytes32(0));

        // first offset for the data is after the first reserved word and after the array, rounding up to 32 bytes words
        uint256 _offset = 1 + _ids.length * 5 / 32 + 1;

        // For each id, add it to the array with the next free offset, then increment the offset by the data length (rounded up)
        for(uint256 _i; _i < _ids.length; _i++) {
            _metadata = abi.encodePacked(_metadata, _ids[_i], bytes1(uint8(_offset)));
            _offset += _metadatas[_i].length / 32;

            // Overflowing a bytes1?
            require(_offset <= 2**8, 'JBXDelegateMetadataLib: metadata too long');
        }
        
        // Pad the array to a multiple of 32B
        uint256 _paddedLength = _metadata.length % 32 == 0 ?_metadata.length : (_metadata.length / 32 + 1) * 32;
        assembly {
            mstore(_metadata, _paddedLength)
        }

        // Add each metadata to the array, each padded to 32 bytes
        for(uint256 _i; _i < _metadatas.length; _i++) {
            _metadata = abi.encodePacked(_metadata, _metadatas[_i]);
            _paddedLength = _metadata.length % 32 == 0 ?_metadata.length : (_metadata.length / 32 + 1) * 32;
            
            assembly {
                mstore(_metadata, _paddedLength)
            }
        }
    }
}