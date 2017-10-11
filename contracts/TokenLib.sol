pragma solidity ^0.4.9;

import "./SafeMathLib.sol";
import "./Storage.sol";

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

  bytes32 constant public F_BALANCE = sha3("F_TOKEN_BALANCE");
  bytes32 constant public F_TOTAL_SUPPLY = sha3("F_TOKEN_TOTAL_SUPPLY");

  function getPublicAccount() public constant returns(address) {
    return PUBLIC_ACCOUNT;
  }

  event Transfer(address indexed from, address indexed to, uint value);

  function init(Storage self, address addr, uint initialBalance) public {
      assert(balanceOf(self, addr) == 0);
      self.setUInt(F_BALANCE, addr, initialBalance);
      self.setUInt(F_TOTAL_SUPPLY, self.getUInt(F_TOTAL_SUPPLY).plus(initialBalance));
  }

  function transfer(Storage self, address from, address to, uint value) {
    if (value == 0) {
      return;
    }
    self.setUInt(F_BALANCE, from, self.getUInt(F_BALANCE, from).minus(value));
    self.setUInt(F_BALANCE, to, self.getUInt(F_BALANCE, to).plus(value));

    Transfer(from, to, value);
  }

  function transferAsMuchAsPossibleOf(Storage self, address from, address to, uint value) public {
    uint balance = balanceOf(self, from);
    uint amountToTransfer = balance < value ? balance : value;
    transfer(self, from, to, amountToTransfer);
  }

  function balanceOf(Storage self, address owner) constant returns (uint balance) {
    return self.getUInt(F_BALANCE, owner);
  }

  function getTotalSupply(Storage self) constant public returns (uint) {
    return self.getUInt(F_TOTAL_SUPPLY);
  }

  function createMoney(Storage self, uint amount) public {

      self.setUInt(F_BALANCE, PUBLIC_ACCOUNT, self.getUInt(F_BALANCE, PUBLIC_ACCOUNT).plus(amount));
      self.setUInt(F_TOTAL_SUPPLY, self.getUInt(F_TOTAL_SUPPLY).plus(amount));

      Transfer(PUBLIC_ACCOUNT, PUBLIC_ACCOUNT, amount);
  }

  function destroyMoney(Storage self, uint amount) public {
    if (amount > self.getUInt(F_BALANCE, PUBLIC_ACCOUNT)) {
        amount = self.getUInt(F_BALANCE, PUBLIC_ACCOUNT);
    }

    self.setUInt(F_BALANCE, PUBLIC_ACCOUNT, self.getUInt(F_BALANCE).minus(amount));
    self.setUInt(F_TOTAL_SUPPLY, self.getUInt(F_TOTAL_SUPPLY).minus(amount));

    Transfer(PUBLIC_ACCOUNT, PUBLIC_ACCOUNT, amount);
  }
}