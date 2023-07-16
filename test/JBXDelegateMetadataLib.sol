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
            // -- offset 0 --
            bytes32(uint256(type(uint256).max)),    // First 32B reserved
            
            // -- offset 1 --
            bytes4(0x11111111), // First delegate id
            bytes1(uint8(2)),       // First delegate offset == 2
            _id,                     // Second delegate id == _id
            bytes1(uint8(3)),       // Second delegate offset

            // -- offset 2 --
            bytes32(0),   // First delegate metadata
            
            // -- offset 3 --
            bytes32(uint256(type(uint256).max))   // Second delegate metadata
        );

        bytes memory _out = parser.getMetadata(_id, _metadata);
        emit log_bytes(_out);
    }

}

/**
 * @dev Harness to deploy and test JBXDelegateMetadataLib
 */
contract ForTest_JBXDelegateMetadataLib {
    function getMetadata(bytes4 _delegateId, bytes calldata _metadata) external pure returns(bytes memory _targetMetadata) {
        // Either no metadata or empty one with only one selector (32+4+1)
        if(_metadata.length < 37) revert(); //return bytes1(0);

        // Parse the id's -> stop when next offset == 0 or current = first offset
        uint256 _firstOffset;

        for(uint256 _i; _metadata[_i + 4] != bytes1(0) && uint256(bytes32(_metadata[_i + 4])) != _firstOffset; _i += 4) {
            _firstOffset = uint256(bytes32(_metadata[_i + 4]));

            // id found?
            if(bytes4(_metadata[_i]) == _delegateId) {
                // End of the calldata (either start of data's or next offset is 0)
                if(_i + 5 > _firstOffset || _metadata[_i + 9] == 0) {
                    return _metadata[uint256(bytes32(_metadata[_i + 4])) : _metadata.length];
                }

                // If not, only return until next offset
                return _metadata[uint256(bytes32(_metadata[_i + 4])) : uint256(bytes32(_metadata[_i + 9]))];
            }
        }
        

    }

    /**
        bytes4 id
        bytes1 offset
        (...)
        last part == 0's

        bytes xxx - metadata
     */

    // function createMetadata(bytes4[] calldata _ids, bytes[] calldata _metadatas) external pure returns(bytes memory _metadata) {
    //     return JBXDelegateMetadataLib.createMetadata(_ids, _metadatas);
    // }

}