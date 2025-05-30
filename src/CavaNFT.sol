// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721A} from "../lib/ERC721A/contracts/ERC721A.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Base64} from "../lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {Strings} from "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {CavaStaking} from "./CavaStaking.sol";

/**
 * @title Cava NFT Smart Contract for Mingles Cava program
 * @author Carlos E. Gutiérrez Chimal
 * @author Github - k2gutierrez
 * @author X - CarlosDappsDev.eth   /  @CarlosGtzChimal
 * @author email - cchimal.gutierrez@gmail.com
 * @notice The main objective of the contract is to mint an ERC721A fully onchaine NFT which 
 * represents a real asset (1 bottle 750ml of tequila). In order to mint you need to stake
 * NFTs approved in a Cava Stake contract which is added only once in this contract. The amount
 * of NFTs you stack are the amount of NFTs to be minted for free to you, only gas need to be paid.
 * The minimum time of stake is 17 weeks which is an estimate fo time to turn tequila blanco 
 * into tequila reposado, by this time the dynamic NFT converts to a reposado token.
 */
contract CavaNFT is ERC721A, Ownable, ReentrancyGuard {
    ////////////////////////////////////////////////////////////
    ////////////               Errors               ////////////
    ////////////////////////////////////////////////////////////
    error CavaNFT__IncorrectTimeForAging();
    error CavaNFT__NoChangeAllowed();
    error CavaNFT__InsufficientApeForPurchase(uint256 value);
    error CavaNFT__WrongPriceFetched(uint256 price);
    error CavaNFT__IncorrectAmount();
    error CavaNFT__MaxExtraBottleReached();
    error CavaNFT__ZeroTokensnotAllowed();
    error CavaNFT__TokensAreAgingAlready();
    error CavaNFT__DecisionNotAllowed();
    error CavaNFT__NotEnoughNFTs();
    error CavaNFT__NoApeIsBeingTranferred();
    error CavaNFT__InsufficientAnejoFunds();
    error CavaNFT__InsufficientReposadoFunds();
    error CavaNFT__ReposadoPriceNotSet();
    error CavaNFT__NotOwnerOfToken();
    error CavaNFT__AnejoPriceNotSet();
    error CavaNFT__ErrorInSell();
    error CavaNFT__UseDesignatedDepositFunctions();
    error CavaNFT__ZeroPriceBottle();
    error CavaNFT__PurchaseNotAllowed();

    ////////////////////////////////////////////////////////////
    ////////////               Libraries          //////////////
    ////////////////////////////////////////////////////////////
    using Strings for uint256;

    ////////////////////////////////////////////////////////////
    //////////             Token Struct               //////////
    ////////////////////////////////////////////////////////////
    struct Token {
        AgingState agingState; // -> token state - see enum AginsState - defaults as blanco
        TokenChoice tokenChoice; // -> token choice - see enum TokenChoice - defaults as age
        bool noChange;
    }

    ////////////////////////////////////////////////////////////
    //////////        Aging State of token            //////////
    ////////////////////////////////////////////////////////////
    // changes automatically when time is passed and the owner send the change request
    // Token won't change to Anejo if in reposado the choice is to sell or bottle
    enum AgingState {
        Blanco,
        Reposado,
        Anejo
    }

    ////////////////////////////////////////////////////////////
    //////////              Token Choice              //////////
    ////////////////////////////////////////////////////////////
    //age -> change state // sell o bottle -/> only certain weeks allows to be changed
    enum TokenChoice {
        age,
        sell,
        bottle
    }

    ////////////////////////////////////////////////////////////
    ////////////              Constants             ////////////
    ////////////////////////////////////////////////////////////
    uint256 public constant MAX_SUPPLY = 5555;
    uint256 private constant CANVAS_SIZE = 300;
    uint256 private constant BUBBLE_COUNT = 10;
    uint256 private constant REPOSADO_TIME = 17 weeks;  // 119 days
    uint256 private constant ANEJO_TIME = 48 weeks; // 336 days, 119 to 217 days
    
    ////////////////////////////////////////////////////////////
    ////////////          Storage variables         ////////////
    ////////////////////////////////////////////////////////////
    AgingState private s_currentState; // Global state of the tokens in the contract.
    
    uint256[] private s_tokensToBurn; // Number of tokens to be burned.
    uint256 private s_startingTime; // block.timestamp when contract was deployed.
    uint256 private _seedBase; // variable used to create onchain svg
    uint256 private s_MaxExtraBottleSupply = 200; // Max supply for bottle purchase option, no need to own Mingle NFT.
    uint256 private s_TotalExtraBottleSupply; // counter of purchasd bottles.
    uint256 private s_bottleMintPrice = 0; // Bottle price to purchase=mint (NFT).
    uint256 s_reposadoPrice; // Price of Reposado to be set by owner when bottles have been selled in order to give money back to he holders on the condition of a burning tokens.
    uint256 s_anejoPrice; // Price of Anejo to be set by owner when bottles have been selled in order to give money back to he holders on the condition of a burning tokens.
    
    bool private s_stakingLockAddress = false; // Function to allow the set of the cava staking contract only once. Can't be replaced onced this variable is set to True.

    address private s_CavaStakingAddress; // The Cafa Staking contract to communicate with. Required for the contract to work properly.

    mapping(uint256 tokenId => Token tokenDecision) private s_tokenState; // Checks the token decision of the tokenId

    mapping(string => uint256) private TequilaBalance; // "REPOSADO" "ANEJO"  / "BOTTLES"  to store the amount of ape stored in the smart contract.

    constructor() ERC721A("CAVA", "CAVA") Ownable(msg.sender) {
        s_currentState = AgingState.Blanco;
        s_startingTime = block.timestamp;
        _seedBase = uint256(keccak256(abi.encodePacked(block.timestamp)));
    }

    ////////////////////////////////////////////////////////////
    ////////////               Events               ////////////
    ////////////////////////////////////////////////////////////
    event ReposadoMoneyTransferredToContract(address indexed sender, uint256 amount);
    event AnejoMoneyTransferredToContract(address indexed sender, uint256 amount);
    event ApeClaimedFromReposado(address sender, uint256 amount);
    event ApeClaimedFromAnejo(address sender, uint256 amount);
    event BottlesClaimed(AgingState, address indexed sender, uint256 indexed bottles);

    ////////////////////////////////////////////////////////////
    ////////////   Receive / fallback functions     ////////////
    ////////////////////////////////////////////////////////////
    receive() external payable {
        revert CavaNFT__UseDesignatedDepositFunctions();
    }

    fallback() external payable {
        transferMoneyToContract();
    }
    
    ////////////////////////////////////////////////////////////
    ///////  External and public All users functions     ///////
    ////////////////////////////////////////////////////////////

    function mint() external nonReentrant {
        CavaStaking cava = CavaStaking(s_CavaStakingAddress);
        uint256 quantity = cava.getUserTotalStaked(msg.sender);
        uint256 alreadyStaked = cava.getUserAlreadyStaked(msg.sender);
        if (quantity <= alreadyStaked) revert CavaNFT__NotEnoughNFTs();
        uint256 amount = quantity - alreadyStaked;
        if (amount == 0) revert CavaNFT__NotEnoughNFTs();
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply");
        cava.setAlreadyStaked(msg.sender, quantity);
        _seedBase = uint256(
            keccak256(abi.encodePacked(_seedBase, block.timestamp))
        );
        _safeMint(msg.sender, amount);
    }

    function purchaseExtraTequilaBottle(uint256 quantity) public payable nonReentrant {
        if (s_currentState != AgingState.Blanco) revert CavaNFT__PurchaseNotAllowed();
        if (s_bottleMintPrice == 0) revert CavaNFT__ZeroPriceBottle();
        uint256 requiredApe = quantity * s_bottleMintPrice;
        if (requiredApe <= 0) revert CavaNFT__WrongPriceFetched(requiredApe);
        if (msg.value < requiredApe)
            revert CavaNFT__InsufficientApeForPurchase(msg.value);
        if (s_TotalExtraBottleSupply + quantity > s_MaxExtraBottleSupply)
            revert CavaNFT__MaxExtraBottleReached();

        _safeMint(msg.sender, quantity);
        s_TotalExtraBottleSupply += quantity;

        TequilaBalance["BOTTLES"] += requiredApe;
        // Refund excess
        if (msg.value > requiredApe) {
            payable(msg.sender).transfer(msg.value - requiredApe);
        } 
    }

    function userTokenDecision(
        uint256[] calldata _tokens,
        uint256 _choice
    ) public {
        if (_choice == 0) revert CavaNFT__TokensAreAgingAlready();
        if (s_currentState == AgingState.Blanco)
            revert CavaNFT__DecisionNotAllowed();

        uint256 currentTime = block.timestamp;

        if (s_currentState == AgingState.Reposado) {
            if ((currentTime - s_startingTime) <= (REPOSADO_TIME + 5 weeks)) {
                for (uint256 i; i < _tokens.length; i++) {
                    if (ERC721A(address(this)).ownerOf(_tokens[i]) != msg.sender) revert CavaNFT__NotOwnerOfToken();
                    s_tokenState[_tokens[i]].agingState = s_currentState;
                    s_tokenState[_tokens[i]].noChange = true;
                    if (_choice == 1) {
                        s_tokenState[_tokens[i]].tokenChoice = TokenChoice.sell;
                    } else if (_choice == 2) {
                        s_tokenState[_tokens[i]].tokenChoice = TokenChoice.bottle;
                    }
                }
            }
        } else {
            if ((currentTime - s_startingTime) <= (ANEJO_TIME + 5 weeks)) {
                for (uint256 i; i < _tokens.length; i++) {
                    if (ERC721A(address(this)).ownerOf(_tokens[i]) != msg.sender) revert CavaNFT__NotOwnerOfToken();
                    s_tokenState[_tokens[i]].agingState = s_currentState;
                    s_tokenState[_tokens[i]].noChange = true;
                    if (_choice == 1) {
                        s_tokenState[_tokens[i]].tokenChoice = TokenChoice.sell;
                    } else if (_choice == 2) {
                        s_tokenState[_tokens[i]].tokenChoice = TokenChoice.bottle;
                    }
                }
            }
        }
    }

    function claimReposadoApe(uint256[] calldata tokens) public nonReentrant {
        if (s_reposadoPrice <= 0) revert CavaNFT__ReposadoPriceNotSet();
        
        uint256 reposadoPrice = s_reposadoPrice;
        uint256 reposadoTotalBottles;
        for (uint256 i; i < tokens.length; i++){
            if (ERC721A(address(this)).ownerOf(tokens[i]) != msg.sender) revert CavaNFT__NotOwnerOfToken();
            Token memory tokenInfo = s_tokenState[tokens[i]];
            if (tokenInfo.agingState == AgingState.Reposado && tokenInfo.tokenChoice == TokenChoice.sell){
                reposadoTotalBottles += 1;
                s_tokensToBurn.push(tokens[i]);
            }
        }

        uint256[] memory tokensToBurn = s_tokensToBurn;
        uint256 totalApe = (reposadoPrice * reposadoTotalBottles);

        if (totalApe == 0) revert CavaNFT__ErrorInSell();
        if (TequilaBalance["REPOSADO"] < totalApe)
            revert CavaNFT__InsufficientReposadoFunds();

        // payable(msg.sender).transfer(address(this).balance);
        (bool success, ) = msg.sender.call{value: totalApe}("");
        require(success);
        TequilaBalance["REPOSADO"] -= totalApe;
        
        for (uint256 i; i < tokensToBurn.length; i++){
            _burn(tokensToBurn[i]);
        }
        emit ApeClaimedFromReposado(msg.sender, totalApe);

        delete s_tokensToBurn;
    }

    function claimAnejoApe(uint256[] calldata tokens) public nonReentrant {
        if (s_anejoPrice <= 0) revert CavaNFT__AnejoPriceNotSet();
        
        uint256 anejoPrice = s_anejoPrice;
        uint256 anejoTotalBottles;
        for (uint256 i; i < tokens.length; i++){
            if (ERC721A(address(this)).ownerOf(tokens[i]) != msg.sender) revert CavaNFT__NotOwnerOfToken();
            Token memory tokenInfo = s_tokenState[tokens[i]];
            if (tokenInfo.agingState == AgingState.Anejo && tokenInfo.tokenChoice == TokenChoice.sell){
                anejoTotalBottles += 1;
                s_tokensToBurn.push(tokens[i]);
            }
        }

        uint256[] memory tokensToBurn = s_tokensToBurn;
        uint256 totalApe = (anejoPrice * anejoTotalBottles);

        if (totalApe == 0) revert CavaNFT__ErrorInSell();
        if (TequilaBalance["ANEJO"] < totalApe)
            revert CavaNFT__InsufficientAnejoFunds();

        // payable(msg.sender).transfer(address(this).balance);
        (bool success, ) = msg.sender.call{value: totalApe}("");
        require(success);
        TequilaBalance["ANEJO"] -= totalApe;
        
        for (uint256 i; i < tokensToBurn.length; i++){
            _burn(tokensToBurn[i]);
        }
        emit ApeClaimedFromAnejo(msg.sender, totalApe);

        delete s_tokensToBurn;
    }

    function claimAnejoBottle(uint256[] calldata tokens) public nonReentrant {
        uint256 anejoTotalBottles;
        for (uint256 i; i < tokens.length; i++){
            if (ERC721A(address(this)).ownerOf(tokens[i]) != msg.sender) revert CavaNFT__NotOwnerOfToken();
            Token memory tokenInfo = s_tokenState[tokens[i]];
            if (tokenInfo.agingState == AgingState.Anejo && tokenInfo.tokenChoice == TokenChoice.bottle){
                anejoTotalBottles += 1;
                s_tokensToBurn.push(tokens[i]);
            }
        }

        uint256[] memory tokensToBurn = s_tokensToBurn;
        
        for (uint256 i; i < tokensToBurn.length; i++){
            _burn(tokensToBurn[i]);
        }

        emit BottlesClaimed(AgingState.Anejo, msg.sender, anejoTotalBottles);

        delete s_tokensToBurn;

    }

    function claimReposadoBottle(uint256[] calldata tokens) public nonReentrant {
        uint256 reposadoTotalBottles;
        for (uint256 i; i < tokens.length; i++){
            if (ERC721A(address(this)).ownerOf(tokens[i]) != msg.sender) revert CavaNFT__NotOwnerOfToken();
            Token memory tokenInfo = s_tokenState[tokens[i]];
            if (tokenInfo.agingState == AgingState.Reposado && tokenInfo.tokenChoice == TokenChoice.bottle){
                reposadoTotalBottles += 1;
                s_tokensToBurn.push(tokens[i]);
            }
        }

        uint256[] memory tokensToBurn = s_tokensToBurn;
        
        for (uint256 i; i < tokensToBurn.length; i++){
            _burn(tokensToBurn[i]);
        }

        emit BottlesClaimed(AgingState.Reposado, msg.sender, reposadoTotalBottles);

        delete s_tokensToBurn;

    }

    ////////////////////////////////////////////////////////////
    //////////////  Public OnlyOwner functions     /////////////
    ////////////////////////////////////////////////////////////

    //----- Can only be called once by the owner to set the Cava Stake Contract to interact with. -----//
    
    function setStakingAddress(address stakingAddress) public onlyOwner {
        if (s_stakingLockAddress == true) revert CavaNFT__NoChangeAllowed();
        s_CavaStakingAddress = stakingAddress;
        s_stakingLockAddress = true;
    }

    //----- Change the state when certain time has passed. -----//
    
    function advanceState() external onlyOwner {
        uint256 timePassed = block.timestamp;
        uint256 time = timePassed - s_startingTime;
        if (s_currentState == AgingState.Blanco && time >= REPOSADO_TIME && time < ANEJO_TIME) {
            s_currentState = AgingState.Reposado;
        } else if (s_currentState == AgingState.Reposado && time >= ANEJO_TIME) {
            s_currentState = AgingState.Anejo;
        } else {
            revert CavaNFT__IncorrectTimeForAging();
        }
    }

    //----- Set mint price to purchase bottle / NFTs and change the max amount of the extra bottle supplies. -----//
    
    function changeBottleMintPrice(uint256 quantity) public onlyOwner {
        s_bottleMintPrice = quantity;
    }

    function changeExtraBottleSupply(uint256 quantity) public onlyOwner {
        if (quantity < s_TotalExtraBottleSupply)
            revert CavaNFT__IncorrectAmount();
        s_MaxExtraBottleSupply = quantity;
    }

    //----- set Price functions used for the users to obtain money of bottles selled! -----//

    function setReposadoPrice(uint256 _price) public onlyOwner {
        s_reposadoPrice = _price;
    }

    function setAnejoPrice(uint256 _price) public onlyOwner {
        s_anejoPrice = _price;
    }

    //----- Withdraw functions used as emergency. -----//
    
    function withdrawReposado() public onlyOwner nonReentrant {
        uint256 amount = TequilaBalance["REPOSADO"];
        
        (bool success, ) = owner().call{value: amount}("");
        if (success){
            TequilaBalance["REPOSADO"] = 0;
        }
    }

    function withdrawAnejo() public onlyOwner nonReentrant {
        uint256 amount = TequilaBalance["ANEJO"];
        
        (bool success, ) = owner().call{value: amount}("");
        if (success){
            TequilaBalance["ANEJO"] = 0;
        }
    }

    function withdrawABottles() public onlyOwner nonReentrant {
        uint256 amount = TequilaBalance["BOTTLES"];
        
        (bool success, ) = owner().call{value: amount}("");
        if (success) {
            TequilaBalance["BOTTLES"] = 0;
        }
    }

    ////////////////////////////////////////////////////////////
    ////////////    TokenURI Dynamic Svg Function     //////////
    ////////////////////////////////////////////////////////////

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_exists(tokenId), "Invalid token");
        bool choice = s_tokenState[tokenId].noChange;
        AgingState choice2 = s_tokenState[tokenId].agingState;
        string memory tequilaState;
        string memory bgColor;
        if (s_currentState == AgingState.Blanco){
            bgColor = "#F0F8FF";
            tequilaState = "Blanco";
        } else if (s_currentState == AgingState.Reposado){
            bgColor = "#FFD700";
            tequilaState = "Reposado";
        } else if (s_currentState == AgingState.Anejo && choice == true && choice2 == AgingState.Reposado){
            bgColor = "#FFD700";
            tequilaState = "Reposado";
        } else if (s_currentState == AgingState.Anejo && choice == false){
            bgColor = "#8B0000";
            tequilaState = "Anejo";
        } else if (s_currentState == AgingState.Anejo && choice == true && choice2 == AgingState.Anejo){
            bgColor = "#8B0000";
            tequilaState = "Anejo";
        }

        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300" style="overflow:hidden">',
                '<defs><clipPath id="frame"><rect width="300" height="300"/></clipPath></defs>',
                '<rect width="300" height="300" fill="',
                bgColor,
                '"/>',
                '<g clip-path="url(#frame)">',
                _generateBubbles(tokenId),
                "</g></svg>"
            )
        );

        string memory json = Base64.encode(
            abi.encodePacked(
                '{"name":"CAVA #',
                tokenId.toString(),
                '","description":"On-chain aged tequila NFT with dynamic animation",',
                '"attributes":[{"trait_type":"State","value":"',
                tequilaState,
                '"}],"image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '"}'
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }
    
    function _generateBubbles(
        uint256 tokenId
    ) internal view returns (string memory) {
        bytes memory bubbles;
        for (uint256 i = 0; i < BUBBLE_COUNT; i++) {
            uint256 seed = uint256(
                keccak256(abi.encodePacked(_seedBase, tokenId, i))
            );
            bubbles = abi.encodePacked(bubbles, _buildBubble(seed, i, tokenId));
        }
        return string(bubbles);
    }

    function _buildBubble(
        uint256 seed,
        uint256 index,
        uint256 tokenId
    ) internal view returns (string memory) {

        AgingState state;

        bool choice = s_tokenState[tokenId].noChange;
        AgingState choice2 = s_tokenState[tokenId].agingState;

        if (s_currentState == AgingState.Blanco){
            state = AgingState.Blanco;
        } else if (s_currentState == AgingState.Reposado){
            state = AgingState.Reposado;
        } else if (s_currentState == AgingState.Anejo && choice == true && choice2 == AgingState.Reposado){
            state = AgingState.Reposado;
        } else if (s_currentState == AgingState.Anejo && choice == false){
            state = AgingState.Anejo;
        } else if (s_currentState == AgingState.Anejo && choice == true && choice2 == AgingState.Anejo){
            state = AgingState.Anejo;
        }

        uint256 baseSize = 20 + (seed % 40);
        uint256 startX = 30 + ((seed >> 8) % 240);
        uint256 startY = 30 + ((seed >> 16) % 240);
        int256 moveX = int256((seed >> 24) % 61) - 30;
        int256 moveY = int256((seed >> 32) % 61) - 30;
        uint256 duration = 4 + ((seed >> 40) % 3);

        return
            string(
                abi.encodePacked(
                    '<g transform="translate(',
                    startX.toString(),
                    ",",
                    startY.toString(),
                    ')">',
                    '<circle r="',
                    baseSize.toString(),
                    '" fill="',
                    _getColor(seed, state),
                    '" opacity="0">',
                    '<animate attributeName="opacity" values="0;0.7;0" dur="',
                    duration.toString(),
                    's" ',
                    'begin="-',
                    (index % duration).toString(),
                    's" repeatCount="indefinite"/>',
                    '<animate attributeName="r" values="',
                    baseSize.toString(),
                    ";",
                    (baseSize * 2).toString(),
                    ";",
                    baseSize.toString(),
                    '" ',
                    'dur="',
                    duration.toString(),
                    's" repeatCount="indefinite"/>',
                    '<animateTransform attributeName="transform" type="translate" ',
                    'values="0,0;',
                    _intToString(moveX),
                    ",",
                    _intToString(moveY),
                    ';0,0" ',
                    'dur="',
                    duration.toString(),
                    's" additive="sum" repeatCount="indefinite"/>',
                    "</circle></g>"
                )
            );
    }

    function _intToString(int256 n) internal pure returns (string memory) {
        return
            n < 0
                ? string(abi.encodePacked("-", uint256(-n).toString()))
                : uint256(n).toString();
    }

    function _getColor(
        uint256 seed,
        AgingState state
    ) internal pure returns (string memory) {
        string[5] memory colors;
        if (state == AgingState.Blanco) {
            colors = ["#87CEEB", "#00BFFF", "#1E90FF", "#4169E1", "#4682B4"];
        } else if (state == AgingState.Reposado) {
            colors = ["#FFD700", "#FFA500", "#FF8C00", "#FFB90F", "#EEB422"];
        } else {
            colors = ["#8B0000", "#A52A2A", "#B22222", "#8B4513", "#CD853F"];
        }
        return colors[seed % 5];
    }

    ////////////////////////////////////////////////////////////
    ///////  External and public view/pure functions     ///////
    ////////////////////////////////////////////////////////////

    function returnTequilaState() external view returns (uint256) {
        if (s_currentState == AgingState.Blanco) {
            return 0;
        } else if (s_currentState == AgingState.Reposado) {
            return 1;
        } else {
            return 2;
        }
    }

    function getTokenInfo(uint256 _tokenId) public view returns(Token memory) {
        return s_tokenState[_tokenId];
    }

    function MaxExtraBottleSupply() public view returns(uint256) {
        return s_MaxExtraBottleSupply;
    }

    function ExtraBottleSupply() public view returns(uint256) {
        return s_TotalExtraBottleSupply;
    }

    function BottleMintprice() public view returns(uint256) {
        return s_bottleMintPrice;
    }

    function ReposadoSellprice() public view returns(uint256) {
        return s_reposadoPrice;
    }

    function AnejoSellprice() public view returns(uint256) {
        return s_anejoPrice;
    }

    function currentTequilaState() public view returns(AgingState) {
        return s_currentState;
    }    

    function reposadoBalance() public view returns(uint256){
        return TequilaBalance["REPOSADO"];
    }

    function anejoBalance() public view returns(uint256){
        return TequilaBalance["ANEJO"];
    }

    function bottlesBalance() public view returns(uint256){
        return TequilaBalance["BOTTLES"];
    }

    function getBalance() public view returns(uint256) {
        return address(this).balance;
    }

    function verifyBalances() public view returns (bool){
        return getBalance() == (reposadoBalance() + anejoBalance() + bottlesBalance());
    }

    ////////////////////////////////////////////////////////////
    ///////  Public ape transfer to contract functions   ///////
    ////////////////////////////////////////////////////////////

    function transferReposadoMoneyToContract() public payable {
        if (msg.value <= 0) revert CavaNFT__NoApeIsBeingTranferred();
        TequilaBalance["REPOSADO"] += msg.value;
        emit ReposadoMoneyTransferredToContract(msg.sender, msg.value);
    }

    function transferAnejoMoneyToContract() public payable {
        if (msg.value <= 0) revert CavaNFT__NoApeIsBeingTranferred();
        TequilaBalance["ANEJO"] += msg.value;
        emit AnejoMoneyTransferredToContract(msg.sender, msg.value);
    }

    function transferMoneyToContract() public payable {
        if (msg.value <= 0) revert CavaNFT__NoApeIsBeingTranferred();
        TequilaBalance["BOTTLES"] += msg.value;
    }

}

// Layout of Contract:
// version *
// imports *
// errors *
// interfaces, libraries, contracts *
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions