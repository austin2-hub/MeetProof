# MeetProof - Decentralized Proof-of-Meeting Protocol

A Stacks blockchain project that provides trustless verification of real-world meetings through NFT minting.

## Overview

MeetProof enables participants to cryptographically prove they attended the same meeting at a specific time and location. When consensus is reached, all participants receive a commemorative NFT as proof of attendance.

## Features

- **Location Verification**: GPS-based meeting location validation
- **Anti-Spoofing**: Bluetooth/NFC proximity verification
- **Multi-Signature Consensus**: NFT minting when minimum participants reached
- **Immutable Records**: Bitcoin-anchored timestamps for permanent verification
- **Privacy-First**: Encrypted metadata storage

## Project Structure

- `contracts/` - Clarity smart contracts
- `tests/` - Contract test suites
- `settings/` - Clarinet configuration

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet)
- Node.js and npm

### Installation

```bash
npm install
```

### Testing

```bash
clarinet test
```

### Contract Validation

```bash
clarinet check
```

## Architecture

The MeetProof protocol consists of:

1. **Session Creation**: Initiator generates secret code and location parameters
2. **Participant Verification**: Users submit location proof and secret
3. **Consensus Minting**: NFTs auto-mint when minimum participants verified
4. **Metadata Storage**: Meeting details stored in Gaia/IPFS

## Security Features

- SHA256 secret hashing
- Geographic radius validation (100m default)
- Time-bounded sessions
- One-time secret usage
- Bluetooth proximity verification

## License

MIT License
