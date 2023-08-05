// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant START_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, START_BALANCE);
    }

    function testMinDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }
    function testOwnerIsMsgSender() public {
        console.log(fundMe.getOwner());
        console.log(msg.sender);
        console.log(address(this));
        assertEq(fundMe.getOwner(), msg.sender);
    }
    function testPriceFeedVersion() public {
        assertEq(fundMe.getVersion(),4);
    }
    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // the next TX will be sent by USER
        fundMe.fund{value:SEND_VALUE}();
        // uint256 amountFunded = fundMe.getAddressToAmountFunded(address(this));
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value:SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value:SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithdrawWithSingleFunder() public funded {
        // arrange
        uint256 startingOwnerBal = fundMe.getOwner().balance;
        uint256 startingFundMeBal = address(fundMe).balance;

        // act
        uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        console.log(gasUsed);
        // assert
        uint256 endingOwnerBal = fundMe.getOwner().balance;
        uint256 endingFundMeBal = address(fundMe).balance;
        assertEq(endingFundMeBal, 0);
        assertEq(startingFundMeBal + startingOwnerBal, endingOwnerBal);
    }

    function testWithdrawWithMultipleFunders() public funded {
        // arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for(uint160 i=startingFunderIndex; i<numberOfFunders; i++){
            // vm.prank new address
            // vm.deal to new address
            hoax(address(i), SEND_VALUE);
            // fund
            fundMe.fund{value:SEND_VALUE}();
        }
        uint256 startingOwnerBal = fundMe.getOwner().balance;
        uint256 startingFundMeBal = address(fundMe).balance;

        // act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // assert
        uint256 endingOwnerBal = fundMe.getOwner().balance;
        uint256 endingFundMeBal = address(fundMe).balance;
        assertEq(endingFundMeBal, 0);
        assertEq(startingFundMeBal + startingOwnerBal, endingOwnerBal);
    }
}
