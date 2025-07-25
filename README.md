# Open Source Learning Rewards

A decentralized platform that compensates creators of educational content through usage metrics on the Stacks blockchain.

## Overview

This smart contract enables creators to register educational content and earn rewards based on user interactions including views, completions, and ratings. The platform uses a transparent reward calculation system that incentivizes quality content creation.

## Features

### For Content Creators
- **Profile Creation**: Register as a content creator with username and bio
- **Content Registration**: Submit educational content with metadata and reward parameters
- **Earnings Tracking**: Monitor total earnings and reputation score
- **Reward Withdrawal**: Withdraw earned rewards from the platform

### For Learners
- **Content Interaction**: View and complete educational content
- **Rating System**: Rate content from 1-5 stars to help others discover quality material
- **Progress Tracking**: Track learning progress across different content

### Platform Features
- **Reward Pool Management**: Sustainable reward distribution system
- **Usage Metrics**: Transparent tracking of views, completions, and ratings
- **Platform Fee**: 5% platform fee for sustainability and development
- **Reputation System**: Creator reputation based on content quality and engagement

## Smart Contract Functions

### Public Functions

#### Creator Functions
- `create-creator-profile(username, bio)` - Register as a content creator
- `register-content(title, description, content-hash, category, base-reward)` - Submit new educational content
- `calculate-rewards(content-id)` - Calculate and distribute rewards for content
- `withdraw-earnings(amount)` - Withdraw earned rewards

#### User Functions
- `interact-with-content(content-id, interaction-type)` - Record content interaction (view/complete)
- `rate-content(content-id, rating)` - Rate content (1-5 stars)

#### Admin Functions
- `fund-reward-pool(amount)` - Add funds to the reward pool (owner only)

### Read-Only Functions
- `get-content(content-id)` - Get content details
- `get-creator-profile(creator)` - Get creator profile information
- `get-user-interaction(user, content-id)` - Get user interaction history
- `get-user-balance(user)` - Get user's reward balance
- `get-reward-pool()` - Get current reward pool balance
- `get-content-rewards(content-id)` - Get content reward parameters

## Reward Calculation

Rewards are calculated based on:
- **Base Reward**: Set by content creator during registration
- **View Multiplier**: 10 points per view
- **Completion Multiplier**: 100 points per completion
- **Rating Multiplier**: Average rating × 50 points

Total Creator Reward = Base Reward + (Views × 10) + (Completions × 100) + (Avg Rating × 50) - Platform Fee (5%)

## Content Categories

The platform supports various educational content categories:
- Programming & Development
- Mathematics & Science
- Language Learning
- Business & Finance
- Arts & Design
- Health & Wellness
- And more...

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for transactions
- Basic understanding of Clarity smart contracts

### Deployment
1. Clone this repository
2. Install dependencies: `clarinet check`
3. Run tests: `clarinet test`
4. Deploy to testnet: `clarinet publish --testnet`

## Usage Examples

### Register as Creator
```clarity
(contract-call? .learning-rewards create-creator-profile "john_educator" "Experienced math teacher with 10+ years")
```

### Submit Content
```clarity
(contract-call? .learning-rewards register-content 
  "Introduction to Calculus" 
  "Complete beginner's guide to calculus concepts" 
  "abc123hash..." 
  "Mathematics" 
  u1000)
```

### Interact with Content
```clarity
(contract-call? .learning-rewards interact-with-content u1 "view")
(contract-call? .learning-rewards interact-with-content u1 "complete")
(contract-call? .learning-rewards rate-content u1 u5)
```

## Technical Specifications

- **Language**: Clarity
- **Blockchain**: Stacks
- **Contract Size**: ~300 lines
- **Gas Optimization**: Efficient data structures and minimal external calls
- **Security**: Input validation and access control mechanisms

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions or support, please open an issue in the GitHub repository.

## Roadmap

- [ ] Integration with IPFS for content storage
- [ ] Mobile app development
- [ ] Advanced analytics dashboard
- [ ] Multi-language support
- [ ] NFT certificates for course completion
## Recent Updates
- Added complete smart contract implementation
- Enhanced reward calculation system
- Improved documentation
