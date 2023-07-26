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
    function getMetadata(bytes4 _id, bytes calldata _metadata) external pure returns (bytes memory _targetMetadata) {
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
        external
        pure
        returns (bytes memory _metadata)
    {
        return JBDelegateMetadataLib.createMetadata(_ids, _metadatas);
    }
}
