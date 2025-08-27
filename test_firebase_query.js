const { Client } = require('pg');

async function testFirebaseUserQuery() {
  // Read the DB URL from environment or use the one from your setup
  const dbUrl = process.env.DB_URL || 'postgres://postgres:your-password@localhost:5432/your-db';
  
  const client = new Client({
    connectionString: dbUrl,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('Connected to database');

    // First, let's see what columns exist in firebase_users
    const schemaQuery = `
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'firebase_users'
      ORDER BY ordinal_position;
    `;
    
    const schemaResult = await client.query(schemaQuery);
    console.log('\n=== firebase_users table structure ===');
    schemaResult.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type}`);
    });

    // Now let's look at a sample row to understand the data structure
    const sampleQuery = `
      SELECT * FROM firebase_users LIMIT 1;
    `;
    
    const sampleResult = await client.query(sampleQuery);
    console.log('\n=== Sample firebase_users row ===');
    if (sampleResult.rows.length > 0) {
      console.log(JSON.stringify(sampleResult.rows[0], null, 2));
    }

    // Test querying by email - try different approaches
    const testEmail = 'tyson@weihs.com';
    console.log(`\n=== Testing queries for email: ${testEmail} ===`);

    // Test 1: Direct column query (if email is a column)
    try {
      const query1 = `SELECT * FROM firebase_users WHERE email = $1`;
      const result1 = await client.query(query1, [testEmail]);
      console.log(`Query 1 (direct column): Found ${result1.rowCount} rows`);
    } catch (e) {
      console.log(`Query 1 failed: ${e.message}`);
    }

    // Test 2: JSON column with different possible names
    const jsonColumnNames = ['user_data', 'data', 'user_info', 'firebase_data'];
    for (const colName of jsonColumnNames) {
      try {
        const query = `SELECT * FROM firebase_users WHERE ${colName}->>'email' = $1`;
        const result = await client.query(query, [testEmail]);
        console.log(`Query with ${colName}->>'email': Found ${result.rowCount} rows`);
        if (result.rowCount > 0) {
          console.log('Successfully found user with column:', colName);
          console.log('User data:', JSON.stringify(result.rows[0], null, 2));
        }
      } catch (e) {
        // Silent fail, just testing different column names
      }
    }

    // Test 3: Check if there's a JSONB column by looking at all text/jsonb columns
    const jsonQuery = `
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'firebase_users' 
      AND data_type IN ('json', 'jsonb', 'text');
    `;
    
    const jsonResult = await client.query(jsonQuery);
    console.log('\n=== Possible JSON columns ===');
    
    for (const row of jsonResult.rows) {
      const colName = row.column_name;
      console.log(`\nTesting column: ${colName}`);
      
      try {
        // Try to query as JSON
        const testQuery = `SELECT ${colName} FROM firebase_users WHERE user_id = 'dd69ec4f-4b2b-48e7-867c-ff7743c07050'`;
        const testResult = await client.query(testQuery);
        
        if (testResult.rows.length > 0) {
          const value = testResult.rows[0][colName];
          console.log(`  Value type: ${typeof value}`);
          
          // Try to parse if it's a string
          if (typeof value === 'string') {
            try {
              const parsed = JSON.parse(value);
              console.log(`  Parsed JSON:`, JSON.stringify(parsed, null, 2));
              
              // Check if it contains email
              if (parsed.email) {
                console.log(`  ✅ Found email field: ${parsed.email}`);
              }
            } catch (e) {
              console.log(`  Not valid JSON`);
            }
          } else if (typeof value === 'object') {
            console.log(`  Direct object:`, JSON.stringify(value, null, 2));
            if (value && value.email) {
              console.log(`  ✅ Found email field: ${value.email}`);
            }
          }
        }
      } catch (e) {
        console.log(`  Error: ${e.message}`);
      }
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await client.end();
    console.log('\nDisconnected from database');
  }
}

// Get DB_URL from command line or environment
const dbUrl = process.argv[2] || process.env.DB_URL;
if (!dbUrl) {
  console.error('Please provide DB_URL as argument or environment variable');
  console.error('Usage: node test_firebase_query.js "postgres://user:pass@host:port/db"');
  process.exit(1);
}

process.env.DB_URL = dbUrl;
testFirebaseUserQuery();