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
        const lookup = await client.query(
            `SELECT user_id FROM user_preferences WHERE user_external_id = $1`,
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
        res.set('Content-Disposition', 'inline; filename="shoot-schedule.ics"')
        res.set('Cache-Control','public, max-age=300')

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

