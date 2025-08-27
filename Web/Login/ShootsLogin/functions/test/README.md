# Firebase Functions Test Suite

This directory contains comprehensive tests for the Apple Sign In and User Preferences Firebase Functions.

## Quick Start

### Run All Tests
```bash
cd Web/Login/ShootsLogin/functions
node test/run-all-tests.js
```

This will:
1. Run ESLint to check code quality
2. Execute 8 comprehensive tests covering all functions
3. Display colored results in the terminal

## Available Test Files

### 1. `run-all-tests.js` - Comprehensive Test Suite ✅
The main test runner that validates all functions:
- **test1**: Create new Apple user
- **test2**: Associate existing Apple user  
- **test3**: Sync user preferences
- **test4**: Fetch user preferences
- **test5**: Update user preferences
- **test6**: Clear marked shoots
- **test7**: Handle invalid user ID
- **test8**: Validate missing Apple user ID

**Run it:**
```bash
node test/run-all-tests.js
```

### 2. `simple-apple-test.js` - Basic Apple User Flow
Tests the basic Apple Sign In flow with a predefined user (Tyson):
```bash
node test/simple-apple-test.js
```

### 3. `test-preferences-only.js` - Preferences Testing
Tests preference sync/fetch with an existing user:
```bash
node test/test-preferences-only.js
```

### 4. `integration-test.js` - Manual Integration Tests
More extensive integration testing with multiple scenarios:
```bash
node test/integration-test.js
```

## Unit Tests (Mocha)

The `apple-user-functions.test.js` file contains unit tests using Mocha, Chai, and Sinon.
These mock the database connections for isolated testing.

**Run unit tests:**
```bash
npm test
```

Note: Unit tests may fail for `onRequest` functions (designed for `onCall`).

## Function URLs

The deployed functions are available at:
- `associateAppleUser`: https://associateappleuser-cbmxtgsqra-uc.a.run.app
- `fetchUserPreferences`: https://fetchuserpreferences-cbmxtgsqra-uc.a.run.app
- `syncUserPreferences`: https://syncuserpreferences-cbmxtgsqra-uc.a.run.app
- `verifyToken`: https://verifytoken-cbmxtgsqra-uc.a.run.app
- `userCalendarIcs`: https://usercalendarics-cbmxtgsqra-uc.a.run.app

## Database Schema

The functions work with these PostgreSQL tables:
- `users` (id: UUID, created_at: timestamp)
- `apple_users` (apple_user_id: string, user_id: UUID, email: string, identity_token: text, display_name: string)
- `user_preferences` (user_id: UUID, preferences: JSON, marked_shoots: array, updated_at: timestamp)

## iOS App Integration

The iOS app has the infrastructure ready but currently has the UserPreferencesService calls commented out:
- `DataManager.swift` line 1689: `// private let userPreferencesService = UserPreferencesService()`
- `AuthenticationManager.swift` line 215: `// let preferencesService = UserPreferencesService()`

To enable full integration, uncomment these lines and ensure the service is properly initialized.

## Expected Test Results

When running `run-all-tests.js`, you should see:
- ✅ 7-8 tests passing (green)
- ❌ 0-1 tests failing (red) - test7 may fail if invalid UUID handling returns 500 instead of 404

A successful run looks like:
```
🎉 ALL TESTS PASSED! 🎉
Total: 8 | Passed: 8 | Failed: 0
```

## Troubleshooting

1. **Lint errors**: Fix any ESLint issues before tests run
   ```bash
   npm run lint
   ```

2. **Connection issues**: Ensure you have internet access to reach Firebase Functions

3. **Wrong directory**: Always run from the `functions` directory

4. **Database errors**: Check that PostgreSQL schema matches expected structure

## Development

To add new tests, create functions following the pattern in `run-all-tests.js`:
```javascript
async test9_YourNewTest() {
  // Your test logic
  if (condition) {
    throw new Error("Test failed");
  }
  return result;
}
```

Then add it to the tests array in `runAllTests()`.