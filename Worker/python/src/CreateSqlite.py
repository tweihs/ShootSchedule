import pandas as pd
import sqlite3
import os
import psycopg2
from dotenv import load_dotenv
from WeatherEstimation import add_weather_estimates_to_dataframe
from datetime import datetime, timezone


def csv_to_sqlite(csv_file: str, sqlite_file: str):
    """
    Converts a CSV file into an SQLite database with PostgreSQL-compatible schema.

    Args:
        csv_file (str): Path to the CSV input file.
        sqlite_file (str): Path to the SQLite output file.
    """
    if not os.path.exists(csv_file):
        raise FileNotFoundError(f"CSV file not found: {csv_file}")

    # Load CSV into Pandas DataFrame
    df = pd.read_csv(csv_file)

    # Create SQLite database and table with PostgreSQL-compatible schema
    conn = sqlite3.connect(sqlite_file)
    cursor = conn.cursor()

    try:
        # Create table matching PostgreSQL schema exactly
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS shoots (
            "Shoot ID" INTEGER PRIMARY KEY,
            "Shoot Name" TEXT,
            "Shoot Type" TEXT,
            "Start Date" TEXT,
            "End Date" TEXT,
            "Club Name" TEXT,
            "Address 1" TEXT,
            "Address 2" TEXT,
            "City" TEXT,
            "State" TEXT,
            "Zip" TEXT,
            "Country" TEXT,
            "Zone" INTEGER,
            "Club E-Mail" TEXT,
            "POC Name" TEXT,
            "POC Phone" TEXT,
            "POC E-Mail" TEXT,
            "ClubID" INTEGER,
            "Event Type" TEXT,
            "Region" TEXT,
            "full_address" TEXT,
            "latitude" REAL,
            "longitude" REAL
        );
        ''')

        # Add indexes for faster querying
        indexes = [
            'CREATE INDEX IF NOT EXISTS idx_shoot_name ON shoots("Shoot Name");',
            'CREATE INDEX IF NOT EXISTS idx_start_date ON shoots("Start Date");',
            'CREATE INDEX IF NOT EXISTS idx_end_date ON shoots("End Date");',
            'CREATE INDEX IF NOT EXISTS idx_club_name ON shoots("Club Name");',
            'CREATE INDEX IF NOT EXISTS idx_event_type ON shoots("Event Type");',
            'CREATE INDEX IF NOT EXISTS idx_state ON shoots("State");',
            'CREATE INDEX IF NOT EXISTS idx_latitude_longitude ON shoots("latitude", "longitude");'
        ]

        for index in indexes:
            cursor.execute(index)

        # Map CSV columns to PostgreSQL column names
        column_mapping = {
            df.columns[0]: "Shoot ID",
            df.columns[1]: "Shoot Name", 
            df.columns[2]: "Shoot Type",
            df.columns[3]: "Start Date",
            df.columns[4]: "End Date",
            df.columns[5]: "Club Name",
            df.columns[6]: "Address 1",
            df.columns[7]: "Address 2", 
            df.columns[8]: "City",
            df.columns[9]: "State",
            df.columns[10]: "Zip",
            df.columns[11]: "Country",
            df.columns[12]: "Zone",
            df.columns[13]: "Club E-Mail",
            df.columns[14]: "POC Name",
            df.columns[15]: "POC Phone",
            df.columns[16]: "POC E-Mail",
            df.columns[17]: "ClubID",
            df.columns[18]: "Event Type",
            df.columns[19]: "Region",
            df.columns[20]: "full_address",
            df.columns[21]: "latitude",
            df.columns[22]: "longitude"
        }

        # Rename DataFrame columns to match PostgreSQL
        df = df.rename(columns=column_mapping)

        # Insert data from the DataFrame into the SQLite database
        df.to_sql('shoots', conn, if_exists='replace', index=False)
        conn.commit()
        print(f"SQLite database successfully created at: {sqlite_file}")

        # Sanity Check
        cursor.execute("SELECT COUNT(*) FROM shoots;")
        db_row_count = cursor.fetchone()[0]
        csv_row_count = len(df)

        if db_row_count == 0:
            raise ValueError("Sanity Check Failed: Database contains zero records.")

        if db_row_count != csv_row_count:
            raise ValueError(
                f"Sanity Check Failed: Database row count ({db_row_count}) "
                f"does not match CSV row count ({csv_row_count})."
            )

        print(f"Sanity Check Passed: {db_row_count} records in the database match the CSV file.")

    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        conn.close()


def postgres_to_sqlite(sqlite_file: str, database_url: str = None):
    """
    Creates SQLite database directly from PostgreSQL database.
    
    Args:
        sqlite_file (str): Path to the output SQLite file.
        database_url (str): PostgreSQL database URL. If None, reads from .env
    """
    # Load environment variables if no URL provided
    if database_url is None:
        load_dotenv()
        database_url = os.getenv('DATABASE_URL')
    
    if not database_url:
        raise ValueError("DATABASE_URL not found in environment or provided as parameter")
    
    # Connect to PostgreSQL and read data
    try:
        pg_conn = psycopg2.connect(database_url)
        
        # Query all data from shoots table
        query = """
        SELECT "Shoot ID", "Shoot Name", "Shoot Type", "Start Date", "End Date",
               "Club Name", "Address 1", "Address 2", "City", "State", "Zip",
               "Country", "Zone", "Club E-Mail", "POC Name", "POC Phone", 
               "POC E-Mail", "ClubID", "Event Type", "Region", 
               "full_address", "latitude", "longitude"
        FROM shoots 
        ORDER BY "Start Date" ASC
        """
        
        df = pd.read_sql_query(query, pg_conn)
        pg_conn.close()
        
        print(f"Retrieved {len(df)} records from PostgreSQL")
        
    except Exception as e:
        print(f"Error connecting to PostgreSQL: {e}")
        raise
    
    # Create SQLite database
    sqlite_conn = sqlite3.connect(sqlite_file)
    cursor = sqlite_conn.cursor()
    
    try:
        # Create table matching PostgreSQL schema exactly
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS shoots (
            "Shoot ID" INTEGER PRIMARY KEY,
            "Shoot Name" TEXT,
            "Shoot Type" TEXT,
            "Start Date" TEXT,
            "End Date" TEXT,
            "Club Name" TEXT,
            "Address 1" TEXT,
            "Address 2" TEXT,
            "City" TEXT,
            "State" TEXT,
            "Zip" TEXT,
            "Country" TEXT,
            "Zone" INTEGER,
            "Club E-Mail" TEXT,
            "POC Name" TEXT,
            "POC Phone" TEXT,
            "POC E-Mail" TEXT,
            "ClubID" INTEGER,
            "Event Type" TEXT,
            "Region" TEXT,
            "full_address" TEXT,
            "latitude" REAL,
            "longitude" REAL
        );
        ''')

        # Add indexes for faster querying
        indexes = [
            'CREATE INDEX IF NOT EXISTS idx_shoot_name ON shoots("Shoot Name");',
            'CREATE INDEX IF NOT EXISTS idx_start_date ON shoots("Start Date");',
            'CREATE INDEX IF NOT EXISTS idx_end_date ON shoots("End Date");',
            'CREATE INDEX IF NOT EXISTS idx_club_name ON shoots("Club Name");',
            'CREATE INDEX IF NOT EXISTS idx_event_type ON shoots("Event Type");',
            'CREATE INDEX IF NOT EXISTS idx_state ON shoots("State");',
            'CREATE INDEX IF NOT EXISTS idx_latitude_longitude ON shoots("latitude", "longitude");'
        ]

        for index in indexes:
            cursor.execute(index)

        # Insert data from DataFrame into SQLite
        df.to_sql('shoots', sqlite_conn, if_exists='replace', index=False)
        
        # Create and populate metadata table with update timestamp
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS metadata (
                key TEXT PRIMARY KEY,
                value TEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Insert or update the last_updated timestamp
        update_time = datetime.now(timezone.utc).isoformat()
        cursor.execute('''
            INSERT OR REPLACE INTO metadata (key, value, updated_at)
            VALUES ('last_updated', ?, CURRENT_TIMESTAMP)
        ''', (update_time,))
        
        # Also add shoot count for verification
        cursor.execute('''
            INSERT OR REPLACE INTO metadata (key, value, updated_at)
            VALUES ('shoot_count', ?, CURRENT_TIMESTAMP)
        ''', (str(len(df)),))
        
        sqlite_conn.commit()
        print(f"SQLite database successfully created at: {sqlite_file}")
        print(f"📅 Database updated at: {update_time}")

        # Sanity Check
        cursor.execute("SELECT COUNT(*) FROM shoots;")
        db_row_count = cursor.fetchone()[0]
        
        if db_row_count == 0:
            raise ValueError("Sanity Check Failed: Database contains zero records.")
            
        if db_row_count != len(df):
            raise ValueError(
                f"Sanity Check Failed: SQLite row count ({db_row_count}) "
                f"does not match PostgreSQL row count ({len(df)})."
            )
            
        print(f"Sanity Check Passed: {db_row_count} records successfully copied to SQLite.")
        
        # Show sample data
        cursor.execute('SELECT "Shoot Name", "Start Date", "Event Type", "State" FROM shoots LIMIT 5')
        sample_data = cursor.fetchall()
        print("\nSample data from SQLite:")
        for row in sample_data:
            print(f"  {row[0]} | {row[1]} | {row[2]} | {row[3]}")
        
    except Exception as e:
        print(f"An error occurred creating SQLite: {e}")
        raise
    finally:
        sqlite_conn.close()


def test():
    """
    Test function that creates SQLite from live PostgreSQL database.
    """

    current_directory = os.getcwd()
    print("Current Working Directory:", current_directory)

    test_sqlite = './data/shoots.sqlite'

    # Ensure the data directory exists
    os.makedirs('./data', exist_ok=True)

    try:
        print("Running test with live PostgreSQL database...")
        postgres_to_sqlite(test_sqlite)
        print(f"✅ Test passed: SQLite database created successfully at {test_sqlite}")
        
        # Show some basic stats
        import sqlite3
        conn = sqlite3.connect(test_sqlite)
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM shoots")
        count = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(DISTINCT "Event Type") FROM shoots WHERE "Event Type" IS NOT NULL')
        event_types = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(DISTINCT "State") FROM shoots WHERE "State" IS NOT NULL')
        states = cursor.fetchone()[0]
        
        print(f"📊 Database contains {count:,} shoots across {event_types} event types and {states} states")
        
        conn.close()
        
    except Exception as e:
        print(f"❌ Test failed: {e}")


def main():
    """
    Main function to create SQLite database from various sources.
    Defaults to PostgreSQL source for live data.
    """
    import argparse

    current_directory = os.getcwd()
    print("Current Working Directory:", current_directory)

    parser = argparse.ArgumentParser(
        description='Create SQLite Database from PostgreSQL (default) or CSV sources.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Default: Create from live PostgreSQL database
  python CreateSqlite.py --sqlite shoots.sqlite
  
  # Use specific PostgreSQL URL
  python CreateSqlite.py --sqlite shoots.sqlite --database-url "postgres://..."
  
  # Use CSV file as source
  python CreateSqlite.py --source csv --csv data.csv --sqlite shoots.sqlite
        """
    )
    
    parser.add_argument('--source', choices=['csv', 'postgres'], default='postgres',
                       help='Data source: postgres (default) or csv')
    parser.add_argument('--sqlite', required=True, 
                       help='Path to the output SQLite file')
    parser.add_argument('--csv', 
                       help='Path to the input CSV file (required when source=csv)')
    parser.add_argument('--database-url', 
                       help='PostgreSQL database URL (optional, reads from .env if not provided)')

    args = parser.parse_args()

    try:
        if args.source == 'csv':
            if not args.csv:
                parser.error("--csv is required when source=csv")
            print(f"Creating SQLite database from CSV: {args.csv}")
            csv_to_sqlite(args.csv, args.sqlite)
        else:  # Default to postgres
            print(f"Creating SQLite database from live PostgreSQL database")
            postgres_to_sqlite(args.sqlite, args.database_url)
            
        print(f"\n✅ Success! SQLite database created at: {args.sqlite}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        exit(1)


if __name__ == '__main__':
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == 'test':
        test()
    else:
        main()
