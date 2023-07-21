// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/JBXDelegateMetadataLib.sol";

contract JBXDelegateMetadataLib_Test is Test {
    ForTest_JBXDelegateMetadataLib parser;

    function setUp() external {
        parser = new ForTest_JBXDelegateMetadataLib();
    }

    function test_parse() external {
        bytes4 _id1 = bytes4(0x11111111);
        bytes4 _id2 = bytes4(0x33333333);

        uint256 _data1 = 69696969;
        bytes memory _data2 = new bytes(50);

        bytes memory _metadata = abi.encodePacked(
            // -- offset 0 --
            bytes32(uint256(type(uint256).max)),    // First 32B reserved
            
            // -- offset 1 --
            _id1,                   // First delegate id
            uint8(2),               // First delegate offset == 2
            _id2,                   // Second delegate id == _id
            uint8(3),               // Second delegate offset == 3
            bytes22(0),             // Rest of the word is 0-padded

            // -- offset 2 --
            _data1,   // First delegate metadata

            // -- offset 3 --
            _data2   // Second delegate metadata
        );

        assertEq(abi.decode(parser.getMetadata(_id1, _metadata), (uint256)), _data1);
        assertEq(parser.getMetadata(_id2, _metadata), _data2);
    }

    function test_create() external {
        bytes4[] memory _ids = new bytes4[](3);
        bytes[] memory _metadatas = new bytes[](3);

        for(uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i+1 * 1000));
            _metadatas[_i] = abi.encode(bytes1(uint8(_i+1)), uint32(69), bytes2(uint16(_i+69)), bytes32(uint256(type(uint256).max)));
        }

        bytes memory _out = parser.createMetadata(_ids, _metadatas);

        for(uint256 _i; _i < _ids.length; _i++) {
            (bytes1 _a, uint32 _deadBeef, bytes2 _c, bytes32 _d) = abi.decode(parser.getMetadata(_ids[_i], _out), (bytes1, uint32, bytes2, bytes32));

            assertEq(uint8(_a), _i+1);
            assertEq(uint256(_deadBeef), uint32(69));
            assertEq(uint16(_c), _i+69);
            assertEq(_d, bytes32(uint256(type(uint256).max)));
        }
    }
}

/**
 * @dev Harness to deploy and test JBXDelegateMetadataLib
 */
contract ForTest_JBXDelegateMetadataLib {
    function getMetadata(bytes4 _delegateId, bytes calldata _metadata) external pure returns(bytes memory _targetMetadata) {
        return JBXDelegateMetadataLib.getMetadata(_delegateId, _metadata);
    }

    function createMetadata(bytes4[] calldata _ids, bytes[] calldata _metadatas) external pure returns(bytes memory _metadata) {
        return JBXDelegateMetadataLib.createMetadata(_ids, _metadatas);
    }
}