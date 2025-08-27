// Test the optimized associateAppleUser endpoint that returns user data and preferences
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

async function testOptimizedAssociation() {
  console.log("🧪 Testing Optimized associateAppleUser Endpoint");
  console.log("================================================\n");

  // Test 1: New user (should return user data but no preferences)
  console.log("Test 1: New Apple user association");
  const newUserData = {
    appleUserID: `test_apple_${Date.now()}`,
    email: "test@example.com",
    displayName: "Test User",
    identityToken: "test_token_123",
  };
  
  try {
    const newUserResult = await makeRequest("associateAppleUser", "POST", newUserData);
    console.log(`Status: ${newUserResult.status}`);
    console.log("Response:", JSON.stringify(newUserResult.data, null, 2));
    
    if (newUserResult.status === 200) {
      console.log("\n✅ New user created successfully");
      console.log(`   User ID: ${newUserResult.data.userId}`);
      console.log(`   Is new user: ${newUserResult.data.isNewUser}`);
      console.log(`   Has preferences: ${newUserResult.data.preferences !== null}`);
      
      const userId = newUserResult.data.userId;
      
      // Test 2: Add preferences for the new user
      console.log("\n\nTest 2: Adding preferences for the new user");
      const prefsData = {
        userId: userId,
        filterSettings: {
          search: "",
          shootTypes: ["NSCA", "NSSA"],
          months: [3, 4, 5],
          states: ["CA", "NV"],
          notable: true,
          future: true,
          marked: false,
        },
        markedShoots: [101, 202, 303],
      };
      
      const prefsResult = await makeRequest("syncUserPreferences", "POST", prefsData);
      console.log(`Status: ${prefsResult.status}`);
      console.log("Response:", prefsResult.data);
      
      if (prefsResult.status === 200) {
        console.log("✅ Preferences added successfully");
        
        // Test 3: Re-authenticate (existing user with preferences)
        console.log("\n\nTest 3: Re-authenticating existing user (should return preferences)");
        const existingUserResult = await makeRequest("associateAppleUser", "POST", newUserData);
        console.log(`Status: ${existingUserResult.status}`);
        console.log("Response:", JSON.stringify(existingUserResult.data, null, 2));
        
        if (existingUserResult.status === 200) {
          console.log("\n✅ Existing user authenticated successfully");
          console.log(`   User ID: ${existingUserResult.data.userId}`);
          console.log(`   Is new user: ${existingUserResult.data.isNewUser}`);
          console.log(`   Has preferences: ${existingUserResult.data.preferences !== null}`);
          
          if (existingUserResult.data.preferences) {
            console.log("\n📋 User preferences retrieved in single query:");
            console.log(`   Shoot types: ${existingUserResult.data.preferences.filterSettings.shootTypes}`);
            console.log(`   Marked shoots: ${existingUserResult.data.preferences.markedShoots}`);
            console.log(`   States: ${existingUserResult.data.preferences.filterSettings.states}`);
          }
        }
      }
    }
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }
  
  // Test 4: Test with the actual user that's been having issues
  console.log("\n\nTest 4: Testing with existing production user");
  const prodUserData = {
    appleUserID: "001867.8e1a98e674324834852e0eb97a4c387a.1523", // Your actual Apple ID
    email: "tyson@takingage.net",
    displayName: "Tyson Weihs",
    identityToken: "test_token_prod",
  };
  
  try {
    const prodResult = await makeRequest("associateAppleUser", "POST", prodUserData);
    console.log(`Status: ${prodResult.status}`);
    console.log("Response:", JSON.stringify(prodResult.data, null, 2));
    
    if (prodResult.status === 200 && prodResult.data.preferences) {
      console.log("\n✅ Production user data and preferences retrieved successfully!");
      console.log("   This confirms the optimized endpoint is working correctly.");
    }
  } catch (error) {
    console.error("❌ Production user test failed:", error.message);
  }
}

testOptimizedAssociation();