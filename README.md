# Bridge Operator Standard

## Overview

This repository contains the contracts for bidirectional bridge operator standard for [Aion network's AIP #005](https://github.com/Mavennet/AIP/blob/master/AIP-005/AIP%23005.md). 

A standard to meet the functionality requirements of a bidirectional bridge operator to support two way flow of tokens or assets.

#### Cross Chain Functionality

To send a cross chain token transfer from the source chain to the destination chain, the token holder must freeze the token(s) on the source chain using the `freeze` function, emitting an event which specifies the token receiver address on the destination chain. The Bridge Operator Contract then relays the transaction to the destination chain using the `thaw` function, thawing the appropriate token amount to the token receiver address on the destination chain.