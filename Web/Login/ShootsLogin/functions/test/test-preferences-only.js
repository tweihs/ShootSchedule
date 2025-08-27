// Test just preferences and marked shoots functions with the existing user
const https = require("https");

const BASE_URL = "https://us-central1-shootsdb-11bb7.cloudfunctions.net";
const EXISTING_USER_ID = "591a98d8-c040-4d3f-830a-f7970d0618cd"; // From successful Apple user creation

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

async function testPreferenceFunctions() {
  console.log("🧪 Testing Preference Functions with existing user");
  console.log(`Using userId: ${EXISTING_USER_ID}\n`);

  try {
    // Test 1: Sync some preferences
    console.log("Test 1: Syncing user preferences...");
    const syncPrefsData = {
      userId: EXISTING_USER_ID,
      filterSettings: {
        search: "test search",
        shootTypes: ["NSCA", "NSSA"],
        months: [1, 2, 3],
        states: ["CA", "TX"],
        notable: false,
        future: true,
        marked: false,
      },
      markedShoots: [1, 2, 3],
    };
    const syncResult = await makeRequest("syncUserPreferences", "POST", syncPrefsData);
    console.log(`Status: ${syncResult.status}`);
    console.log(`Response:`, syncResult.data);

    // Test 2: Fetch preferences
    console.log("\nTest 2: Fetching user preferences...");
    const prefsResult = await makeRequest(`fetchUserPreferences?userId=${EXISTING_USER_ID}`, "GET");
    console.log(`Status: ${prefsResult.status}`);
    console.log(`Response:`, JSON.stringify(prefsResult.data, null, 2));

    console.log("\n🎉 Preference function tests completed!");
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }
}

testPreferenceFunctions();