// Monitor user preferences changes in real-time
const https = require("https");

const BASE_URL = "https://us-central1-shootsdb-11bb7.cloudfunctions.net";

function fetchPreferences(userId) {
  return new Promise((resolve, reject) => {
    const url = `${BASE_URL}/fetchUserPreferences?userId=${userId}`;
    https.get(url, { rejectUnauthorized: false }, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve(null);
        }
      });
    }).on("error", reject);
  });
}

async function monitorPreferences() {
  // Use your actual user ID from the database
  // This is the ID that was created when you signed in with Apple ID: 001867.8e1a98e674324834852e0eb97a4c387a.1523
  const userId = "cd936d42-3253-49ab-810b-d88ca55a82ec";
  
  console.log("🔍 Monitoring preferences for user:", userId);
  console.log("📱 Now make changes in the iOS app (filters, marked shoots, etc.)\n");
  
  let lastPreferences = null;
  
  setInterval(async () => {
    try {
      const prefs = await fetchPreferences(userId);
      
      if (!prefs || prefs.error) {
        if (!lastPreferences) {
          console.log("⏳ Waiting for initial preferences...");
        }
        return;
      }
      
      const prefsString = JSON.stringify(prefs);
      const lastString = lastPreferences ? JSON.stringify(lastPreferences) : null;
      
      if (prefsString !== lastString) {
        const timestamp = new Date().toLocaleTimeString();
        console.log(`\n✅ [${timestamp}] Preferences updated!`);
        console.log("────────────────────────────────────");
        
        if (prefs.filterSettings) {
          console.log("📋 Filter Settings:");
          console.log(`   Search: "${prefs.filterSettings.search || ''}"`);
          console.log(`   Types: ${prefs.filterSettings.shootTypes?.join(", ") || "none"}`);
          console.log(`   Months: ${prefs.filterSettings.months?.join(", ") || "none"}`);
          console.log(`   States: ${prefs.filterSettings.states?.join(", ") || "none"}`);
          console.log(`   Future only: ${prefs.filterSettings.future}`);
          console.log(`   Notable only: ${prefs.filterSettings.notable}`);
          console.log(`   Marked only: ${prefs.filterSettings.marked}`);
        }
        
        if (prefs.markedShoots) {
          console.log(`\n🎯 Marked Shoots: ${prefs.markedShoots.length > 0 ? prefs.markedShoots.join(", ") : "none"}`);
        }
        
        if (prefs.temperatureUnit) {
          console.log(`\n🌡️  Temperature: ${prefs.temperatureUnit}`);
        }
        
        if (prefs.calendarSyncEnabled !== undefined) {
          console.log(`📅 Calendar sync: ${prefs.calendarSyncEnabled ? "enabled" : "disabled"}`);
        }
        
        console.log("────────────────────────────────────");
        lastPreferences = prefs;
      }
    } catch (error) {
      console.error("❌ Error fetching preferences:", error.message);
    }
  }, 2000); // Check every 2 seconds
}

monitorPreferences();