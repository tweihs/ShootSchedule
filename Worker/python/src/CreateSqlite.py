import pandas as pd
import sqlite3
import os


def csv_to_sqlite(csv_file: str, sqlite_file: str):
    """
    Converts a CSV file into an SQLite database with optimized indexing.

    Args:
        csv_file (str): Path to the CSV input file.
        sqlite_file (str): Path to the SQLite output file.
    """
    if not os.path.exists(csv_file):
        raise FileNotFoundError(f"CSV file not found: {csv_file}")

    # Load CSV into Pandas DataFrame
    df = pd.read_csv(csv_file)

    # Clean column names for SQLite compatibility
    df.columns = [
        'shoot_id', 'shoot_name', 'shoot_type', 'start_date', 'end_date',
        'club_name', 'address_1', 'address_2', 'city', 'state', 'zip_code',
        'country', 'zone', 'club_email', 'poc_name', 'poc_phone', 'poc_email',
        'club_id', 'event_type', 'region', 'full_address', 'latitude', 'longitude'
    ]

    # Create SQLite database and table with indexes
    conn = sqlite3.connect(sqlite_file)
    cursor = conn.cursor()

    try:
        # Create table
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS shoot_schedule (
            shoot_id INTEGER PRIMARY KEY,
            shoot_name TEXT,
            shoot_type TEXT,
            start_date TEXT,
            end_date TEXT,
            club_name TEXT,
            address_1 TEXT,
            address_2 TEXT,
            city TEXT,
            state TEXT,
            zip_code TEXT,
            country TEXT,
            zone INTEGER,
            club_email TEXT,
            poc_name TEXT,
            poc_phone TEXT,
            poc_email TEXT,
            club_id INTEGER,
            event_type TEXT,
            region TEXT,
            full_address TEXT,
            latitude REAL,
            longitude REAL
        );
        ''')

        # Add indexes for faster querying
        indexes = [
            "CREATE INDEX IF NOT EXISTS idx_shoot_name ON shoot_schedule(shoot_name);",
            "CREATE INDEX IF NOT EXISTS idx_start_date ON shoot_schedule(start_date);",
            "CREATE INDEX IF NOT EXISTS idx_end_date ON shoot_schedule(end_date);",
            "CREATE INDEX IF NOT EXISTS idx_club_name ON shoot_schedule(club_name);",
            "CREATE INDEX IF NOT EXISTS idx_latitude_longitude ON shoot_schedule(latitude, longitude);"
        ]

        for index in indexes:
            cursor.execute(index)

        # Insert data from the DataFrame into the SQLite database
        df.to_sql('shoot_schedule', conn, if_exists='replace', index=False)
        conn.commit()
        print(f"SQLite database successfully created at: {sqlite_file}")

        # Sanity Check
        cursor.execute("SELECT COUNT(*) FROM shoot_schedule;")
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


def test():
    """
    Test function for csv_to_sqlite using predefined file paths.
    """

    current_directory = os.getcwd()
    print("Current Working Directory:", current_directory)

    test_csv = './data/Geocoded_Combined_Shoot_Schedule_2024.csv'
    test_sqlite = './data/Geocoded_Combined_Shoot_Schedule_2024.db'

    # Ensure the data directory exists
    os.makedirs('./data', exist_ok=True)

    try:
        print("Running test with actual Geocoded CSV file...")
        csv_to_sqlite(test_csv, test_sqlite)
        print(f"Test passed: SQLite database created successfully at {test_sqlite}")
    except Exception as e:
        print(f"Test failed: {e}")


def main():
    """
    Main function to run csv_to_sqlite with user-provided paths.
    """
    import argparse

    current_directory = os.getcwd()
    print("Current Working Directory:", current_directory)

    parser = argparse.ArgumentParser(description='Convert CSV to SQLite Database.')
    parser.add_argument('--csv', required=True, help='Path to the input CSV file')
    parser.add_argument('--sqlite', required=True, help='Path to the output SQLite file')

    args = parser.parse_args()
    csv_file = args.csv
    sqlite_file = args.sqlite

    try:
        csv_to_sqlite(csv_file, sqlite_file)
    except Exception as e:
        print(f"Error: {e}")


if __name__ == '__main__':
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == 'test':
        test()
    else:
        main()
