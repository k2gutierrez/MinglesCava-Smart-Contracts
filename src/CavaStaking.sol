// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721A} from "../lib/ERC721A/contracts/ERC721A.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {CavaNFT} from "./CavaNFT.sol";

/**
 * @title Cava Stake Smart Contract for Mingles Cava program
 * @author Carlos E. Gutiérrez Chimal
 * @author Github - k2gutierrez
 * @author X - CarlosDappsDev.eth   /  @CarlosGtzChimal
 * @author email - cchimal.gutierrez@gmail.com
 * @notice The main objective of the contract is to stake for a certain amount of time
 * the Mingles NFTs while giving access to mint an ERC721A fully onchaine NFT which 
 * represents a real asset (1 bottle 750ml of tequila). The minimum time of stake is
 * 17 weeks which is an estimate fo time to turn tequila blanco into tequila reposado, 
 * by this time the dynamic NFT converts to a reposado token.
 */
contract CavaStaking is Ownable {
    ////////////////////////////////////////////////////////////
    ////////////               Errors               ////////////
    ////////////////////////////////////////////////////////////
    error CavaStaking__NotTheOwner(uint256 token);
    error CavaStaking__NoTokensOwned();
    error CavaStaking__NoStakingAllowed();
    error CavaStaking__WrongTimeToUnstake();
    error CavaStaking__TokenAlreadyStaked(uint256 token);
    error CavaStaking__NotApproved();
    error CavaStaking__WrongCaller();
    error CavaStaking__NeedToBePaused();

    ////////////////////////////////////////////////////////////
    ////////////               User Struct          ////////////
    ////////////////////////////////////////////////////////////
    struct User {
        uint256 totalStaked;
        uint256 alreadyStaked;
        uint256[] tokens;
    }
    
    ////////////////////////////////////////////////////////////
    ////////////     external contract addresses    ////////////
    ////////////////////////////////////////////////////////////
    address private immutable i_nftContractAddress;
    address private immutable i_cavaAddress;

    ////////////////////////////////////////////////////////////
    ////////////              Pause State           ////////////
    ////////////////////////////////////////////////////////////
    bool private s_pause = false;

    ////////////////////////////////////////////////////////////
    //////Mappings - User and check on staked tokens    ////////
    ////////////////////////////////////////////////////////////
    mapping(address userAddress => User userInfo) private s_user;
    mapping(uint256 token => bool staked) private s_stakedTokens;

    ////////////////////////////////////////////////////////////
    /////////  Constructor to add external contracts    ////////
    ////////////////////////////////////////////////////////////
    constructor(address _nftAddress, address _cavaAddress) Ownable(msg.sender) {
        i_nftContractAddress = _nftAddress;
        i_cavaAddress = _cavaAddress;
    }

    ////////////////////////////////////////////////////////////
    ////////////                Modifiers           ////////////
    ////////////////////////////////////////////////////////////
    modifier paused {
        if (s_pause == false){
            revert CavaStaking__NeedToBePaused();
        }
        _;
    }

    ////////////////////////////////////////////////////////////
    ////////////            External functions      ////////////
    ////////////////////////////////////////////////////////////
    /**
     * @dev This function is runned by the Cava contract to registered the staked (num) of 
     * minted NFTs of the Cava - this works in order to avoid minting more than the staked NFTs.
     * @param _user is the address of the msg.sender when calling the mint function of the 
     * cava contract.
     * @param _stakedTokens the amount of staked NFTs in this contract to give the same amount of
     * Cava NFTs.
     */
    function setAlreadyStaked(address _user, uint256 _stakedTokens) external {
        if (msg.sender != i_cavaAddress) revert CavaStaking__WrongCaller();
        s_user[_user].alreadyStaked = _stakedTokens;
    }

    /**
     * Functino to stake a certain amount of the approved smart contract NFT collection.
     * @param tokenIds Array of uint256 which must contain the NFTs "tokenId" that the user wants
     * to stake to the contract. Before this function runs the user must "setApprovedForAll" this
     * contract address or approve each token manually (this is done with the ERC721 or ERC721A
     * smart contract).
     */
    function stakeNfts(uint256[] calldata tokenIds) external {
        if (CavaNFT(payable(i_cavaAddress)).returnTequilaState() != 0) {
            revert CavaStaking__NoStakingAllowed();
        }
        if (tokenIds.length == 0) {
            revert CavaStaking__NoTokensOwned();
        }
        
        ERC721A nft = ERC721A(i_nftContractAddress);
        if (!nft.isApprovedForAll(msg.sender, address(this))) {
            revert CavaStaking__NotApproved();
        }

        User storage user = s_user[msg.sender];
        
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (nft.ownerOf(tokenId) != msg.sender) {
                revert CavaStaking__NotTheOwner(tokenId);
            }
            if (s_stakedTokens[tokenId]) {
                revert CavaStaking__TokenAlreadyStaked(tokenId);
            }

            nft.transferFrom(msg.sender, address(this), tokenId);
            s_stakedTokens[tokenId] = true;
            user.tokens.push(tokenId);
        }

        user.totalStaked += tokenIds.length;
    }

    /**
     * @dev Allow users to recover their own NFTs as long as the time needed in the Cava contract
     * has passed.
     */
    function unstakeNfts() external {
        if (CavaNFT(payable(i_cavaAddress)).returnTequilaState() < 1) {
            revert CavaStaking__WrongTimeToUnstake();
        }
        
        User storage user = s_user[msg.sender];
        if (user.totalStaked == 0) {
            revert CavaStaking__NoTokensOwned();
        }

        ERC721A nft = ERC721A(i_nftContractAddress);
        uint256[] memory tokens = user.tokens;

        for (uint256 i; i < tokens.length; i++) {
            uint256 tokenId = tokens[i];
            nft.transferFrom(address(this), msg.sender, tokenId);
            s_stakedTokens[tokenId] = false;
        }

        delete user.tokens;
        user.totalStaked = 0;
    }

    /**
     * @dev Function to roll back if something fails. It is required that the owner sets
     * the contract in pause status "true" to allow users to recover their own NFTs overriding
     * the time that needs to pass with the normal function.
     */
    function unstakeNftsEmergency() paused external {
        
        User storage user = s_user[msg.sender];
        if (user.totalStaked == 0) {
            revert CavaStaking__NoTokensOwned();
        }

        ERC721A nft = ERC721A(i_nftContractAddress);
        uint256[] memory tokens = user.tokens;

        for (uint256 i; i < tokens.length; i++) {
            uint256 tokenId = tokens[i];
            nft.transferFrom(address(this), msg.sender, tokenId);
            s_stakedTokens[tokenId] = false;
        }

        delete user.tokens;
        user.totalStaked = 0;
    }

    ////////////////////////////////////////////////////////////
    ////////////            Public functions        ////////////
    ////////////////////////////////////////////////////////////
    
    /**
     * @dev This function can only be called by the owner to puase the contract and allows
     * the function "unstakeNftsEmergency()" to be used by the users. This function when true allows
     * the users to call their NFTs back overriding the unstake function which needs 17 weeks to pass.
     */
    function changePauseStatus() public onlyOwner {
        s_pause = !s_pause;
    }

    ////////////////////////////////////////////////////////////
    ////////////       Public view functions        ////////////
    ////////////////////////////////////////////////////////////
    
    /**
     * @dev Cheks the pause contract status, default set at false.
     */
    function pauseStatus() public view returns(bool) {
        return s_pause;
    }
    
    /**
     * Allows everyone to see the User struct info of an address.
     * @param user address of the user registered when staking NFTs, gives access to the struct "User".
     */
    function getUser(address user) public view returns(User memory) {
        return s_user[user];
    }
    
    /**
     * Gives the number totalStaked NFTs.
     * @param user address of the user registered when staking NFTs, gives access to 
     * totalStaked amount in the struct "User".
     */
    function getUserTotalStaked(address user) public view returns(uint256) {
        return s_user[user].totalStaked;
    }
    
    /**
     * Gives the number alreadyStaked NFTs (this means that this number of staked NFTs have been
     * claimed as NFTs in the Cava contract).
     * @param user address of the user registered when staking NFTs, gives access to 
     * alreadtStaked amount in the struct "User".
     */
    function getUserAlreadyStaked(address user) public view returns(uint256) {
        return s_user[user].alreadyStaked;
    }
    
    /**
     * A function that can give use a quick check if it has already been staked.
     * @param tokenId NFTs staked can be checked if already staked with it's tokenId
     */
    function isTokenStaked(uint256 tokenId) public view returns(bool) {
        return s_stakedTokens[tokenId];
    }
}