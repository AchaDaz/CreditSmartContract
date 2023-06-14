// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract InstallmentAgreement {
	
	// Переменные для хранения информации о договоре кредита
	address public buyer;
	address public seller1;
	address public seller2;
	uint public price;
	uint public money1;
	uint public money2;
	uint public paymentsAmount;
	uint public paymentInterval;
	uint public commission;
	uint private debt;
	uint private completionDate;
	uint private balance;
	uint public paymentNumber;
	
	// Маппинг для хранения информации о платежах
	mapping (uint => Payment) private payments;
	
	// Структура для хранения информации о платеже
	struct Payment {
		uint owed;
		uint paid;
		uint date;
	}
	
	// Событие для оповещения о новом платеже
	event PaymentMade(uint indexed paymentNumber, uint indexed amount);
	
	// Конструктор для создания договора кредита
	constructor(address _buyer, address _seller1, address _seller2, uint _price, uint _paymentsAmount, uint _paymentInterval, uint _commission) {
		buyer = _buyer;
		seller1 = _seller1;
		seller2 = _seller2;
		price = _price;
		money1 = 0;
		money2 = 0;
		paymentsAmount = _paymentsAmount;
		paymentInterval = _paymentInterval;
		commission = _commission;
		debt = 0;
		balance = 0;
		paymentNumber = 0;
		completionDate = block.timestamp + (_paymentInterval * 60 * 24 * 30 * _paymentsAmount);
		
	}
	
	// Перевод валюты кредитора 1 на счет смарт-контракта
	function loadMoney_creditor1() public payable {
		require(msg.sender == seller1, "Only creditor_1 can give money");
		require(balance == 0 || price == msg.value + balance, "The total payment must be equal to the price");
		require(msg.value < price, "You trying to transact more than needed");
		money1 = msg.value;
		balance = balance + msg.value;
	}

	// Перевод валюты кредитора 2 на счет смарт-контракта
	function loadMoney_creditor2() public payable {
		require(msg.sender == seller2, "Only creditor_2 can give money");
		require(balance == 0 || price == msg.value + balance, "The total payment must be equal to the price");
		require(msg.value < price, "You trying to transact more than needed");
		money2 = msg.value;
		balance = balance + msg.value;
	}


	 // Перевод валюты кредитора на счет смарт-контракта
	function getMoney() public payable {
		require(msg.sender == buyer, "Only buyer can get money");
		require(balance != 0 && money1 != 0 && money2 != 0, "No money on contract");
		address payable _to = payable(buyer);
		debt = balance + balance*commission/100;
		_to.transfer(address(this).balance);
		balance = 0;
	}


	// Функция для получения текущей суммы долга по договору кредита
	function getDebt() public view returns (uint) {
		return debt;
	}
	
	// Функция для получения даты окончания договора кредита
	function getCompletionDate() public view returns (uint) {
		return completionDate;
	}
	
	// Функция для оплаты очередного платежа
	function makePayment() public payable {
		require(msg.sender == buyer, "Only buyer can make a payment");
		require(debt > 0, "The debt is already paid");
		require(paymentNumber < paymentsAmount, "All payments are already made");
		require(block.timestamp <= completionDate, "The agreement is already expired");
		require(msg.value == ((price + price*commission/100) / paymentsAmount), "Incorrect payment amount");
		payments[paymentNumber].owed = debt;
		payments[paymentNumber].paid = msg.value;
		payments[paymentNumber].date = block.timestamp;
		paymentNumber += 1;
		if (paymentNumber == paymentsAmount) {
			debt = 0;
		} else {
			debt = debt - msg.value;
		}
		balance = balance + msg.value;
		emit PaymentMade(paymentNumber, msg.value);
	}
	
	// Функция для получения информации о платеже по его номеру
	function getPayment(uint NumberOfPayement) public view returns (uint, uint, uint) {
		return (payments[NumberOfPayement].owed, payments[NumberOfPayement].paid, payments[NumberOfPayement].date);
	}
	
	// Функция для получения общей суммы платежей
	function getTotalPayments() public view returns (uint) {
		uint total = 0;
		for (uint i = 0; i < paymentsAmount; i++) {
			total += payments[i].paid;
		}
		return total;
	}

	// Проверка баланса для продавца
	function getBalance() public view returns (uint) {
		require(msg.sender == seller1 || msg.sender == seller2, "Only seller can check balance");
		return balance;
	}

	// Функция для вывода средств на аккаунты кредиторов
	function withdrawAll() public {
		require(msg.sender == seller1 || msg.sender == seller2, "Only seller can withdraw");
		require(balance > 0, "The balance is at zero");
		address payable _to1 = payable(seller1);
		address payable _to2 = payable(seller2);
		uint _percentage1 = money1/(money1 + money2);
		_to1.transfer(address(this).balance * _percentage1);
		_to2.transfer(address(this).balance * (1 - _percentage1));
		balance = 0;
	}
	
	// Функция для получения общей суммы комиссии, которую осталось выплатить
	function getTotalCommission() public view returns (uint) {
		return debt * commission / 100;
	}
	
	// Функция для получения текущей суммы, которую должен заплатить заемщик
	function getCurrentPaymentAmount() public view returns (uint) {
		if (paymentNumber < paymentsAmount && debt > 0 && block.timestamp <= completionDate) {
			uint All_payment =  price + price*commission/100;
				return All_payment / paymentsAmount;
		} else {
			return 0;
		}
	}

	// Функция для досрочного закрытия кредита
	function makePaymentAll() public payable {
		require(msg.sender == buyer, "Only buyer can make a payment");
		require(debt > 0, "The debt is already paid");
		require(paymentNumber < paymentsAmount, "All payments are already made");
		require(block.timestamp <= completionDate, "The agreement is already expired");
		require(msg.value == debt, "Incorrect payment amount");
		payments[paymentNumber].owed = debt;
		payments[paymentNumber].paid = msg.value;
		payments[paymentNumber].date = block.timestamp;
		paymentNumber += 1;
		debt = 0;
		balance += msg.value;
		completionDate = block.timestamp;
		emit PaymentMade(paymentNumber, msg.value);
	}
}