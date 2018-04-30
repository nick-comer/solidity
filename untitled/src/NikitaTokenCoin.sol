pragma solidity ^0.4.13;

/** Интерфейс без возможности предоставления полномочий на передачу
 * взят https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/token/ERC20/ERC20Basic.sol
 */
contract ERC20Basic {
    uint256 public totalSupply;
    function balanceOf(address who) public constant returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

/** Интерфейс добавляющий возможность предоставления полномочий на передачу
 * взят https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/token/ERC20/ERC20.sol
 */
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public constant returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * библотека для безопасных математических операций, чтобы не было переполнений и т.д.
 * взял из https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
 */
library SafeMath {

    function mul(uint256 a, uint256 b) internal returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal returns (uint256) {
        return a / b;
    }

    function sub(uint256 a, uint256 b) internal returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

// Реализация Интерфейса ERC20Basic без возможности предоставления полномочий на передачу
contract BasicToken is ERC20Basic {
    using SafeMath for uint256;

    //все балансы владельцев токенов
    mapping(address => uint256) balances;

    //передача со своего счета на другой кошелек
    function transfer(address to, uint256 value) public returns (bool) {
        require(to != address(0));// чтобы нельзя было удалить деньги, отправив на нулевой адрес
        require(value <= balances[msg.sender]);//на балансе больше или равно чем отправляемая сумма
        // Все остальные проверки (на переполнение в т.ч.) перешли в библотеку SafeMath
        balances[msg.sender] = balances[msg.sender].sub(value); //отнимаем у отправителя
        balances[to] = balances[to].add(value);//добавляем получателю
        Transfer(msg.sender, to, value);//инициируем событие
        return true;
    }

    //проверка своего баланса
    function balanceOf(address owner) public constant returns (uint256 balance) {
        return balances[owner];
    }
}

// Реализация Интерфейса ERC20 с возможностью предоставления полномочий на передачу

contract StandartToken is ERC20, BasicToken {

    //храним двумерный массив кошельков и кошельков, которые могут распоряжаться монетами на определенную сумму, но не более этой суммы.
    mapping (address => mapping(address => uint256)) internal allowed;

    //функция для передачи денег тем, кому это было позволено
    function transferFrom (address from, address to, uint256 value) public returns (bool) {
        require(to != address(0));// чтобы нельзя было удалить деньги, отправив на нулевой адрес
        require(value <= balances[from]);//на балансе больше или равно чем отправляемая сумма
        require(value <= allowed[from][msg.sender]);//отправляемая сумма должна быть меньше или равна разрешенной для распоряжения
        balances[from] = balances[from].sub(value);//отнимаем у отправителя
        balances[to] = balances[to].add(value);//добавляем получателю
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(value); //уменьшаем теперь разрешенную сумму, которой можно оперировать на эту сумму
        Transfer(from, to, value);
        return true;
    }

    //передача полномочий на распоряжение определенной сумме другому кошельку
    function approve(address spender, uint256 value) public returns(bool) {
        allowed[msg.sender][spender] = value;
        Approval(msg.sender, spender, value);
        return true;
    }

    //возвращает на какую сумму может распоряжаться кошельком тот, кому это позволено
    function allowance(address owner, address spender) public constant returns (uint256 remaining) {
        return allowed[owner][spender];
    }

    //функция для повышения размера распорягаемой суммой
    function increaseApproval (address spender, uint addedValue) public returns (bool success) {
        allowed[msg.sender][spender] = allowed[msg.sender][spender].add(addedValue);
        Approval(msg.sender, spender, allowed[msg.sender][spender]);
        return true;
    }

    //функция для понижения размера распорягаемой суммой
    function decreaseApproval (address spender, uint subtractedValue) public returns (bool success) {
        uint oldValue = allowed[msg.sender][spender];
        //если уменьшаемая сумма меньше оставшейся для распоряжения суммы, мы уменьшаем до нуля, если нет, то уменьшаем на разницу.
        if (subtractedValue > oldValue) {
            allowed[msg.sender][spender] = 0;
        } else {
            allowed[msg.sender][spender] = oldValue.sub(subtractedValue);
        }
        Approval(msg.sender, spender, allowed[msg.sender][spender]);
        return true;
    }

    //fall back функция, толком не понял зачем она. В jave есть callback-методы. Может это одно и то же?
    function () public payable {
        revert();
    }
}

//контракт, который хранит функционал, доступный только человеку создавшему эту монету
contract Ownable {
    address public owner;

    //событие переноса
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function Ownable() public {
        owner = msg.sender;
    }

    //создаем модификатор
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    //если кошелек переедет, то перенос будет с помощью этой функции
    function transferOwnership(address newOwner) onlyOwner public {
        require(newOwner != address(0));
        OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

//контракт позволяет выпускать монеты владельцу монет
contract MintableToken is StandartToken, Ownable {

    event Mint(address indexed to, uint256 amount);

    event MintFinished();

    bool public mintingFinished = false;

    address public saleAgent;

    //для назначения торгового агента
    function setSaleAgent(address newSaleAgent) public {
        require(msg.sender == saleAgent || msg.sender == owner);
        saleAgent = newSaleAgent;
    }

    //чеканка монет может проводить или торговый агент или владелец монет
    function mint(address to, uint256 amount) public returns (bool) {
        require (msg.sender == saleAgent && !mintingFinished);
        totalSupply = totalSupply.add(amount);
        balances[to] = balances[to].add(amount);
        Mint(to, amount);
        return true;
    }

    function finishMinting() public returns (bool) {
        require ((msg.sender == saleAgent || msg.sender == owner) && !mintingFinished);
        mintingFinished = true;
        MintFinished();
        return true;
    }
}

contract NikitaTokenCoin is MintableToken {
    string public constant name = "Nikita Token Coin";
    string public constant symbol = "NTC";
    uint32 public constant decimals = 18;
}
