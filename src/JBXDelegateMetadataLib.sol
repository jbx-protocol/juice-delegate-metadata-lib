// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library JBXDelegateMetadataLib {

    // Parse - onchain, so in Yul, maybe will convert to etkAsm later
    function getMetadata(bytes4 _id, bytes calldata _metadata) internal pure returns(bytes memory _targetMetadata) {
        // Either no metadata or empty one with only one selector (32+4+1)
        if(_metadata.length < 37) return new bytes(0);

        assembly {
            // Current calldata byte pointer
            let _current := 32

            // End of the id/offset: take the first offset
            let _end := and(calldataload(add(_current, 5)), 0xFF)

            // // Iterate over every ID:
            // for {  } lt(_current, _end) { _current := add(_current, 5) }
            // {   
            //     // Load the current word and extract the ID and the offset
            //     let _currentWord := calldataload(_current)
            //     let _currentId := and(_currentWord, 0xFFFFFFFF)
            //     let _currentOffset := and(shr(32, _currentWord), 0xFF)

            //     // If we found the ID, copy the metadata
            //     if eq(_currentId, _id) {
            //         // If it's the last one, copy until the end
            //         switch eq(add(_current, 5), _end)
            //         case true {
            //             // Start at the free mem pointer
            //             _targetMetadata := mload(0x40)

            //             let _dataSize := sub(calldatasize(), _currentOffset)

            //             mstore(0x0, _dataSize)

            //             calldatacopy(0x20, _currentOffset, _dataSize)

            //             return(0x0, add(_dataSize, 32))
            //         }
            //         // Otherwise, copy until the next offset
            //         default {
            //             let _nextOffset := and(shr(32, calldataload(add(_current, 5))), 0xFF)
            //             _targetMetadata := mload(0x40)
            //             mstore(0x40, add(_targetMetadata, sub(_nextOffset, add(_currentOffset, 1))))
            //             calldatacopy(_targetMetadata, add(_currentOffset, 1), sub(_nextOffset, add(_currentOffset, 1)))

            //         }
            //     }                
            // }

            // // If we didn't find the ID, return an empty array
            // if eq(_targetMetadata, 0) {
            //     _targetMetadata := mload(0x40)
            //     mstore(0x40, add(_targetMetadata, 32))
            //     mstore(_targetMetadata, 0)
            // }
        }
        

    }

    // Pack dem data (offchain helper)
    function createMetadata(bytes4[] calldata _ids, bytes[] calldata _metadatas) internal pure returns(bytes memory _metadata) {

    }
}

/**
4 bytes
+ 1 bytes for start offset

with _metadata CALLDATA so we can slice it:)


 */