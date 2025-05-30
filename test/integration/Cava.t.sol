// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {console} from "forge-std/console.sol";
import {CavaStaking} from "../../src/CavaStaking.sol";
import {CavaNFT} from "../../src/CavaNFT.sol";
import {NFT} from "../../src/MockNFT.sol";
import {DeployCavaStaking} from "../../script/DeployCavaStaking.s.sol";
import {DeployCava} from "../../script/DeployCava.s.sol";
import {DeployMockNFT} from "../../script/DeployMockNFT.s.sol";

contract Cava is Test {
    NFT nft;
    CavaNFT cavaNFT;
    CavaStaking cavaStaking;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    uint256[] tokensArr;

    function setUp() external {
        uint256 tokens = 10;

        DeployMockNFT deployMockNFT = new DeployMockNFT();
        DeployCava deployCava = new DeployCava();
        nft = deployMockNFT.run();
        cavaNFT = deployCava.run();

        DeployCavaStaking deployCavaStaking = new DeployCavaStaking(
            address(nft),
            address(cavaNFT)
        );
        cavaStaking = deployCavaStaking.run();

        vm.deal(USER, STARTING_BALANCE);

        for (uint256 i; i < tokens; i++) {
            nft.mintTo(USER);
        }

        vm.prank(cavaNFT.owner());

        cavaNFT.setStakingAddress(address(cavaStaking));
    }

    modifier fundedReposado() {
        vm.prank(USER); //The next tx will be sent by user
        cavaNFT.transferReposadoMoneyToContract{value: SEND_VALUE}();
        _;
    }

    modifier fundedAnejo() {
        vm.prank(USER); //The next tx will be sent by user
        cavaNFT.transferAnejoMoneyToContract{value: SEND_VALUE}();
        _;
    }

    modifier fundedBottles() {
        vm.prank(USER); //The next tx will be sent by user
        cavaNFT.transferMoneyToContract{value: SEND_VALUE}();
        _;
    }

    // Helper function to stake tokens
    function stakeTokens(uint256 count) internal {
        delete tokensArr;
        for (uint256 i; i < count; i++) {
            tokensArr.push(i + 1);
        }
        vm.prank(USER);
        nft.setApprovalForAll(address(cavaStaking), true);
        vm.prank(USER);
        cavaStaking.stakeNfts(tokensArr);

    }

    function testCavaNFTOwnerIsMsgSender() public view {
        //console.log(fundMe.i_owner());
        //console.log(msg.sender);
        assertEq(cavaNFT.owner(), msg.sender); //we used address(this) before refactoring
    }

    function testCavaStakingOwnerIsMsgSender() public view {
        assertEq(cavaStaking.owner(), msg.sender); //we used address(this) before refactoring
    }

    function testFundReposadoFailWithoutEnoughETH() public {
        vm.expectRevert();
        cavaNFT.transferReposadoMoneyToContract{value: 0}();
    }

    function testOnlyOwnerCanWithdraw() public fundedReposado {
        vm.prank(USER);
        vm.expectRevert();
        cavaNFT.withdrawReposado();
    }

    function testTokenidBelongsToAddressUser() public view {
        address tokenOwner = nft.ownerOf(1);
        assertEq(tokenOwner, USER);
    }

    function testStakeFailNoSetApprove() public {
        delete tokensArr;
        uint256 counter = 5;
        for (uint256 i; i < counter; i++) {
            tokensArr.push(i + 1);
        }
        vm.expectRevert();
        vm.prank(USER);
        cavaStaking.stakeNfts(tokensArr);
        
    }

    function testApproveAndStackTokens() public {
        delete tokensArr;
        uint256 counter = 5;
        for (uint256 i; i < counter; i++) {
            tokensArr.push(i + 1);
        }
        vm.prank(USER);
        nft.setApprovalForAll(address(cavaStaking), true);
        vm.prank(USER);
        cavaStaking.stakeNfts(tokensArr);
        uint256 stakedTokens = cavaStaking.getUserTotalStaked(USER);
        assertEq(stakedTokens, counter);
    }

    // ===========
    // CavaStaking Tests
    // ===========

    function testSetAlreadyStaked() public {
        stakeTokens(5);

        vm.prank(address(cavaNFT));
        cavaStaking.setAlreadyStaked(USER, 3);

        assertEq(cavaStaking.getUserTotalStaked(USER), 5);
        assertEq(cavaStaking.getUserAlreadyStaked(USER), 3);
    }

    function testSetAlreadyStakedFailWrongCaller() public {
        stakeTokens(5);

        vm.expectRevert();
        cavaStaking.setAlreadyStaked(USER, 3);
    }

    function testUnstakeNfts() public {
        stakeTokens(5);

        // Simulate time passing
        vm.warp(block.timestamp + 18 weeks);

        // Change state to allow unstaking
        vm.prank(cavaNFT.owner());
        cavaNFT.advanceState();

        vm.prank(USER);
        cavaStaking.unstakeNfts();

        assertEq(cavaStaking.getUserTotalStaked(USER), 0);
        assertEq(nft.balanceOf(USER), 10);
    }

    function testUnstakeNftsEmergency() public {
        stakeTokens(5);

        // Enable emergency mode
        vm.prank(cavaStaking.owner());
        cavaStaking.changePauseStatus();

        vm.prank(USER);
        cavaStaking.unstakeNftsEmergency();

        assertEq(cavaStaking.getUserTotalStaked(USER), 0);
        assertEq(nft.balanceOf(USER), 10);
    }

    function testUnstakeNftsEmergencyFailNotPaused() public {
        stakeTokens(5);

        vm.expectRevert();
        vm.prank(USER);
        cavaStaking.unstakeNftsEmergency();
    }

    function testChangePauseStatus() public {
        bool initialStatus = cavaStaking.pauseStatus();

        vm.prank(cavaStaking.owner());
        cavaStaking.changePauseStatus();

        assertEq(cavaStaking.pauseStatus(), !initialStatus);
    }

    function testIsTokenStaked() public {
        stakeTokens(3);
        assertTrue(cavaStaking.isTokenStaked(1));
        assertFalse(cavaStaking.isTokenStaked(10));
    }

    // ===========
    // CavaNFT Tests
    // ===========

    function testMint() public {
        stakeTokens(5);

        uint256 initialBalance = cavaNFT.balanceOf(USER);
        vm.prank(USER);
        cavaNFT.mint();

        assertEq(cavaNFT.balanceOf(USER), initialBalance + 5);
        assertEq(cavaStaking.getUserAlreadyStaked(USER), 5);
    }

    function testMintFailNotEnoughNFTs() public {
        vm.prank(USER);
        vm.expectRevert();
        cavaNFT.mint();
    }

    function testPurchaseExtraTequilaBottle() public {
        uint256 price = 0.1 ether;
        vm.prank(cavaNFT.owner());
        cavaNFT.changeBottleMintPrice(price);

        vm.prank(USER);
        cavaNFT.purchaseExtraTequilaBottle{value: price}(1);

        assertEq(cavaNFT.balanceOf(USER), 1);
        assertEq(cavaNFT.ExtraBottleSupply(), 1);
    }

    function testUserTokenDecision() public {
        stakeTokens(1);
        vm.prank(USER);
        cavaNFT.mint();

        // Advance to reposado state
        vm.warp(block.timestamp + 18 weeks);
        vm.prank(cavaNFT.owner());
        cavaNFT.advanceState();

        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 0;

        vm.prank(USER);
        cavaNFT.userTokenDecision(tokens, 1); // Sell option

        // Correct way to get struct values
        CavaNFT.Token memory tokenInfo = cavaNFT.getTokenInfo(0);
        bool noChange = tokenInfo.noChange;

        assertTrue(noChange);
    }

    function testClaimReposadoApe() public {
        // Setup claim scenario
        testUserTokenDecision();

        vm.prank(cavaNFT.owner());
        cavaNFT.setReposadoPrice(0.1 ether);

        // Fund the contract
        vm.prank(USER);
        cavaNFT.transferReposadoMoneyToContract{value: 0.1 ether}();

        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 0;

        uint256 initialBalance = USER.balance;
        vm.prank(USER);
        cavaNFT.claimReposadoApe(tokens);

        assertEq(USER.balance, initialBalance + 0.1 ether);
        assertEq(cavaNFT.balanceOf(USER), 0);
    }

    function testAdvanceState() public {
        // Initial state should be Blanco
        assertEq(uint(cavaNFT.currentTequilaState()), 0);

        // Advance to reposado
        vm.warp(block.timestamp + 18 weeks);
        vm.prank(cavaNFT.owner());
        cavaNFT.advanceState();
        assertEq(uint(cavaNFT.currentTequilaState()), 1);

        // Advance to anejo
        vm.warp(block.timestamp + 30 weeks);
        vm.prank(cavaNFT.owner());
        cavaNFT.advanceState();
        assertEq(uint(cavaNFT.currentTequilaState()), 2);
    }

    function testWithdrawFunctions() public {
        // Fund the contract
        vm.prank(USER);
        cavaNFT.transferReposadoMoneyToContract{value: 0.1 ether}();
        vm.prank(USER);
        cavaNFT.transferAnejoMoneyToContract{value: 0.1 ether}();
        vm.prank(USER);
        cavaNFT.transferMoneyToContract{value: 0.1 ether}();

        uint256 initialOwnerBalance = cavaNFT.owner().balance;

        vm.prank(cavaNFT.owner());
        cavaNFT.withdrawReposado();
        vm.prank(cavaNFT.owner());
        cavaNFT.withdrawAnejo();
        vm.prank(cavaNFT.owner());
        cavaNFT.withdrawABottles();

        assertEq(cavaNFT.owner().balance, initialOwnerBalance + 0.3 ether);
    }

    function testTokenURI() public {
        stakeTokens(1);
        vm.prank(USER);
        cavaNFT.mint();

        string memory uri = cavaNFT.tokenURI(0);
        assertTrue(bytes(uri).length > 0);
    }

    // Additional edge cases
    function testCannotStakeWhenNotBlanco() public {
        uint256 count = 2;
        // Advance to reposado state
        vm.warp(block.timestamp + 18 weeks);
        vm.prank(cavaNFT.owner());
        cavaNFT.advanceState();

        for (uint256 i; i < count; i++) {
            tokensArr.push(i + 1);
        }
        vm.prank(USER);
        nft.setApprovalForAll(address(cavaStaking), true);
        
        vm.expectRevert();
        
        vm.prank(USER);
        cavaStaking.stakeNfts(tokensArr);
    }

    function testCannotMintMoreThanStaked() public {
        stakeTokens(3);

        // First mint
        vm.prank(USER);
        cavaNFT.mint();

        // Attempt second mint with same staked tokens
        vm.prank(USER);
        vm.expectRevert();
        cavaNFT.mint();
    }

    function testEmergencyUnstakeAfterMint() public {
        stakeTokens(3);
        vm.prank(USER);
        cavaNFT.mint();

        // Enable emergency mode
        vm.prank(cavaStaking.owner());
        cavaStaking.changePauseStatus();

        vm.prank(USER);
        cavaStaking.unstakeNftsEmergency();

        assertEq(nft.balanceOf(USER), 10);
        assertEq(cavaNFT.balanceOf(USER), 3);
    }
}

/*
    function testFundUpdatedDataStructure() public funded{
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public funded {
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }
    
    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testWithdrawWithASingleFunder() public funded {
        //arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        //act
        uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        //assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(startingFundMeBalance + startingOwnerBalance, endingOwnerBalance);
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++){
            // vm.prank new address
            // vm.deal new address
            // hoax does both prank and deal
            hoax(address(i), SEND_VALUE);
            // fund the fundMe
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
    }*/
