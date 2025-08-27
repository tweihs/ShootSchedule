// Simple test for Apple user functions only
const https = require("https");

const BASE_URL = "https://us-central1-shootsdb-11bb7.cloudfunctions.net";

const TYSON_TEST_DATA = {
  appleUserID: "test.apple.tyson.unique.id.12345",
  email: "tyson@weihs.com",
  displayName: "Tyson Weihs",
  identityToken: "test.apple.identity.token.for.tyson",
};

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

async function testAppleUserFunctions() {
  console.log("🧪 Testing Apple User Functions\n");

  try {
    // Test 1: Associate Tyson's Apple user
    console.log("Test 1: Associating Tyson's Apple user...");
    const tysonResult = await makeRequest("associateAppleUser", "POST", TYSON_TEST_DATA);
    console.log(`Status: ${tysonResult.status}`);
    console.log(`Response:`, tysonResult.data);

    if (tysonResult.status === 200) {
      const tysonUserId = tysonResult.data.userId;
      console.log("✅ Tyson association successful");

      // Test 2: Sync some preferences
      console.log("\nTest 2: Syncing user preferences...");
      const syncPrefsData = {
        userId: tysonUserId,
        filterSettings: {
          states: ["CA", "TX"],
          disciplines: ["Trap", "Skeet"],
          maxDistance: 100,
        },
        markedShoots: [10, 20, 30],
      };
      const syncResult = await makeRequest("syncUserPreferences", "POST", syncPrefsData);
      console.log(`Status: ${syncResult.status}`);
      console.log(`Response:`, syncResult.data);

      // Test 3: Fetch preferences
      console.log("\nTest 3: Fetching user preferences...");
      const prefsResult = await makeRequest(`fetchUserPreferences?userId=${tysonUserId}`, "GET");
      console.log(`Status: ${prefsResult.status}`);
      console.log(`Response:`, JSON.stringify(prefsResult.data, null, 2));
    } else {
      console.log("❌ Tyson association failed");
    }

    console.log("\n🎉 Apple user function tests completed!");
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }
}

testAppleUserFunctions();