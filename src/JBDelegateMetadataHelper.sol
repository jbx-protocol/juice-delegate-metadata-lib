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

    /**
     * @notice Add a delegate to an existing metadata
     *
     * @param _idToAdd         The id of the delegate to add
     * @param _dataToAdd       The metadata of the delegate to add
     * @param _originalMetadata The original metadata
     *
     * @return _newMetadata    The new metadata with the delegate added
     */
    function addToMetadata(bytes4 _idToAdd, bytes calldata _dataToAdd, bytes calldata _originalMetadata) public pure returns (bytes memory _newMetadata) {
        return JBDelegateMetadataLib.addToMetadata(_idToAdd, _dataToAdd, _originalMetadata);
    }
}
