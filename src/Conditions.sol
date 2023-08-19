// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Conditional {
    // holds core key so authorized to call any function on keep
    // would it be recursive if we call 'relay' on keep with this contract as the recipient and this contract calls 'relay' on keep with the calldata in it
    // {
    //     conditions: [
    //         {
    //             type: "price",
    //             amount: 1000 // in usd
    //             address: '0xfucku'
    //         }
    //     ],
    //     actions: [
    //         {
    //                op
    //                to
    //                value
    //                data
    //
    //         }
    //     ]
    // }
}
