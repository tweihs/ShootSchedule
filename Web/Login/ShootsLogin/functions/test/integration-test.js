// test/integration-test.js
// Manual integration tests for Apple user functions
// Run this after deploying to Firebase to test the actual endpoints

const https = require("https");
const querystring = require("querystring");

// Your Firebase project URL - update this after deployment
const BASE_URL = "https://us-central1-shootsdb-11bb7.cloudfunctions.net";

// Test data for Tyson's scenario
const TYSON_TEST_DATA = {
  appleUserID: "test.apple.tyson.unique.id.12345",
  email: "tyson@weihs.com",
  displayName: "Tyson Weihs",
  identityToken: "test.apple.identity.token.for.tyson",
};

const NEW_USER_TEST_DATA = {
  appleUserID: "test.apple.newuser.unique.id.67890",
  email: "newuser@example.com",
  displayName: "New Test User",
  identityToken: "test.apple.identity.token.for.newuser",
};

function makeRequest(endpoint, method = "GET", data = null) {
  return new Promise((resolve, reject) => {
    const url = `${BASE_URL}/${endpoint}`;
    const options = {
      method,
      headers: {
        "Content-Type": "application/json",
      },
      rejectUnauthorized: false, // For testing
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

async function runTests() {
  console.log("🧪 Running Apple User Functions Integration Tests\n");

  try {
    // Test 1: Associate Tyson's Apple user (should link to existing Firebase user)
    console.log("Test 1: Associating Tyson's Apple user...");
    const tysonResult = await makeRequest("associateAppleUser", "POST", TYSON_TEST_DATA);
    console.log(`Status: ${tysonResult.status}`);
    console.log(`Response:`, tysonResult.data);

    if (tysonResult.status === 200) {
      const tysonUserId = tysonResult.data.userId;
      console.log("✅ Tyson association successful");

      // Test 2: Try to associate the same Apple user again (should return existing)
      console.log("\nTest 2: Re-associating same Apple user...");
      const duplicateResult = await makeRequest("associateAppleUser", "POST", TYSON_TEST_DATA);
      console.log(`Status: ${duplicateResult.status}`);
      console.log(`Response:`, duplicateResult.data);

      if (duplicateResult.data.userId === tysonUserId) {
        console.log("✅ Duplicate association handled correctly");
      } else {
        console.log("❌ Duplicate association created different user");
      }

      // Test 3: Fetch user preferences (might not exist yet)
      console.log("\nTest 3: Fetching user preferences...");
      const prefsResult = await makeRequest(`fetchUserPreferences?userId=${tysonUserId}`, "GET");
      console.log(`Status: ${prefsResult.status}`);
      console.log(`Response:`, prefsResult.data);

      // Test 4: Sync some preferences
      console.log("\nTest 4: Syncing user preferences...");
      const syncPrefsData = {
        userId: tysonUserId,
        filterSettings: {
          states: ["CA", "TX", "FL"],
          disciplines: ["Trap", "Skeet"],
          maxDistance: 100,
        },
      };
      const syncResult = await makeRequest("syncUserPreferences", "POST", syncPrefsData);
      console.log(`Status: ${syncResult.status}`);
      console.log(`Response:`, syncResult.data);

      // Test 5: Sync marked shoots
      console.log("\nTest 5: Syncing marked shoots...");
      const syncShootsData = {
        userId: tysonUserId,
        markedShootIds: [1, 2, 3, 4, 5],
      };
      const syncShootsResult = await makeRequest("syncMarkedShoots", "POST", syncShootsData);
      console.log(`Status: ${syncShootsResult.status}`);
      console.log(`Response:`, syncShootsResult.data);

      // Test 6: Fetch preferences again (should have data now)
      console.log("\nTest 6: Fetching updated preferences...");
      const updatedPrefsResult = await makeRequest(`fetchUserPreferences?userId=${tysonUserId}`, "GET");
      console.log(`Status: ${updatedPrefsResult.status}`);
      console.log(`Response:`, JSON.stringify(updatedPrefsResult.data, null, 2));
    } else {
      console.log("❌ Tyson association failed");
    }

    // Test 7: Create completely new user
    console.log("\nTest 7: Creating new user...");
    const newUserResult = await makeRequest("associateAppleUser", "POST", NEW_USER_TEST_DATA);
    console.log(`Status: ${newUserResult.status}`);
    console.log(`Response:`, newUserResult.data);

    console.log("\n🎉 Integration tests completed!");
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }
}

// Test error cases
async function runErrorTests() {
  console.log("\n🚨 Running Error Case Tests\n");

  try {
    // Test missing appleUserID
    console.log("Test: Missing appleUserID...");
    const missingIdResult = await makeRequest("associateAppleUser", "POST", {
      email: "test@example.com",
      displayName: "Test User",
    });
    console.log(`Status: ${missingIdResult.status}`);
    console.log(`Response:`, missingIdResult.data);

    // Test invalid userId for preferences
    console.log("\nTest: Invalid userId for preferences...");
    const invalidUserResult = await makeRequest("fetchUserPreferences?userId=nonexistent-user", "GET");
    console.log(`Status: ${invalidUserResult.status}`);
    console.log(`Response:`, invalidUserResult.data);

    // Test invalid marked shoots data
    console.log("\nTest: Invalid marked shoots data...");
    const invalidShootsResult = await makeRequest("syncMarkedShoots", "POST", {
      userId: "test-user",
      markedShootIds: "not-an-array",
    });
    console.log(`Status: ${invalidShootsResult.status}`);
    console.log(`Response:`, invalidShootsResult.data);
  } catch (error) {
    console.error("❌ Error test failed:", error.message);
  }
}

// Usage instructions
if (require.main === module) {
  console.log("📋 Apple User Functions Integration Test");
  console.log("=====================================");
  console.log("");
  console.log("Before running these tests:");
  console.log("1. Deploy the functions: npm run deploy");
  console.log("2. Update BASE_URL in this file with your project URL");
  console.log("3. Run: node test/integration-test.js");
  console.log("");
  console.log("Starting tests in 3 seconds...");

  setTimeout(async () => {
    await runTests();
    await runErrorTests();
  }, 3000);
}

module.exports = {runTests, runErrorTests};
