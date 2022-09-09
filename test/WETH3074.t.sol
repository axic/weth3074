// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Test.sol";

import "../src/WETH3074.sol";

contract WETH3074Test is Test {
    WETH3074 public weth;

    function setUp() public {
        weth = new WETH3074();
    }

    function testMetadata() public {
        assertEq(weth.name(), "Wrapped Ether");
        assertEq(weth.symbol(), "WETH");
        assertEq(weth.decimals(), 18);
    }

    function testTotalSupply() public {
        assertEq(weth.totalSupply(), type(uint256).max);
    }

    function testAuthorize() public {
        weth.authorize({commit: 0, yParity: false, r: 0, s: 0});
    }

    function testDeauthorize() public {
        weth.deauthorize();
    }

    function testBalance() public {
        assertEq(weth.balanceOf(address(this)), address(this).balance);
    }

    function testUnauthorizedTransfer() public {
        weth.transferFrom(address(this), address(0), 1234);
    }

    function testApprove() public {
        weth.approve(address(0), 1234);
        weth.transferFrom(address(0), address(this), 1234);
    }
}
