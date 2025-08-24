import os
import pandas as pd
from sqlalchemy import create_engine, Table, MetaData, Column, Integer, String, Date, Float
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import inspect, event
from dotenv import load_dotenv

def load_and_insert_data(output_dir):
    # Database connection
    # DB_URI = f"postgresql://bnegptoqfyncka:75c6e3c584720a20fada97c6aee5fd81c0813e6fea05935425e36ec3b659af64@ec2-44-215-176-210.compute-1.amazonaws.com:5432/d7lhas6u4ssfim"
    #DB_URI = f"postgresql://retool:gKLQ6FNbkxZ5@ep-snowy-sun-44634698.us-west-2.retooldb.com/retool?sslmode=require"

    # Load environment variables from .env file (for local development)
    load_dotenv()

    # Get the database URL from the environment variables or use the statically defined URL
    DB_URI: str = os.getenv('DATABASE_URL', 'postgresql://u8bc0f64rlk46n:p24e608893e2e9812f8db8234878db631956fcbae5afe81febf1e95126c8fa26f@cbdhrtd93854d5.cluster-czrs8kj4isg7.us-east-1.rds.amazonaws.com:5432/de5iln7eou0tgj')

    if 'DYNO' in os.environ:
        DB_URI = DB_URI.replace("://", "ql+psycopg2://", 1)

    # Read the CSV
    geocoded_file = os.path.join(output_dir, "Geocoded_Combined_Shoot_Schedule_2024.csv")
    df = pd.read_csv(geocoded_file)

    # Convert date fields explicitly
    df['Start Date'] = pd.to_datetime(df['Start Date']).dt.date
    df['End Date'] = pd.to_datetime(df['End Date']).dt.date

    # Ensure integer fields are properly formatted; handle NaNs if necessary
    # df['Shoot ID'] = df['Shoot ID'].fillna(0).astype(int)
    # df['Zone'] = df['Zone'].fillna(0).astype(int)
    # df['ClubID'] = df['ClubID'].fillna(0).astype(int)
    if 'Shoot ID' in df.columns:
        df['Shoot ID'] = df['Shoot ID'].fillna(0).astype(int)
    if 'Zone' in df.columns:
        df['Zone'] = df['Zone'].fillna(0).astype(int)
    if 'ClubID' in df.columns:
        df['ClubID'] = df['ClubID'].fillna(0).astype(int)

    # Example of handling nulls and cleaning text fields
    df.fillna('None', inplace=True)  # Replace all NaN with 'Unknown' or another placeholder

    # Check the DataFrame output again
    print(df.head())

    # Metadata and table definition
    metadata = MetaData()
    shoots_table = Table('shoots', metadata,
        Column('Shoot ID', Integer, primary_key=True),
        Column('Shoot Name', String),
        Column('Shoot Type', String),
        Column('Start Date', Date),
        Column('End Date', Date),
        Column('Club Name', String),
        Column('Address 1', String),
        Column('Address 2', String),
        Column('City', String),
        Column('State', String),
        Column('Zip', String),
        Column('Country', String),
        Column('Zone', Integer),
        Column('Club E-Mail', String),
        Column('POC Name', String),
        Column('POC Phone', String),
        Column('POC E-Mail', String),
        Column('ClubID', Integer),
        Column('Event Type', String),
        Column('Region', String),
        Column('full_address', String),
        Column('latitude', Float),
        Column('longitude', Float),
        extend_existing=True
    )

    engine = create_engine(DB_URI)
    metadata.create_all(engine)

    # Check and create table
    inspector = inspect(engine)
    if not inspector.has_table('shoots'):
        metadata.create_all(engine)
        print("table created")
    # else:
    #     print("Table already exists.")

    # print(df.head().to_dict(orient='records'))

    # Function to log SQL
    # def log_sql(conn, cursor, statement, parameters, context, executemany):
    #     print("Statement:", statement)
    #     print("Parameters:", parameters)

    # Add event listener to log SQL
    # event.listen(engine, "before_cursor_execute", log_sql)
    # event.listen(engine, "before_cursor_execute")

    # Convert DataFrame to list of dictionaries
    # records = df.to_dict(orient='records')
    # batch_size = 100  # You can adjust the batch size based on your needs
    # with engine.connect() as conn:
    #     for i in range(0, len(records), batch_size):
    #         batch = records[i:i + batch_size]
    #         upsert_stmt = pg_insert(shoots_table).values(batch)
    #         update_dict = {c.name: upsert_stmt.excluded[c.name] for c in shoots_table.columns if c.name != 'Shoot ID'}
    #         upsert_stmt = upsert_stmt.on_conflict_do_update(
    #             index_elements=['Shoot ID'],
    #             set_=update_dict
    #         )
    #         conn.execute(upsert_stmt)
    #
    # print("Data upserted successfully.")

    # # Insert or update data row by row
    with engine.connect() as conn:
        has_error = False
        trans = conn.begin()  # Begin a transaction
        df = df.drop_duplicates(subset=["Shoot ID"], keep='last')
        records = df.to_dict(orient='records')
        batch_size = 197
        try:
            # for index, row in df.iterrows():
            for index in range(0, len(records), batch_size):
                # stmt = insert(shoots_table).values(row.to_dict())
                batch = records[index:index + batch_size]

                for record in batch:
                    start_date = record.get('Start Date', 'N/A')
                    shoot_id = record.get('Shoot ID', 'N/A')
                    shoot_name = record.get('Shoot Name', 'N/A')
                    # print(f"Batch record {start_date} {shoot_id} {shoot_name}")

                stmt = insert(shoots_table).values(batch)
                update_dict = {c.name: stmt.excluded[c.name] for c in shoots_table.columns if
                               c.name != 'Shoot ID'}
                on_conflict_stmt = stmt.on_conflict_do_update(
                    index_elements=['Shoot ID'],
                    set_=update_dict
                )
                conn.execute(on_conflict_stmt)
                # print("Batch inserted")
                # print(f"Successfully inserted/updated row {index} {row['Start Date']} {row['Shoot ID']} {row['Shoot Name']}")

            # trans.commit()  # Commit the transaction
        except SQLAlchemyError as e:
            print(f"Error inserting/updating data: {e}")
            has_error = True

        if has_error:
            trans.rollback()  # Roll back the transaction on error
        else:
            trans.commit()
            print("All data committed successfully.")


if __name__ == "__main__":
    # Determine if running inside a Docker container
    if os.path.exists('/.dockerenv'):
        output_dir = "/app/data"
    else:
        output_dir = "../data"

    load_and_insert_data(output_dir)