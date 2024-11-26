# SoulStamp: Non-transferable Soulbound Token System

SoulStamp is a robust implementation of soulbound tokens (SBTs) on the Stacks blockchain, providing non-transferable tokens that are permanently linked to user identities. The system includes comprehensive emergency management features and multi-signature governance.

## Features

### Core Token System
- **Non-transferable Tokens**: Permanently linked to user identities
- **Flexible Categories**: Support for multiple credential types
- **Metadata Management**: Detailed token information storage
- **Scalable Architecture**: Support for up to 50 tokens per user

### Emergency Management
- **Multi-signature Governance**: Requires guardian approval for emergency actions
- **Time-bound Proposals**: Emergency proposals expire after 24 hours
- **Guardian System**: Reputation-based voting system
- **Cooldown Periods**: Prevents abuse of emergency features

## Technical Specifications

### Token Structure
```clarity
{
    name: string-ascii,
    description: string-ascii,
    category: string-ascii,
    timestamp: uint,
    issuer: principal,
    emergency-status: bool,
    revoked: bool
}
```

### Guardian System
- Minimum required approvals: 3
- Proposal duration: 144 blocks (~24 hours)
- Emergency cooldown: 720 blocks (~5 days)

## Setup and Deployment

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for contract deployment
- Access to Stacks blockchain (testnet/mainnet)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-repo/soulstamp.git
cd soulstamp
```

2. Deploy the contract:
```bash
clarinet deploy
```

### Initial Configuration

1. Add categories:
```clarity
(contract-call? .soulstamp add-category "CERTIFICATION")
(contract-call? .soulstamp add-category "MEMBERSHIP")
(contract-call? .soulstamp add-category "ACHIEVEMENT")
```

2. Set up guardians (minimum 3 recommended):
```clarity
(contract-call? .soulstamp add-guardian 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## Usage

### Issuing Tokens

```clarity
(contract-call? .soulstamp issue-token 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  "Advanced Developer" 
  "Completed advanced development course" 
  "CERTIFICATION")
```

### Emergency Unlock Process

1. Propose emergency unlock:
```clarity
(contract-call? .soulstamp propose-emergency-unlock 
  u1 
  "Lost access to primary wallet")
```

2. Guardian voting:
```clarity
(contract-call? .soulstamp vote-on-emergency u1 true)
```

3. Execute unlock (after sufficient votes):
```clarity
(contract-call? .soulstamp execute-emergency-unlock u1)
```

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Already exists |
| u102 | Invalid user |
| u103 | Token not found |
| u104 | Insufficient approvals |
| u105 | Already voted |
| u106 | No emergency |
| u107 | Expired |
| u108 | Category inactive |
| u109 | Invalid guardian |

## Security Considerations

### Token Security
- Tokens are non-transferable by design
- Only contract owner can issue tokens
- Each token action is logged on-chain

### Emergency System Security
- Multi-signature requirement prevents single-point failures
- Time-bound proposals prevent stale executions
- Cooldown periods prevent spam attacks
- Guardian reputation system ensures quality voting

## Testing

Run the test suite:
```bash
clarinet test
```

Key test scenarios:
- Token issuance and validation
- Category management
- Guardian voting mechanics
- Emergency proposal lifecycle
- Error handling and edge cases

## Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -am 'Add new feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Submit a pull request


### Phase 1 (Current)
- ✅ Basic token implementation
- ✅ Emergency management system
- ✅ Guardian voting system

### Phase 2 (Planned)
- 🔄 Enhanced metadata support
- 🔄 Integration with decentralized identity systems
- 🔄 Advanced guardian reputation mechanics

## Acknowledgments

Special thanks to:
- Stacks Foundation
- Clarity language developers


