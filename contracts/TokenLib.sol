pragma solidity ^0.4.9;

import "./SafeMathLib.sol";

library TokenLib {
  using SafeMathLib for uint;

  address constant PUBLIC_ACCOUNT = 0;

  struct TokenStorage {
    mapping (address => uint) balances;
    uint totalSupply;
  }

  event Transfer(address indexed from, address indexed to, uint value);

  function init(TokenStorage storage self, address addr, uint initialBalance) public {
      assert(self.balances[addr] == 0);
      self.balances[addr] = initialBalance;
      self.totalSupply = self.totalSupply.plus(initialBalance);
  }

  function transfer(TokenStorage storage self, address from, address to, uint value) {
    self.balances[to] = self.balances[to].plus(value);
    self.balances[from] = self.balances[from].minus(value);
    Transfer(from, to, value);
  }

  function transferAsMuchAsPossibleOf(TokenStorage storage self, address from, address to, uint value) public {
    uint balance = self.balanceOf(from);
    uint amountToTransfer = balance < value ? balance : value;
    self.transfer(from, to, amountToTransfer);
  }

  function balanceOf(TokenStorage storage self, address owner) constant returns (uint balance) {
    return self.balances[owner];
  }

  function createMoney(TokenStorage storage self, uint amount) public {

      self.balances[PUBLIC_ACCOUNT] = self.balances[PUBLIC_ACCOUNT].plus(amount);
      self.totalSupply = self.totalSupply.plus(amount);

      Transfer(PUBLIC_ACCOUNT, PUBLIC_ACCOUNT, amount);
  }

  function destroyMoney(TokenStorage storage self, uint amount) private {
    if (amount > self.balances[PUBLIC_ACCOUNT]) {
        amount = self.balances[PUBLIC_ACCOUNT];
    }

    self.balances[PUBLIC_ACCOUNT] = self.balances[PUBLIC_ACCOUNT].minus(amount);
    self.totalSupply = self.totalSupply.minus(amount);

    Transfer(PUBLIC_ACCOUNT, PUBLIC_ACCOUNT, amount);
  }
}