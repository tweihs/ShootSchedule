import pandas as pd
import sqlite3
import os
import psycopg2
from dotenv import load_dotenv
from WeatherEstimation import add_weather_estimates_to_dataframe


def csv_to_sqlite_with_weather(csv_file: str, sqlite_file: str):
    """
    Converts a CSV file into an SQLite database with PostgreSQL-compatible schema
    and weather estimates.

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
        # Create table matching PostgreSQL schema exactly, with weather columns
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
            "longitude" REAL,
            "morning_temp_f" INTEGER,
            "afternoon_temp_f" INTEGER,
            "morning_temp_c" INTEGER,
            "afternoon_temp_c" INTEGER,
            "duration_days" INTEGER,
            "morning_temp_band" TEXT,
            "afternoon_temp_band" TEXT,
            "estimation_method" TEXT
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
            'CREATE INDEX IF NOT EXISTS idx_latitude_longitude ON shoots("latitude", "longitude");',
            'CREATE INDEX IF NOT EXISTS idx_afternoon_temp ON shoots("afternoon_temp_f");',
            'CREATE INDEX IF NOT EXISTS idx_duration ON shoots("duration_days");'
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
        
        # Add weather estimates to the dataframe
        print("Adding weather estimates...")
        df = add_weather_estimates_to_dataframe(df)
        print(f"Weather estimates added for {len(df)} shoots")

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
        
        # Show weather data sample
        cursor.execute('''
        SELECT "Shoot Name", "Start Date", "State", 
               "morning_temp_f", "afternoon_temp_f", "duration_days"
        FROM shoots 
        WHERE "morning_temp_f" IS NOT NULL 
        LIMIT 5
        ''')
        sample_weather = cursor.fetchall()
        print("\nSample weather data:")
        for row in sample_weather:
            print(f"  {row[0]} ({row[2]}, {row[1]}): {row[3]}°F-{row[4]}°F, {row[5]} day(s)")

    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        conn.close()


def postgres_to_sqlite_with_weather(sqlite_file: str, database_url: str = None):
    """
    Creates SQLite database directly from PostgreSQL database with weather estimates.
    
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
        
        # Add weather estimates to the dataframe
        print("Adding weather estimates...")
        df = add_weather_estimates_to_dataframe(df)
        print(f"Weather estimates added for {len(df)} shoots")
        
    except Exception as e:
        print(f"Error connecting to PostgreSQL: {e}")
        raise
    
    # Create SQLite database
    sqlite_conn = sqlite3.connect(sqlite_file)
    cursor = sqlite_conn.cursor()
    
    try:
        # Create table matching PostgreSQL schema exactly, with weather columns
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
            "longitude" REAL,
            "morning_temp_f" INTEGER,
            "afternoon_temp_f" INTEGER,
            "morning_temp_c" INTEGER,
            "afternoon_temp_c" INTEGER,
            "duration_days" INTEGER,
            "morning_temp_band" TEXT,
            "afternoon_temp_band" TEXT,
            "estimation_method" TEXT
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
            'CREATE INDEX IF NOT EXISTS idx_latitude_longitude ON shoots("latitude", "longitude");',
            'CREATE INDEX IF NOT EXISTS idx_afternoon_temp ON shoots("afternoon_temp_f");',
            'CREATE INDEX IF NOT EXISTS idx_duration ON shoots("duration_days");'
        ]

        for index in indexes:
            cursor.execute(index)

        # Insert data from DataFrame into SQLite
        df.to_sql('shoots', sqlite_conn, if_exists='replace', index=False)
        sqlite_conn.commit()
        print(f"SQLite database successfully created at: {sqlite_file}")

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
        cursor.execute('''
        SELECT "Shoot Name", "Start Date", "Event Type", "State", 
               "morning_temp_f", "afternoon_temp_f", "duration_days"
        FROM shoots 
        LIMIT 5
        ''')
        sample_data = cursor.fetchall()
        print("\nSample data from SQLite:")
        for row in sample_data:
            print(f"  {row[0]} | {row[1]} | {row[2]} | {row[3]} | {row[4]}°F-{row[5]}°F | {row[6]}d")
        
    except Exception as e:
        print(f"An error occurred creating SQLite: {e}")
        raise
    finally:
        sqlite_conn.close()


def test():
    """
    Test function that creates SQLite from live PostgreSQL database with weather.
    """

    current_directory = os.getcwd()
    print("Current Working Directory:", current_directory)

    test_sqlite = './data/shoots_with_weather.sqlite'

    # Ensure the data directory exists
    os.makedirs('./data', exist_ok=True)

    try:
        print("Running test with live PostgreSQL database and weather estimation...")
        postgres_to_sqlite_with_weather(test_sqlite)
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
        
        cursor.execute('SELECT COUNT(*) FROM shoots WHERE "morning_temp_f" IS NOT NULL')
        weather_count = cursor.fetchone()[0]
        
        cursor.execute('SELECT AVG("afternoon_temp_f") FROM shoots WHERE "afternoon_temp_f" IS NOT NULL')
        avg_temp = cursor.fetchone()[0]
        
        print(f"📊 Database contains {count:,} shoots across {event_types} event types and {states} states")
        print(f"🌡️ Weather data available for {weather_count:,} shoots (avg afternoon temp: {avg_temp:.1f}°F)")
        
        conn.close()
        
    except Exception as e:
        print(f"❌ Test failed: {e}")


def main():
    """
    Main function to create SQLite database from various sources with weather estimation.
    Defaults to PostgreSQL source for live data.
    """
    import argparse

    current_directory = os.getcwd()
    print("Current Working Directory:", current_directory)

    parser = argparse.ArgumentParser(
        description='Create SQLite Database with Weather Estimates from PostgreSQL (default) or CSV sources.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Default: Create from live PostgreSQL database with weather (uses default sqlite path)
  python CreateSqliteWithWeather.py
  
  # Use specific SQLite path
  python CreateSqliteWithWeather.py --sqlite custom_path/shoots_with_weather.sqlite
  
  # Use specific PostgreSQL URL
  python CreateSqliteWithWeather.py --database-url "postgres://..."
  
  # Use CSV file as source
  python CreateSqliteWithWeather.py --source csv --csv data.csv
        """
    )
    
    parser.add_argument('--source', choices=['csv', 'postgres'], default='postgres',
                       help='Data source: postgres (default) or csv')
    parser.add_argument('--sqlite', 
                       help='Path to the output SQLite file (default: ./data/shoots_with_weather.sqlite)')
    parser.add_argument('--csv', 
                       help='Path to the input CSV file (required when source=csv)')
    parser.add_argument('--database-url', 
                       help='PostgreSQL database URL (optional, reads from .env if not provided)')

    args = parser.parse_args()

    # Set default SQLite file if not provided
    if not args.sqlite:
        args.sqlite = './data/shoots_with_weather.sqlite'
    
    # Ensure the data directory exists
    sqlite_dir = os.path.dirname(args.sqlite)
    if sqlite_dir and not os.path.exists(sqlite_dir):
        os.makedirs(sqlite_dir, exist_ok=True)

    try:
        if args.source == 'csv':
            if not args.csv:
                parser.error("--csv is required when source=csv")
            print(f"Creating SQLite database with weather estimates from CSV: {args.csv}")
            csv_to_sqlite_with_weather(args.csv, args.sqlite)
        else:  # Default to postgres
            print(f"Creating SQLite database with weather estimates from live PostgreSQL database")
            postgres_to_sqlite_with_weather(args.sqlite, args.database_url)
            
        print(f"\n✅ Success! SQLite database with weather estimates created at: {args.sqlite}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        exit(1)


if __name__ == '__main__':
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == 'test':
        test()
    else:
        main()