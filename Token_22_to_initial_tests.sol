// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";



contract TokenWithdrawal is ERC20, Ownable, ERC20Burnable, ERC20Pausable {
    using SafeMath for uint256;

    uint256 public totalFundsGathered;
    bool public isGatheringFunds;
    bool public isMintingEnabled;
    uint256 public tokenPrice;
    uint256 public totalDepositors;
    address payable beneficiary;
    address payable gatherer;
    bool public pauseMy;
    mapping(address => mapping(address => uint256)) public depositedTokens;// donator , address of token, volume of token
    mapping(address => uint256) public depositedEthers;
    mapping(address => uint256) public tokenConversions;


    event TokensMinted(address indexed to, uint256 amount);
    event FundsGathered(uint256 amount);
    event FundsReleased(uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _tokenPrice
    ) ERC20(name, symbol) {
        tokenPrice = _tokenPrice;
        tokenPrice = 1000; //initial token price is 1000 as 1 eth = 1 X token
        isGatheringFunds = true;
        isMintingEnabled = true;
        beneficiary = payable(msg.sender); 
        gatherer = payable(address(this));
        // pause Token minted
        pauseMy = true;
        // USDC 
        tokenConversions[address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)] = 0.000529 * 1 ether; // 0.000529
    }

function setTokenConversion(address tokenAddress, uint256 conversionRate) external onlyOwner returns(address,uint256){
tokenConversions[tokenAddress] = conversionRate * 1 ether;
return (tokenAddress,tokenConversions[tokenAddress]); // tu moze być jakiś chochlik
}

function settokenPrice(uint256 newPrice) external onlyOwner returns(uint256){
    require(newPrice<tokenPrice," New price must be bigger to generate less tokens ");
    tokenPrice = newPrice; 
    return tokenPrice;
} 
 function depositToken(address tokenAddress, uint256 tokenAmount) external payable returns(bool){
     require(tokenConversions[tokenAddress]>0, "We don't accept this token as deposit");
     require(tokenAmount > 0, "Deposit amount must be greater than 0.");
     require(isGatheringFunds, "Funds gathering has been stopped.");
     IERC20 token = IERC20(tokenAddress);
     require(token.transferFrom(msg.sender, payable(address(this)), tokenAmount), "Token transfer failed.");
     uint256 valueOfToken = tokenConversions[tokenAddress]*tokenAmount;
     depositedTokens[msg.sender][tokenAddress] = depositedTokens[msg.sender][tokenAddress].add(tokenAmount);
      
     totalDepositors = totalDepositors.add(1);
     uint256 tokenToMint = valueOfToken*tokenPrice/1000;
     _mint(msg.sender, tokenToMint);

        totalFundsGathered = totalFundsGathered.add(valueOfToken);

        emit TokensMinted(msg.sender, tokenToMint);
        emit FundsGathered(msg.value);
    return true;
 }



    function deposit() public payable returns(bool){
        require(isGatheringFunds, "Funds gathering has been stopped.");
        require(msg.value > 0, "Deposit amount must be greater than 0.");

     
        depositedEthers[msg.sender] = depositedEthers[msg.sender].add(msg.value);
        totalDepositors = totalDepositors.add(1);
        uint256 tokenToMint = msg.value*tokenPrice/1000;
        _mint(msg.sender, tokenToMint);

        totalFundsGathered = totalFundsGathered.add(msg.value);

        emit TokensMinted(msg.sender, tokenToMint);
        emit FundsGathered(msg.value);
        return true;
    }

    function getTokenAmount(uint256 weiAmount) public view returns (uint256) {
        return weiAmount.mul(10**18).div(tokenPrice);
    }
    // any token 
    function withdrawToken(address tokenAddress, address to, uint256 value) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(to, value), "Transfer failed.");
    }

    function stopGatheringFunds() external onlyOwner {
        isGatheringFunds = false;
    }

    function startGatheringFunds() external onlyOwner {
        isGatheringFunds = true;
    }

    function enableMinting() external onlyOwner {
        isMintingEnabled = true;
    }

    function disableMinting() external onlyOwner {
        isMintingEnabled = false;
    }

    function setTokenPrice(uint256 _tokenPrice) external onlyOwner {
        require(_tokenPrice > 0, "Token price must be greater than 0.");
        tokenPrice = _tokenPrice;
    }


   

        
    // Fallback function - called when someone sends ether to the contract without calling any other function 
    fallback() external payable { 
        deposit(); 
    } 
            
    // Deposit + additinal data
    function sendEtherToContractWithData(uint256 amount, bytes memory data) public payable {
    (bool success,) = address(this).call{value: amount}(data);
    require(success, "Failed to send Ether");
    }
    
    // Withdraw function - called by the beneficiary to withdraw the contract's balance to their own address 
    function withdrawAll() public onlyOwner { 
        uint256 balance = address(this).balance; 
        //beneficiary.transfer(balance); 
        bool sent =  beneficiary.send(balance);
        emit Transfer(address(this), beneficiary, balance); 
    

    emit FundsReleased(balance);
    } 

      function withdrawAmount(uint256 amount) public onlyOwner { 
        require(address(this).balance>amount); 
        //beneficiary.transfer(balance); 
        bool sent =  beneficiary.send(amount);
        emit Transfer(address(this), beneficiary, amount); 
   
    emit FundsReleased(amount);
    }              

      function withdrawAllToken(address tokenAddress) public onlyOwner { 
        IERC20 TokenContract = IERC20(tokenAddress);
        uint256 amount = TokenContract.balanceOf(address(this)); 
        require(amount>0,"There is no such token in this smartcontract");  
		bool success = TokenContract.transfer(beneficiary, amount);
// valueOfToken in Ether
        uint256 valueOfToken = tokenConversions[tokenAddress]*amount;

    emit FundsReleased(valueOfToken);
    }    

          function withdrawAmountOfToken(address tokenAddress, uint256 amount) public onlyOwner { 
        IERC20 TokenContract = IERC20(tokenAddress);
        require(amount <= TokenContract.balanceOf(address(this)),"There is not so much Token on this account");  
		bool success = TokenContract.transfer(payable(msg.sender), amount);
        
// valueOfToken in Ether
        uint256 valueOfToken = tokenConversions[tokenAddress]*amount;

        emit Transfer(address(this), beneficiary, amount); 
    
    emit FundsReleased(valueOfToken);
    }              

function additionalPauseSet() onlyOwner public returns(bool){
    pauseMy = !pauseMy;
    return pauseMy;
}

function _beforeTokenTransfer(address from, address to, uint256 amount) internal whenNotPaused override(ERC20,ERC20Pausable) {
   require(!paused(), "ERC20Pausable: token transfer while paused");
   require(!pauseMy, "ERC20Pausable: token transfer while paused My");
   super.transferFrom(from, to, amount);
  
}
 }