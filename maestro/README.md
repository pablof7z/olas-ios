# Olas Maestro Tests

This directory contains Maestro UI tests for the Olas iOS app.

## Prerequisites

1. Install Maestro CLI:
```bash
curl -Ls "https://get.maestro.mobile.dev" | bash
```

2. Make sure you have the iOS Simulator installed via Xcode.

## Running Tests

### Run all tests:
```bash
maestro test maestro/
```

### Run a specific test:
```bash
maestro test maestro/create_account_test.yaml
```

### Run tests with specific device:
```bash
maestro test --device "iPhone 15 Pro" maestro/
```

## Test Files

- `create_account_test.yaml` - Tests the new account creation flow through onboarding
- `login_with_nsec_test.yaml` - Tests login with nsec private key format
- `login_with_hex_test.yaml` - Tests login with hex private key format
- `config.yaml` - Maestro configuration file

## Important Notes

1. **Private Keys**: The private keys used in the login tests are TEST KEYS ONLY. Never use real private keys in test files.

2. **Test Data**: Account creation uses dynamic timestamps to ensure unique usernames.

3. **Timeouts**: Some operations (like account creation) may take time due to network requests. Timeouts are configured accordingly.

## Writing New Tests

When adding new tests:

1. Use accessibility identifiers in the SwiftUI code for reliable element selection
2. Add appropriate waits for animations and network operations
3. Keep tests focused on a single user flow
4. Document any test data requirements

## Troubleshooting

- If tests fail on element not found, check that accessibility identifiers are properly set in the code
- For timing issues, increase timeout values or add `waitForAnimationToEnd` commands
- Use `maestro studio` to interactively explore the app and find elements