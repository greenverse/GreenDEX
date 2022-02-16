//SPDX-License-Identifier: Unlicense

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import './SafeMath.sol';
import './Ownable.sol';
import './IERC20.sol';

contract GreenDEX {
    using SafeMath for uint256;

    struct Balance {
        uint available;
        uint reserved;
    }

    struct Order {
        address token;
        address account;
        uint amount;
        uint price;
        bool buying;
    }

    uint public lastOrderId;

    mapping (address => Balance) private balances;
    mapping (address => mapping (address => Balance)) private tokenBalances;

    mapping (uint => Order) private ordersById;

    function deposit() payable public {
        balances[msg.sender].available = balances[msg.sender].available.add(msg.value);
    }

    function withdraw(uint amount) public returns (bool) {
        require(balances[msg.sender].available >= amount);
        
        balances[msg.sender].available = balances[msg.sender].available.sub(amount);
        msg.sender.transfer(amount);
        
        return true;
    }

    function getBalance(address addr) public view returns (uint) {
        return balances[addr].available;
    }

    function getReserved(address addr) public view returns (uint) {
        return balances[addr].reserved;
    }

    function depositTokens(IERC20 token, uint amount) public returns (bool) {
        require(token.transferFrom(msg.sender, address(this), amount));
        
        tokenBalances[address(token)][msg.sender].available = tokenBalances[address(token)][msg.sender].available.add(amount);
        
        return true;
    }

    function withdrawTokens(IERC20 token, uint amount) public returns (bool) {
        require(tokenBalances[address(token)][msg.sender].available >= amount);
        require(token.transfer(msg.sender, amount));
        
        tokenBalances[address(token)][msg.sender].available = tokenBalances[address(token)][msg.sender].available.sub(amount);
        
        return true;
    }

    function getTokenBalance(address token, address addr) public view returns (uint) {
        return tokenBalances[token][addr].available;
    }

    function getReservedTokens(address token, address addr) public view returns (uint) {
        return tokenBalances[token][addr].reserved;
    }

    function sellTokens(address token, uint amount, uint price) public returns (bool) {
        require(tokenBalances[token][msg.sender].available >= amount);

        tokenBalances[token][msg.sender].available = tokenBalances[token][msg.sender].available.sub(amount);
        tokenBalances[token][msg.sender].reserved = tokenBalances[token][msg.sender].reserved.add(amount);

        ordersById[lastOrderId] = Order(token, msg.sender, amount, price, false);

        lastOrderId = lastOrderId++;

        return true;
    }

    function buyTokens(address token, uint amount, uint price) public returns (bool) {
        uint total = amount * price;

        require(balances[msg.sender].available >= total);

        balances[msg.sender].available = balances[msg.sender].available.sub(total);
        balances[msg.sender].reserved = balances[msg.sender].reserved.add(total);

        ordersById[lastOrderId] = Order(token, msg.sender, amount, price, true);

        lastOrderId = lastOrderId++;

        return true;
    }

    function cancelOrder(uint id) public {
        Order storage order = ordersById[id];

        address account = order.account;
        address token = order.token;

        require(account == msg.sender);

        if (order.buying) {
            uint total = order.price.mul(order.amount);

            balances[account].reserved = balances[account].reserved.sub(total);
            balances[account].available = balances[account].available.add(total);
        } else {
            tokenBalances[token][account].reserved = tokenBalances[token][account].reserved.sub(order.amount);
            tokenBalances[token][account].available = tokenBalances[token][account].available.add(order.amount);
        }

        delete(ordersById[id]);
    }

    function getOrderById(uint id) public view returns(address account, address token, uint amount, uint price, bool buying) {
        Order storage order = ordersById[id];
        return (order.account, order.token, order.amount, order.price, order.buying);
    }
}