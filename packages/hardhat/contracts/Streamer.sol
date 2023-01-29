// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;


import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";


error Streamer__User_already_running_a_channel();
error Streamer__Less_than_required_amount();
error Streamer__Signer_is_not_running_the_channel();
error Streamer__Transfer_failed();
error Streamer__User_channel_is_not_open();
error Streamer__User_channel_is_not_closed();
error Streamer__User_time_is_not_before_current_time();


/**
 * @title State Channel Application.
 * @author ABossOfMyself
 * @notice A minimal state channel application.
 * @dev Created a minimal state channel application, where users seeking a service lock collateral on-chain with a single transaction, interact with their service provider entirely off-chain, and finalize the interaction with a second on-chain transaction.
 */


contract Streamer is Ownable {

    /* ========== EVENTS ========== */


    event Opened(address user, uint256 amount);

    event Challenged(address user);

    event Withdrawn(address user, uint256 amount);

    event Closed(address user);


    /* ========== MAPPINGS ========== */


    mapping(address => uint256) balances;

    mapping(address => uint256) canCloseAt;


    /* ========== MUTATIVE FUNCTIONS ========== */


    function fundChannel() public payable {
        
        if(balances[msg.sender] != 0) revert Streamer__User_already_running_a_channel();

        if(msg.value < 0.5 ether) revert Streamer__Less_than_required_amount();

        balances[msg.sender] = msg.value;

        emit Opened(msg.sender, msg.value);
    }



    function timeLeft(address channel) public view returns(uint256) {

        if(canCloseAt[channel] == 0) revert Streamer__User_channel_is_not_closed();

        return canCloseAt[channel] - block.timestamp;
    }



    function withdrawEarnings(Voucher calldata voucher) public onlyOwner {

        // like the off-chain code, signatures are applied to the hash of the data
        // instead of the raw data itself

        bytes32 hashed = keccak256(abi.encode(voucher.updatedBalance));

        // The prefix string here is part of a convention used in ethereum for signing
        // and verification of off-chain messages. The trailing 32 refers to the 32 byte
        // length of the attached hash message.
        //
        // There are seemingly extra steps here compared to what was done in the off-chain
        // `reimburseService` and `processVoucher`. Note that those ethers signing and verification
        // functions do the same under the hood.
        //
        // again, see https://blog.ricmoo.com/verifying-messages-in-solidity-50a94f82b2ca

        bytes memory prefixed = abi.encodePacked("\x19Ethereum Signed Message:\n32", hashed);

        bytes32 prefixedHashed = keccak256(prefixed);

        address signer = ecrecover(prefixedHashed, voucher.sig.v, voucher.sig.r, voucher.sig.s);

        if(balances[signer] <= voucher.updatedBalance) revert Streamer__Signer_is_not_running_the_channel();

        uint256 payment = balances[signer] - voucher.updatedBalance;

        balances[signer] -= payment;

        address owner = owner();

        (bool success, ) = owner.call{value: payment}("");

        if(!success) revert Streamer__Transfer_failed();

        emit Withdrawn(owner, payment);
    }

    

    function challengeChannel() public {

        if(balances[msg.sender] == 0) revert Streamer__User_channel_is_not_open();

        canCloseAt[msg.sender] = block.timestamp + 30 seconds;

        emit Challenged(msg.sender);
    }

    

    function defundChannel() public {

        if(canCloseAt[msg.sender] == 0) revert Streamer__User_channel_is_not_closed();

        if(canCloseAt[msg.sender] > block.timestamp) revert Streamer__User_time_is_not_before_current_time();

        (bool success, ) = msg.sender.call{value: balances[msg.sender]}("");

        if(!success) revert Streamer__Transfer_failed();

        balances[msg.sender] = 0;

        emit Closed(msg.sender);
    }



    struct Voucher {

        uint256 updatedBalance;

        Signature sig;
    }



    struct Signature {

        bytes32 r;

        bytes32 s;

        uint8 v;
    }
}