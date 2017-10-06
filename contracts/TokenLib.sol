pragma solidity ^0.4.9;

import "./SafeMathLib.sol";

// Tokens records a token balance for each address
// Maintains a count of the total supply
// There is a special account at address 0x0 called the Public Account
// A new address may be initialized with an initial balance using the init function
// Tokens may be transferred from one address to another using the transfer function
// A special transferAsMuchAsPossibleOf function transfers the requested amount, or the senders total balance, whichever is smaller
// the balanceOf function returs the balance of the given address
// The createMoney function adds new tokens to the Public Account
// The destroyMoney function burns tokens from the Public Account
// The Tranfer event is fired whenever a transfer occurs
library TokenLib {
  using SafeMathLib for uint;

  address constant public PUBLIC_ACCOUNT = 0;

  function getPublicAccount() public constant returns(address) {
    return PUBLIC_ACCOUNT;
  }

  struct Tokens {
    mapping (address => uint) balances;
    uint totalSupply;
  }

  event Transfer(address indexed from, address indexed to, uint value);

  function init(Tokens storage self, address addr, uint initialBalance) public {
      assert(self.balances[addr] == 0);
      self.balances[addr] = initialBalance;
      self.totalSupply = self.totalSupply.plus(initialBalance);
  }

  function transfer(Tokens storage self, address from, address to, uint value) {
    if (value == 0) {
      return;
    }
    self.balances[to] = self.balances[to].plus(value);
    self.balances[from] = self.balances[from].minus(value);
    Transfer(from, to, value);
  }

  function transferAsMuchAsPossibleOf(Tokens storage self, address from, address to, uint value) public {
    uint balance = balanceOf(self, from);
    uint amountToTransfer = balance < value ? balance : value;
    transfer(self, from, to, amountToTransfer);
  }

  function balanceOf(Tokens storage self, address owner) constant returns (uint balance) {
    return self.balances[owner];
  }

  function createMoney(Tokens storage self, uint amount) public {

      self.balances[PUBLIC_ACCOUNT] = self.balances[PUBLIC_ACCOUNT].plus(amount);
      self.totalSupply = self.totalSupply.plus(amount);

      Transfer(PUBLIC_ACCOUNT, PUBLIC_ACCOUNT, amount);
  }

  function destroyMoney(Tokens storage self, uint amount) public {
    if (amount > self.balances[PUBLIC_ACCOUNT]) {
        amount = self.balances[PUBLIC_ACCOUNT];
    }

    self.balances[PUBLIC_ACCOUNT] = self.balances[PUBLIC_ACCOUNT].minus(amount);
    self.totalSupply = self.totalSupply.minus(amount);

    Transfer(PUBLIC_ACCOUNT, PUBLIC_ACCOUNT, amount);
  }
}