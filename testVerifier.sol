// TEST for the verifying plugin of remix
//
// THIS CODE verify withour problems on ropsten using the plugin (see at address 0x4ecb5eF92AD7434a1fB41d69fDA423D4000b6641 a verified instance)
// BUT IT DOES NOT VERIFY AT ALL if compiled using 0.6.2 solc


pragma solidity 0.4.26;
//pragma solidity 0.6.2;        // to be used to compile with solc 0.6.2 

contract testVerify {
    uint test;
    address   owner;
    // address payable owner;   // to be used to compile with solc 0.6.2 
    
    constructor() public {
        test = 10;
    }
    
    function setTest(uint param) public {
        test = param;
        owner = msg.sender;
    }
    
    function readTest() view public returns (uint _out) {
        _out = test;
    }
    
     
    function killThis() public {
            require(msg.sender == owner);
            selfdestruct(owner);
        }
    
}