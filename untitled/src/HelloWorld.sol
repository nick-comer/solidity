pragma solidity ^0.4.13;

contract HelloWorld {
    string returnedString = "Hello, World!";

    function getString() public constant returns (string) {
        return returnedString;
    }

    function setString(string newDate) public {
        returnedString = newDate;
    }
}