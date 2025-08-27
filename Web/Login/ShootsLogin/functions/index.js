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

          // Update identity token and email if provided (email might not have been available on first sign in)
          if (identityToken || email) {
            const updateFields = [];
            const updateValues = [];
            let paramCount = 1;

            if (identityToken) {
              updateFields.push(`identity_token = $${paramCount++}`);
              updateValues.push(identityToken);
            }

            if (email && !userData.email) {
              // Only update email if we didn't have one before
              updateFields.push(`email = $${paramCount++}`);
              updateValues.push(email);
              console.log(`Updating missing email for Apple user: ${email}`);
            }

            if (updateFields.length > 0) {
              updateValues.push(appleUserID);
              await client.query(
                  `UPDATE apple_users SET ${updateFields.join(", ")} WHERE apple_user_id = $${paramCount}`,
                  updateValues,
              );
            }
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

        // Check if this email already exists in firebase_users (account linking)
        let userId;
        let createdAt;
        let existingPreferences = null;
        let linkedAccount = false;

        if (email && !email.includes("@privaterelay.appleid.com")) {
          // Only try to link if we have a real email (not Apple's private relay)
          console.log(`Checking if email ${email} exists in firebase_users for account linking`);

          const firebaseUserQuery = `
            SELECT 
              fu.user_id,
              fu.user_json->>'displayName' as firebase_display_name,
              fu.user_json->>'email' as firebase_email,
              u.created_at,
              up.preferences,
              up.marked_shoots
            FROM firebase_users fu
            INNER JOIN users u ON fu.user_id = u.id
            LEFT OUTER JOIN user_preferences up ON u.id = up.user_id
            WHERE fu.user_json->>'email' = $1
          `;

          const firebaseUserResult = await client.query(firebaseUserQuery, [email]);
          console.log(`Firebase user query returned ${firebaseUserResult.rowCount} rows for email: ${email}`);

          if (firebaseUserResult.rowCount > 0) {
            // Found existing user with same email in firebase_users - link accounts!
            const existingData = firebaseUserResult.rows[0];
            userId = existingData.user_id;
            createdAt = existingData.created_at;
            linkedAccount = true;
            console.log(`Found existing Firebase user with email ${email}, user_id: ${userId}`);

            // Prepare existing preferences if they exist
            if (existingData.preferences !== null || existingData.marked_shoots !== null) {
              existingPreferences = {
                filterSettings: existingData.preferences || {
                  future: true,
                  marked: false,
                  months: [],
                  search: "",
                  states: [],
                  notable: false,
                  shootTypes: [],
                },
                markedShoots: existingData.marked_shoots || [],
              };
            }

            console.log(`🔗 Linking Apple account to existing user ${userId} (previously signed in with Google)`);
          }
        }

        // If no existing user found, create new one
        if (!userId) {
          const newUser = await client.query(
              `INSERT INTO users (id, created_at) 
               VALUES (gen_random_uuid(), NOW()) 
               RETURNING id, created_at`,
          );
          userId = newUser.rows[0].id;
          createdAt = newUser.rows[0].created_at;
          console.log(`Created new user: ${userId}`);
        }

        // Create Apple user association
        await client.query(
            `INSERT INTO apple_users (apple_user_id, user_id, email, identity_token, display_name) 
             VALUES ($1, $2, $3, $4, $5)`,
            [appleUserID, userId, email, identityToken, displayName],
        );

        console.log(`Associated Apple user ${appleUserID} with user ${userId}`);

        // Return user data with preferences if it's a linked account
        const response = {
          userId,
          isNewUser: !linkedAccount,
          email,
          displayName,
          createdAt,
          preferences: existingPreferences,
        };

        if (linkedAccount) {
          response.linkedAccount = true;
          response.message = "Account successfully linked with existing Google account";
        }

        return res.json(response);
      } catch (error) {
        console.error("Error associating Apple user:", error);
        return res.status(500).json({error: "Failed to associate Apple user"});
      } finally {
        await client.end();
      }
    },
);

// associateFirebaseUser: Link Firebase/Google Sign In user to existing or new user
exports.associateFirebaseUser = onRequest(
    {region: "us-central1", runtime: "nodejs22", secrets: ["DB_URL"]},
    async (req, res) => {
      const {uid, email, displayName} = req.body;

      if (!uid || !email) {
        return res.status(400).json({error: "Missing uid or email"});
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

        // Check if Firebase user already exists
        const existingUserQuery = `
          SELECT 
            fu.user_id,
            fu.user_json,
            fu.firebase_uid,
            u.created_at,
            up.preferences,
            up.marked_shoots
          FROM firebase_users fu
          INNER JOIN users u ON fu.user_id = u.id
          LEFT OUTER JOIN user_preferences up ON u.id = up.user_id
          WHERE fu.firebase_uid = $1
        `;

        const existingUserResult = await client.query(existingUserQuery, [uid]);

        if (existingUserResult.rowCount > 0) {
          // Firebase user already exists, return all user data
          const userData = existingUserResult.rows[0];
          const userId = userData.user_id;

          console.log(`Existing Firebase user found: ${uid} -> ${userId}`);

          // Extract user info from JSON
          const userDataJson = userData.user_json || {};

          // Prepare response with user data and preferences
          const response = {
            userId,
            isNewUser: false,
            email: userDataJson.email || email,
            displayName: userDataJson.displayName || displayName,
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

        // Check if this email already exists in apple_users (account linking)
        let userId;
        let createdAt;
        let existingPreferences = null;
        let linkedAccount = false;

        console.log(`Checking if email ${email} exists in apple_users for account linking`);

        const appleUserQuery = `
          SELECT 
            au.user_id,
            au.display_name as apple_display_name,
            u.created_at,
            up.preferences,
            up.marked_shoots
          FROM apple_users au
          INNER JOIN users u ON au.user_id = u.id
          LEFT OUTER JOIN user_preferences up ON u.id = up.user_id
          WHERE au.email = $1 AND au.email NOT LIKE '%@privaterelay.appleid.com'
        `;

        const appleUserResult = await client.query(appleUserQuery, [email]);

        if (appleUserResult.rowCount > 0) {
          // Found existing user with same email in apple_users - link accounts!
          const existingData = appleUserResult.rows[0];
          userId = existingData.user_id;
          createdAt = existingData.created_at;
          linkedAccount = true;

          // Prepare existing preferences if they exist
          if (existingData.preferences !== null || existingData.marked_shoots !== null) {
            existingPreferences = {
              filterSettings: existingData.preferences || {
                future: true,
                marked: false,
                months: [],
                search: "",
                states: [],
                notable: false,
                shootTypes: [],
              },
              markedShoots: existingData.marked_shoots || [],
            };
          }

          console.log(`🔗 Linking Firebase account to existing user ${userId} (previously signed in with Apple)`);
        }

        // If no existing user found, create new one
        if (!userId) {
          const newUser = await client.query(
              `INSERT INTO users (id, created_at) 
               VALUES (gen_random_uuid(), NOW()) 
               RETURNING id, created_at`,
          );
          userId = newUser.rows[0].id;
          createdAt = newUser.rows[0].created_at;
          console.log(`Created new user: ${userId}`);
        }

        // Create Firebase user association with JSON data
        const firebaseUserData = {
          uid,
          email,
          displayName,
          customClaims: {},
        };

        await client.query(
            `INSERT INTO firebase_users (firebase_uid, user_id, user_json, linked_at) 
             VALUES ($1, $2, $3, NOW())`,
            [uid, userId, JSON.stringify(firebaseUserData)],
        );

        console.log(`Associated Firebase user ${uid} with user ${userId}`);

        // Return user data with preferences if it's a linked account
        const response = {
          userId,
          isNewUser: !linkedAccount,
          email,
          displayName,
          createdAt,
          preferences: existingPreferences,
        };

        if (linkedAccount) {
          response.linkedAccount = true;
          response.message = "Account successfully linked with existing Apple account";
        }

        return res.json(response);
      } catch (error) {
        console.error("Error associating Firebase user:", error);
        return res.status(500).json({error: "Failed to associate Firebase user"});
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


