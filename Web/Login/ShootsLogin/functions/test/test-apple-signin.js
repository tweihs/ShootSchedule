// Test Apple Sign In flow with real Apple User ID format
const https = require("https");

const BASE_URL = "https://us-central1-shootsdb-11bb7.cloudfunctions.net";

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

async function testAppleSignIn() {
  console.log("🧪 Testing Apple Sign In Flow");
  console.log("================================\n");

  // Simulate a real Apple Sign In
  const testAppleUser = {
    appleUserID: "001234.5678abcd9012efgh3456ijkl7890mnop.1234", // Realistic Apple ID format
    email: "tyson@weihs.com",
    displayName: "Tyson Weihs",
    identityToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.token" // Mock JWT token
  };

  try {
    console.log("📱 Simulating Apple Sign In with:");
    console.log(`   Apple ID: ${testAppleUser.appleUserID}`);
    console.log(`   Email: ${testAppleUser.email}`);
    console.log(`   Name: ${testAppleUser.displayName}\n`);

    // Test 1: Associate Apple user
    console.log("Test 1: Associating Apple user...");
    const associateResult = await makeRequest("associateAppleUser", "POST", testAppleUser);
    console.log(`Status: ${associateResult.status}`);
    console.log(`Response:`, associateResult.data);

    if (associateResult.data && associateResult.data.userId) {
      const userId = associateResult.data.userId;
      console.log(`\n✅ User ID received: ${userId}`);
      console.log(`   New user: ${associateResult.data.isNewUser}\n`);

      // Test 2: Fetch user preferences
      console.log("Test 2: Fetching user preferences...");
      const prefsResult = await makeRequest(`fetchUserPreferences?userId=${userId}`, "GET");
      console.log(`Status: ${prefsResult.status}`);
      if (prefsResult.status === 404) {
        console.log("No preferences found (expected for new user)");
      } else {
        console.log(`Response:`, JSON.stringify(prefsResult.data, null, 2));
      }

      // Test 3: Sync preferences
      console.log("\nTest 3: Syncing user preferences...");
      const syncData = {
        userId: userId,
        filterSettings: {
          search: "",
          shootTypes: ["NSCA", "NSSA"],
          months: [1, 2, 3],
          states: ["CA", "NV"],
          notable: false,
          future: true,
          marked: false,
        },
        markedShoots: [100, 200, 300],
      };
      const syncResult = await makeRequest("syncUserPreferences", "POST", syncData);
      console.log(`Status: ${syncResult.status}`);
      console.log(`Response:`, syncResult.data);

      // Test 4: Verify preferences were saved
      console.log("\nTest 4: Verifying preferences were saved...");
      const verifyResult = await makeRequest(`fetchUserPreferences?userId=${userId}`, "GET");
      console.log(`Status: ${verifyResult.status}`);
      console.log(`Response:`, JSON.stringify(verifyResult.data, null, 2));
    }

    console.log("\n🎉 Apple Sign In flow test completed!");
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }
}

testAppleSignIn();