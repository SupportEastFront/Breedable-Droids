// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MyToken5 is ERC20, ERC20Burnable, Pausable, Ownable {
        using SafeMath for uint256;
        uint256 public totalFundsGathered;
    bool public isGatheringFunds;

    uint256 public tokenPriceMultiplicator;
    uint256 public totalDepositors;
    address payable beneficiary;
    address payable gatherer;
    string public urlToWhitepaper;
    string public urlToRegulations;
    string public stateOfProject;

    mapping(address => mapping(address => uint256)) public depositedTokens;// donator , address of token, volume of token
    mapping(address => uint256) public depositedEthers;
    mapping(address => uint256) public tokenConversions;


    event TokensMinted(address indexed to, uint256 amount);
    event FundsGathered(uint256 amount);
    event FundsReleased(uint256 amount);

    constructor() ERC20("MyToken", "MTK") {
        isGatheringFunds = true;
        tokenPriceMultiplicator = 1000; //initial token price is 1000 as 1 eth = 1 X token
        beneficiary = payable(msg.sender); 
        gatherer = payable(address(this));


        // USDC 
        tokenConversions[address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)] = 0.000529 * 1 ether; // 0.000529
        mintByOnwer(beneficiary,100*1 ether);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) internal {
        require(isGatheringFunds, "Funds gathering has been stopped.");
        _mint(to, amount);
    }
    function mintByOnwer(address to, uint256 amount) public onlyOwner {
        require(isGatheringFunds, "Funds gathering has been stopped.");
        _mint(to, amount);
    }
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function deposit() public payable returns(bool){
        require(isGatheringFunds, "Funds gathering has been stopped.");
        require(msg.value > 0, "Deposit amount must be greater than 0.");

     
       depositedEthers[msg.sender] = depositedEthers[msg.sender].add(msg.value);
        totalDepositors = totalDepositors.add(1);
        uint256 tokenToMint = msg.value*tokenPriceMultiplicator/1000;
        //community and devs tokens +15%
        _mint(beneficiary, tokenToMint.mul(15).div(100));
        _mint(msg.sender, tokenToMint);

        totalFundsGathered = totalFundsGathered.add(msg.value);

        emit TokensMinted(msg.sender, tokenToMint);
        emit TokensMinted(beneficiary, tokenToMint.mul(15).div(100));
        emit FundsGathered(msg.value);
        return true;
    }
        // Fallback function - called when someone sends ether to the contract without calling any other function 
    fallback() external payable { 
        deposit(); 
    } 
    receive() external payable { 
        deposit(); 
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
        if(sent){}else{
            revert();
        }
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

        function howManyTokensIwillGetForMyEther(uint256 weiAmount) public view returns (uint256) {
        return weiAmount.mul(10**18).mul(tokenPriceMultiplicator).div(1000);
    }
    // any token which might entered the smartcontract by accident
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
// seting / 1000 value of ether as conversion rate for certain token
    function setTokenConversion(address tokenAddress, uint256 conversionRate) external onlyOwner returns(address,uint256){
tokenConversions[tokenAddress] = conversionRate.mul(1 ether).div(1000);
return (tokenAddress,tokenConversions[tokenAddress]); // tu moze być jakiś chochlik
}

function settokenPriceMultiplicator(uint256 newPrice) external onlyOwner returns(uint256){
    require(newPrice<tokenPriceMultiplicator," New price must be bigger to generate less tokens ");
    tokenPriceMultiplicator = newPrice; 
    return tokenPriceMultiplicator;
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
     uint256 tokenToMint = valueOfToken*tokenPriceMultiplicator/1000;
     _mint(msg.sender, tokenToMint);
     _mint(beneficiary, tokenToMint.mul(15).div(100));
        totalFundsGathered = totalFundsGathered.add(valueOfToken);

        emit TokensMinted(msg.sender, tokenToMint);
        emit TokensMinted(beneficiary, tokenToMint.mul(15).div(100));
        emit FundsGathered(msg.value);
    return true;
 }

    function setUrlToWhitepaper(string memory newUrl) public onlyOwner{
        urlToWhitepaper = newUrl;
    }

    function setUrlToRegulations(string memory newUrl) public onlyOwner{
        urlToRegulations = newUrl;
    }

      function setState(string memory state) public onlyOwner{
        stateOfProject = state;
    }  
}
