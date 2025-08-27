// Test syncing preferences with the correct database user ID
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

async function testSyncWithCorrectId() {
  console.log("🧪 Testing Preference Sync with Correct Database User ID");
  console.log("========================================================\n");

  // Use the actual user ID from the database for your Apple Sign In
  const correctUserId = "4d3b82cb-5cf7-49e6-b240-0316be1ddf7c";
  
  console.log(`Using correct database user ID: ${correctUserId}\n`);

  try {
    // Test: Sync preferences with correct user ID
    console.log("Test: Syncing user preferences with correct ID...");
    const syncData = {
      userId: correctUserId,
      filterSettings: {
        search: "",
        shootTypes: ["NSCA", "NSSA", "ATA"],
        months: [1, 2, 3, 4, 5, 6],
        states: ["CA", "NV", "AZ"],
        notable: true,
        future: true,
        marked: false,
      },
      markedShoots: [123, 456, 789],
    };
    
    const syncResult = await makeRequest("syncUserPreferences", "POST", syncData);
    console.log(`Status: ${syncResult.status}`);
    console.log(`Response:`, syncResult.data);

    if (syncResult.status === 200) {
      console.log("\n✅ Preference sync successful!");
      
      // Verify preferences were saved
      console.log("\nVerifying preferences were saved...");
      const verifyResult = await makeRequest(`fetchUserPreferences?userId=${correctUserId}`, "GET");
      console.log(`Status: ${verifyResult.status}`);
      console.log(`Response:`, JSON.stringify(verifyResult.data, null, 2));
    } else {
      console.log("\n❌ Preference sync failed");
    }
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }
}

testSyncWithCorrectId();