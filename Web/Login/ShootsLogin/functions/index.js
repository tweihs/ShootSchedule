// functions/index.js
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
// const functions = require("firebase-functions");
const {Client} = require("pg");

admin.initializeApp();

// verifyToken: validate Firebase ID token and return user info
exports.verifyToken = onRequest(
    {region: "us-central1", runtime: "nodejs22"},
    async (req, res) => {
      const idToken = req.body.token;
      if (!idToken) {
        return res.status(400).json({error: "Missing token"});
      }

      try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const uid = decodedToken.uid;
        const userRecord = await admin.auth().getUser(uid);

        return res.json({
          uid: userRecord.uid,
          email: userRecord.email,
          displayName: userRecord.displayName,
          customClaims: userRecord.customClaims || {},
        });
      } catch (error) {
        console.error("Token verification failed:", error);
        return res.status(401).json({error: "Invalid token"});
      }
    },
);

// userCalendarIcs: return marked shoots as an iCal feed
// URL: /api/user/calendar?token=<calendar_token>
exports.userCalendarIcs = onRequest(
    {region: "us-central1", runtime: "nodejs22", secrets: ["DB_URL"]},
    async (req, res) => {
      const token = req.query.token;
      console.log("userCalendarIcs invoked, query params:", req.query);

      if (!token) {
        console.error("Missing token in query");
        return res.status(400).send("Missing token");
      }

      // Read database URL from Secret Manager
      const dbUrl = process.env.DB_URL;
      console.log("DB_URL is:", dbUrl);
      if (!dbUrl) {
        console.error("Missing DB_URL env var");
        return res.status(500).send("Database configuration error");
      }

      // Initialize Postgres client
      const client = new Client({
        connectionString: dbUrl,
        ssl: {rejectUnauthorized: false},
      });

      let userId;
      try {
        await client.connect();
        console.log(`Looking up user_id for calendar_token: ${token}`);

        // 1) Lookup user_id from stored calendar_token
        // Note: This might need adjustment based on actual calendar token storage schema
        const lookup = await client.query(
            `SELECT user_id FROM user_preferences WHERE user_id = $1`,
            [token],
        );
        if (lookup.rowCount === 0) {
          console.error(`No user found for token: ${token}`);
          return res.status(401).send("Invalid calendar token");
        }
        userId = lookup.rows[0].user_id;
        console.log(`Mapped token to userId: ${userId}`);

        // 2) Fetch the ICS feed for the user
        console.log(`Querying calendar for userId: ${userId}`);
        const sql = `SELECT ics_calendar FROM marked_shoots_ics WHERE user_id = $1`;
        const result = await client.query(sql, [userId]);
        console.log(`ICS query returned ${result.rowCount} rows`);

        if (result.rowCount === 0) {
          console.warn(`No calendar found for userId: ${userId}`);
          return res.status(404).send("No calendar found for that user");
        }

        res.set("Content-Type", "text/calendar; charset=utf-8");
        res.set("X-PUBLISHED-TTL", "PT5M");
        res.set("Content-Disposition", "inline; filename=\"shoot-schedule.ics\"");
        res.set("Cache-Control", "public, max-age=300");

        console.log(
            `Returning calendar payload length ${
              result.rows[0].ics_calendar.length
            }`,
        );
        return res.status(200).send(result.rows[0].ics_calendar);
      } catch (err) {
        console.error("Error generating calendar:", err);
        return res.status(500).send("Error generating calendar");
      } finally {
        try {
          await client.end();
        } catch (cleanupErr) {
          console.warn("Error closing DB client:", cleanupErr);
        }
      }
    },
);

// associateAppleUser: Link Apple Sign In user to existing or new user
exports.associateAppleUser = onRequest(
    {region: "us-central1", runtime: "nodejs22", secrets: ["DB_URL"]},
    async (req, res) => {
      const {appleUserID, email, displayName, identityToken} = req.body;

      if (!appleUserID) {
        return res.status(400).json({error: "Missing appleUserID"});
      }

      const dbUrl = process.env.DB_URL;
      if (!dbUrl) {
        console.error("Missing DB_URL env var");
        return res.status(500).json({error: "Database configuration error"});
      }

      const client = new Client({
        connectionString: dbUrl,
        ssl: {rejectUnauthorized: false},
      });

      try {
        await client.connect();

        // Check if Apple user already exists and fetch all data with JOINs
        const existingUserQuery = `
          SELECT 
            au.user_id,
            au.email,
            au.display_name,
            u.created_at,
            up.preferences,
            up.marked_shoots
          FROM apple_users au
          INNER JOIN users u ON au.user_id = u.id
          LEFT OUTER JOIN user_preferences up ON u.id = up.user_id
          WHERE au.apple_user_id = $1
        `;

        const existingUserResult = await client.query(existingUserQuery, [appleUserID]);

        if (existingUserResult.rowCount > 0) {
          // Apple user already exists, return all user data
          const userData = existingUserResult.rows[0];
          const userId = userData.user_id;

          console.log(`Existing Apple user found: ${appleUserID} -> ${userId}`);

          // Update identity token if provided
          if (identityToken) {
            await client.query(
                `UPDATE apple_users SET identity_token = $1 WHERE apple_user_id = $2`,
                [identityToken, appleUserID],
            );
          }

          // Prepare response with user data and preferences
          const response = {
            userId,
            isNewUser: false,
            email: userData.email,
            displayName: userData.display_name,
            createdAt: userData.created_at,
          };

          // Include preferences if they exist
          if (userData.preferences !== null || userData.marked_shoots !== null) {
            response.preferences = {
              filterSettings: userData.preferences || {
                future: true,
                marked: false,
                months: [],
                search: "",
                states: [],
                notable: false,
                shootTypes: [],
              },
              markedShoots: userData.marked_shoots || [],
            };
          }

          return res.json(response);
        }

        // New user - create user record first
        const newUser = await client.query(
            `INSERT INTO users (id, created_at) 
             VALUES (gen_random_uuid(), NOW()) 
             RETURNING id, created_at`,
        );
        const userId = newUser.rows[0].id;
        const createdAt = newUser.rows[0].created_at;
        console.log(`Created new user: ${userId}`);

        // Create Apple user association
        await client.query(
            `INSERT INTO apple_users (apple_user_id, user_id, email, identity_token, display_name) 
             VALUES ($1, $2, $3, $4, $5)`,
            [appleUserID, userId, email, identityToken, displayName],
        );

        console.log(`Associated Apple user ${appleUserID} with user ${userId}`);

        // Return new user data (no preferences yet)
        return res.json({
          userId,
          isNewUser: true,
          email,
          displayName,
          createdAt,
          preferences: null, // New users have no preferences yet
        });
      } catch (error) {
        console.error("Error associating Apple user:", error);
        return res.status(500).json({error: "Failed to associate Apple user"});
      } finally {
        await client.end();
      }
    },
);

// fetchUserPreferences: Get user preferences by user ID
exports.fetchUserPreferences = onRequest(
    {region: "us-central1", runtime: "nodejs22", secrets: ["DB_URL"]},
    async (req, res) => {
      const {userId} = req.query;

      if (!userId) {
        return res.status(400).json({error: "Missing userId"});
      }

      const dbUrl = process.env.DB_URL;
      if (!dbUrl) {
        console.error("Missing DB_URL env var");
        return res.status(500).json({error: "Database configuration error"});
      }

      const client = new Client({
        connectionString: dbUrl,
        ssl: {rejectUnauthorized: false},
      });

      try {
        await client.connect();

        // Fetch user preferences from the preferences column (JSON)
        const prefsResult = await client.query(
            `SELECT preferences, marked_shoots FROM user_preferences WHERE user_id = $1`,
            [userId],
        );

        if (prefsResult.rowCount === 0) {
          return res.status(404).json({error: "User preferences not found"});
        }

        const prefs = prefsResult.rows[0];

        const preferences = {
          userId,
          filterSettings: prefs.preferences || {
            future: true,
            marked: false,
            months: [],
            search: "",
            states: [],
            notable: false,
            shootTypes: [],
          },
          markedShoots: prefs.marked_shoots || [],
        };

        console.log(`Retrieved preferences for user ${userId}`);
        return res.json(preferences);
      } catch (error) {
        console.error("Error fetching user preferences:", error);
        return res.status(500).json({error: "Failed to fetch user preferences"});
      } finally {
        await client.end();
      }
    },
);

// syncUserPreferences: Save user preferences to PostgreSQL
exports.syncUserPreferences = onRequest(
    {region: "us-central1", runtime: "nodejs22", secrets: ["DB_URL"]},
    async (req, res) => {
      // Log the entire request body
      console.log("📥 Received sync request:");
      console.log("=====================================");
      console.log(JSON.stringify(req.body, null, 2));
      console.log("=====================================");

      const {userId, filterSettings, markedShoots} = req.body;

      if (!userId) {
        console.error("Missing userId in request body");
        return res.status(400).json({error: "Missing userId"});
      }

      const dbUrl = process.env.DB_URL;
      if (!dbUrl) {
        console.error("Missing DB_URL env var");
        return res.status(500).json({error: "Database configuration error"});
      }

      const client = new Client({
        connectionString: dbUrl,
        ssl: {rejectUnauthorized: false},
      });

      try {
        await client.connect();

        // Log what we're about to save
        console.log(`📤 Saving to database for user ${userId}:`);
        console.log(`   Filter settings: ${JSON.stringify(filterSettings)}`);
        console.log(`   Marked shoots: ${JSON.stringify(markedShoots)}`);

        // Upsert user preferences (JSON in preferences column and marked_shoots)
        await client.query(
            `INSERT INTO user_preferences 
             (user_id, preferences, marked_shoots, updated_at) 
             VALUES ($1, $2, $3, NOW())
             ON CONFLICT (user_id) 
             DO UPDATE SET 
               preferences = $2,
               marked_shoots = $3,
               updated_at = NOW()`,
            [userId, JSON.stringify(filterSettings || {}), markedShoots || []],
        );

        console.log(`✅ Successfully synced preferences for user ${userId}`);
        return res.json({success: true});
      } catch (error) {
        console.error("❌ Error syncing user preferences:", error);
        return res.status(500).json({error: "Failed to sync user preferences"});
      } finally {
        await client.end();
      }
    },
);


