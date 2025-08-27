#!/usr/bin/env node

/**
 * Comprehensive Test Suite for Apple Sign In Firebase Functions
 * Run this from the command line to test all functions
 */

const https = require("https");
const { exec } = require("child_process");
const util = require("util");
const execPromise = util.promisify(exec);

// Configuration
const BASE_URL = "https://us-central1-shootsdb-11bb7.cloudfunctions.net";
const TEST_APPLE_USER_ID = `test.apple.user.${Date.now()}`;
const TEST_EMAIL = `test${Date.now()}@example.com`;

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

function makeRequest(endpoint, method = "GET", data = null) {
  return new Promise((resolve, reject) => {
    const url = `${BASE_URL}/${endpoint}`;
    const options = {
      method,
      headers: {
        "Content-Type": "application/json",
      },
      rejectUnauthorized: false,
    };

    const req = https.request(url, options, (res) => {
      let responseData = "";
      res.on("data", (chunk) => {
        responseData += chunk;
      });
      res.on("end", () => {
        try {
          const parsed = JSON.parse(responseData);
          resolve({status: res.statusCode, data: parsed});
        } catch (e) {
          resolve({status: res.statusCode, data: responseData});
        }
      });
    });

    req.on("error", reject);

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

class TestRunner {
  constructor() {
    this.testResults = [];
    this.userId = null;
  }

  async runTest(testName, testFn) {
    log(`\n📝 ${testName}`, colors.cyan);
    try {
      const result = await testFn();
      this.testResults.push({name: testName, status: 'PASSED', result});
      log(`   ✅ PASSED`, colors.green);
      return result;
    } catch (error) {
      this.testResults.push({name: testName, status: 'FAILED', error: error.message});
      log(`   ❌ FAILED: ${error.message}`, colors.red);
      throw error;
    }
  }

  async test1_CreateNewAppleUser() {
    const testData = {
      appleUserID: TEST_APPLE_USER_ID,
      email: TEST_EMAIL,
      displayName: "Test User",
      identityToken: "test.identity.token",
    };

    const result = await makeRequest("associateAppleUser", "POST", testData);
    
    if (result.status !== 200) {
      throw new Error(`Expected status 200, got ${result.status}: ${JSON.stringify(result.data)}`);
    }
    
    if (!result.data.userId) {
      throw new Error("No userId returned");
    }
    
    if (!result.data.isNewUser) {
      throw new Error("Expected isNewUser to be true for new user");
    }
    
    this.userId = result.data.userId;
    log(`   Created user: ${this.userId}`, colors.bright);
    return result.data;
  }

  async test2_AssociateExistingAppleUser() {
    const testData = {
      appleUserID: TEST_APPLE_USER_ID,
      email: TEST_EMAIL,
      displayName: "Test User",
      identityToken: "test.identity.token",
    };

    const result = await makeRequest("associateAppleUser", "POST", testData);
    
    if (result.status !== 200) {
      throw new Error(`Expected status 200, got ${result.status}`);
    }
    
    if (result.data.userId !== this.userId) {
      throw new Error(`Expected same userId ${this.userId}, got ${result.data.userId}`);
    }
    
    if (result.data.isNewUser) {
      throw new Error("Expected isNewUser to be false for existing user");
    }
    
    return result.data;
  }

  async test3_SyncUserPreferences() {
    const testData = {
      userId: this.userId,
      filterSettings: {
        future: true,
        marked: false,
        months: ["January", "February"],
        search: "test search",
        states: ["CA", "TX", "NY"],
        notable: true,
        shootTypes: ["Sporting", "Trap"],
        maxDistance: 500,
      },
      markedShoots: [100, 200, 300, 400, 500],
    };

    const result = await makeRequest("syncUserPreferences", "POST", testData);
    
    if (result.status !== 200) {
      throw new Error(`Expected status 200, got ${result.status}: ${JSON.stringify(result.data)}`);
    }
    
    if (!result.data.success) {
      throw new Error("Expected success: true");
    }
    
    return result.data;
  }

  async test4_FetchUserPreferences() {
    const result = await makeRequest(`fetchUserPreferences?userId=${this.userId}`, "GET");
    
    if (result.status !== 200) {
      throw new Error(`Expected status 200, got ${result.status}: ${JSON.stringify(result.data)}`);
    }
    
    if (result.data.userId !== this.userId) {
      throw new Error(`Expected userId ${this.userId}, got ${result.data.userId}`);
    }
    
    // Verify filter settings
    const fs = result.data.filterSettings;
    if (!fs.states || fs.states.length !== 3) {
      throw new Error("Expected 3 states in filter settings");
    }
    
    if (!fs.shootTypes || fs.shootTypes.length !== 2) {
      throw new Error("Expected 2 shoot types in filter settings");
    }
    
    // Verify marked shoots
    if (!result.data.markedShoots || result.data.markedShoots.length !== 5) {
      throw new Error("Expected 5 marked shoots");
    }
    
    log(`   Filter Settings: ${JSON.stringify(fs.states)}`, colors.bright);
    log(`   Marked Shoots: ${JSON.stringify(result.data.markedShoots)}`, colors.bright);
    return result.data;
  }

  async test5_UpdateUserPreferences() {
    const testData = {
      userId: this.userId,
      filterSettings: {
        states: ["FL", "GA"],
        shootTypes: ["FITASC"],
        maxDistance: 1000,
      },
      markedShoots: [999],
    };

    const syncResult = await makeRequest("syncUserPreferences", "POST", testData);
    if (syncResult.status !== 200) {
      throw new Error(`Sync failed with status ${syncResult.status}`);
    }

    // Fetch and verify the update
    const fetchResult = await makeRequest(`fetchUserPreferences?userId=${this.userId}`, "GET");
    
    if (fetchResult.data.filterSettings.states.length !== 2) {
      throw new Error("Expected 2 states after update");
    }
    
    if (fetchResult.data.markedShoots.length !== 1 || fetchResult.data.markedShoots[0] !== 999) {
      throw new Error("Expected marked shoots to be [999]");
    }
    
    log(`   Updated States: ${JSON.stringify(fetchResult.data.filterSettings.states)}`, colors.bright);
    log(`   Updated Marked Shoots: ${JSON.stringify(fetchResult.data.markedShoots)}`, colors.bright);
    return fetchResult.data;
  }

  async test6_EmptyMarkedShoots() {
    const testData = {
      userId: this.userId,
      filterSettings: {
        states: ["AZ"],
      },
      markedShoots: [],
    };

    const syncResult = await makeRequest("syncUserPreferences", "POST", testData);
    if (syncResult.status !== 200) {
      throw new Error(`Sync failed with status ${syncResult.status}`);
    }

    const fetchResult = await makeRequest(`fetchUserPreferences?userId=${this.userId}`, "GET");
    
    if (fetchResult.data.markedShoots.length !== 0) {
      throw new Error("Expected empty marked shoots array");
    }
    
    log(`   Marked Shoots cleared successfully`, colors.bright);
    return fetchResult.data;
  }

  async test7_InvalidUserId() {
    const result = await makeRequest(`fetchUserPreferences?userId=invalid-uuid`, "GET");
    
    if (result.status !== 404) {
      throw new Error(`Expected status 404 for invalid user, got ${result.status}`);
    }
    
    return result.data;
  }

  async test8_MissingAppleUserId() {
    const testData = {
      email: "test@example.com",
      displayName: "Test User",
    };

    const result = await makeRequest("associateAppleUser", "POST", testData);
    
    if (result.status !== 400) {
      throw new Error(`Expected status 400 for missing appleUserID, got ${result.status}`);
    }
    
    return result.data;
  }

  async runAllTests() {
    log("\n🚀 Starting Comprehensive Firebase Functions Test Suite", colors.bright);
    log("=" .repeat(60), colors.yellow);

    const tests = [
      () => this.test1_CreateNewAppleUser(),
      () => this.test2_AssociateExistingAppleUser(),
      () => this.test3_SyncUserPreferences(),
      () => this.test4_FetchUserPreferences(),
      () => this.test5_UpdateUserPreferences(),
      () => this.test6_EmptyMarkedShoots(),
      () => this.test7_InvalidUserId(),
      () => this.test8_MissingAppleUserId(),
    ];

    for (let i = 0; i < tests.length; i++) {
      const testName = tests[i].toString().match(/test\d+_(\w+)/)[0].replace(/_/g, ' ');
      try {
        await this.runTest(testName, tests[i]);
      } catch (error) {
        // Continue with other tests even if one fails
      }
    }

    // Print summary
    log("\n" + "=" .repeat(60), colors.yellow);
    log("📊 Test Results Summary", colors.bright);
    log("=" .repeat(60), colors.yellow);
    
    const passed = this.testResults.filter(r => r.status === 'PASSED').length;
    const failed = this.testResults.filter(r => r.status === 'FAILED').length;
    
    this.testResults.forEach(result => {
      const icon = result.status === 'PASSED' ? '✅' : '❌';
      const color = result.status === 'PASSED' ? colors.green : colors.red;
      log(`${icon} ${result.name}`, color);
    });
    
    log("\n" + "=" .repeat(60), colors.yellow);
    log(`Total: ${this.testResults.length} | Passed: ${passed} | Failed: ${failed}`, colors.bright);
    
    if (failed === 0) {
      log("\n🎉 ALL TESTS PASSED! 🎉", colors.green);
    } else {
      log(`\n⚠️  ${failed} test(s) failed`, colors.red);
    }
    
    return failed === 0;
  }
}

async function runLintCheck() {
  log("\n🔍 Running ESLint check...", colors.cyan);
  try {
    const { stdout } = await execPromise("npm run lint");
    log("   ✅ Lint check passed", colors.green);
    return true;
  } catch (error) {
    log("   ❌ Lint check failed", colors.red);
    console.error(error.stdout);
    return false;
  }
}

async function main() {
  log("\n🏗️  Firebase Functions Test Suite", colors.bright);
  log("Testing environment: " + BASE_URL, colors.cyan);
  
  // Check if we're in the right directory
  const path = require("path");
  const currentDir = path.basename(process.cwd());
  
  if (currentDir !== 'functions') {
    log("\n⚠️  Please run this from the functions directory:", colors.yellow);
    log("cd Web/Login/ShootsLogin/functions", colors.cyan);
    log("node test/run-all-tests.js", colors.cyan);
    process.exit(1);
  }
  
  // Run lint check first
  const lintPassed = await runLintCheck();
  
  if (!lintPassed) {
    log("\n⚠️  Fix lint errors before running tests", colors.yellow);
    process.exit(1);
  }
  
  // Run all tests
  const runner = new TestRunner();
  const allPassed = await runner.runAllTests();
  
  process.exit(allPassed ? 0 : 1);
}

// Run if called directly
if (require.main === module) {
  main().catch(error => {
    log(`\n❌ Unexpected error: ${error.message}`, colors.red);
    process.exit(1);
  });
}

module.exports = { TestRunner, makeRequest };