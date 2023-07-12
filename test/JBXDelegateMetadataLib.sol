// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// import "../src/JBXDelegateMetadataLib.sol";

contract JBXDelegateMetadataLib_Test is Test {
    ForTest_JBXDelegateMetadataLib parser;

    function setUp() external {
        parser = new ForTest_JBXDelegateMetadataLib();
    }

    function test_parse() external {
        bytes4 _id = bytes4(0x33333333);

        bytes memory _metadata = abi.encodePacked(
            bytes32(uint256(type(uint256).max)),    // First 32B reserved
            
            bytes4(0x11111111), // First delegate id == 2
            bytes1(uint8(132)),       // First delegate offset:
            // 4B function selector
            // 32B _id arg
            // 32B pointer to the bytes
            // 32B bytes length
            // 32B reserved
            // Then start the actual metadata -> offset are shifted by 132

            _id,                     // Second delegate id == _id
            bytes1(uint8(132+32)),       // Second delegate offset (first offset + length of first metadata)

            bytes32(0),   // First delegate metadata
            bytes32(uint256(type(uint256).max))   // Second delegate metadata
        );

        // bytes memory _out = parser.getMetadata(_id, _metadata);
        // emit log_bytes(_out);
        bytes32 _out = parser.getMetadata(_id, _metadata);
        emit log_bytes32(_out);
    }

}

/**
 * @dev Harness to deploy and test JBXDelegateMetadataLib
 */
contract ForTest_JBXDelegateMetadataLib {
    function getMetadata(bytes4 _delegateId, bytes calldata _metadata) external pure returns(bytes32 _targetMetadata) {
        // Either no metadata or empty one with only one selector (32+4+1)
        if(_metadata.length < 37) revert(); //return bytes1(0);

        assembly {
            // Store the first arg, the target id
            let _id := and(shr(224, calldataload(4)), 0xFFFFFFFF)

            // Current calldata byte pointer
            let _current := 132 // function  selector 4B + _id one word + bytes pointer (0x40) 1 word + bytes length 1 word + reserved for protocol 1 word

            // End of the id/offset: take the first offset
            let _end := shr(248, calldataload(add(_current, 4)))

            // Iterate over every ID:
            for {  } lt(_current, _end) { _current := add(_current, 5) }
            {   
                // Load the current word and extract the ID and the offset
                let _currentWord := calldataload(_current)
                let _currentId := and(shr(224, _currentWord), 0xFFFFFFFF)
                let _currentOffset := and(shr(216, _currentWord), 0xFF)

                // If we found the ID, copy the metadata
                if eq(_currentId, _id) {
                        _targetMetadata := _end

                    // If it's the last one, copy until the end
                    switch eq(add(_current, 5), _end)
                    case true {
                        // let _dataSize := sub(mul(calldatasize(), 8), add(_currentOffset, 132))

                        // mstore(0x0, _dataSize)

                        // calldatacopy(0x20, add(_currentOffset, 132), _dataSize)

                        // return(0x0, add(_dataSize, 32))
                    }
                    // Otherwise, copy until the next offset
                    // default {
                    //     let _nextOffset := and(shr(32, calldataload(add(_current, 5))), 0xFF)
                    //     _targetMetadata := mload(0x40)
                    //     mstore(0x40, add(_targetMetadata, sub(_nextOffset, add(_currentOffset, 1))))
                    //     calldatacopy(_targetMetadata, add(_currentOffset, 1), sub(_nextOffset, add(_currentOffset, 1)))
                    // }
                }                
            }

            // // If we didn't find the ID, return an empty array
            // if eq(_targetMetadata, 0) {
            //     _targetMetadata := 0
            // }
        }
        

    }

    // function createMetadata(bytes4[] calldata _ids, bytes[] calldata _metadatas) external pure returns(bytes memory _metadata) {
    //     return JBXDelegateMetadataLib.createMetadata(_ids, _metadatas);
    // }

}