# Olas - Picture-First Decentralized Social Media

<div align="center">
  <img src="Resources/olas-icon.png" alt="Olas Logo" width="200"/>
  
  [![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey)](https://developer.apple.com/ios/)
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
  [![NDKSwift](https://img.shields.io/badge/NDKSwift-0.2.0-blue)](https://github.com/pablof7z/NDKSwift)
  [![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
</div>

## Overview

Olas is a cutting-edge decentralized social media application built on the [Nostr protocol](https://nostr.com), designed with a strong emphasis on visual content sharing. It combines the power of decentralized social networking with professional-grade photo creation and editing tools, creating a unique platform for visual storytelling that is censorship-resistant and user-controlled.

## Features

### 📸 Picture-First Content Experience
- **Visual Feed**: Dynamic image and video feed with progressive loading using Blurhash
- **Multi-Image Posts**: Share multiple images in a single post
- **Professional Camera**: In-app camera with timer, flash control, and composition grid
- **Advanced Image Editor**: 12 custom filters and granular adjustments for brightness, contrast, saturation, and rotation
- **Decentralized Storage**: Images uploaded to multiple Blossom servers using [NIP-92](https://github.com/nostr-protocol/nips/blob/master/92.md)

### 🔐 Nostr-Native Social Features
- **Self-Sovereign Identity**: Control your cryptographic keys (nsec/pubkey)
- **Rich Interactions**: Likes, threaded replies ([NIP-22](https://github.com/nostr-protocol/nips/blob/master/22.md)), and Bitcoin Lightning zaps ([NIP-57](https://github.com/nostr-protocol/nips/blob/master/57.md))
- **Rich Text Editor**: Real-time @mention suggestions and #hashtag autocomplete
- **Encrypted DMs**: Private messaging with support for [NIP-44](https://github.com/nostr-protocol/nips/blob/master/44.md) encryption
- **Ephemeral Stories**: 24-hour disappearing visual content

### 🔍 Discovery & Exploration
- **Explore Tab**: Masonry grid layout for content discovery
- **Category Filtering**: Art, Photography, Nature, and other categories
- **Trending Hashtags**: Real-time popularity indicators with velocity metrics
- **Universal Search**: Find posts, hashtags, and users

### ⚡ Integrated Bitcoin Lightning & Cashu Wallet
- **NIP-60 Wallet**: Built-in support for Bitcoin Lightning and Cashu ecash
- **Balance Management**: Visual breakdown of funds across multiple Cashu mints
- **Seamless Transactions**: Send/receive sats via Lightning, ecash tokens, and Nostr zaps
- **QR Code Scanner**: Easy payment processing
- **Mint Management**: Add, remove, and monitor multiple Cashu mints

### ⚙️ Comprehensive Settings & Customization
- **Account Management**: Profile settings, key backup, biometric lock
- **Relay Control**: Granular management of Nostr relay connections
- **Notification Settings**: Customizable alerts with quiet hours
- **Theme Customization**: Light/dark modes, accent colors, alternate app icons

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/pablof7z/Olas.git
cd Olas
```

2. Install XcodeGen if you haven't already:
```bash
brew install xcodegen
```

3. Generate the Xcode project:
```bash
./refresh-project.sh
```

4. Open the project in Xcode:
```bash
open Olas.xcodeproj
```

5. Build and run the project on your device or simulator

### TestFlight

Coming soon! We'll be releasing Olas on TestFlight for beta testing.

## Development

### Building

```bash
# Refresh project after file changes
./refresh-project.sh

# Build with clean output
./build.sh

# Build for specific device
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro" ./build.sh
```

### Deploying to TestFlight

```bash
./deploy.sh
```

## Architecture

Olas is built using modern iOS development technologies:

- **SwiftUI** for the user interface
- **NDKSwift** for Nostr protocol interactions
- **Core Image** for advanced photo editing
- **AVFoundation** for camera functionality
- **SwiftData** for local storage
- **Combine** for reactive programming

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [NDKSwift](https://github.com/pablof7z/NDKSwift)
- Uses the [Nostr Protocol](https://nostr.com)
- Integrates [Cashu](https://cashu.space) for ecash functionality

## Contact

- Nostr: `npub1l2vyh47mk2p0qlsku7hg0vn29faehy9hy34ygaclpn66ukqp3afqutajft`
- GitHub: [@pablof7z](https://github.com/pablof7z)

---

<div align="center">
  Made with ❤️ for the decentralized future
</div>