# ShootSchedule Database Generator

Python scripts for generating SQLite databases for the ShootSchedule mobile app from live PostgreSQL data.

## Quick Start

### Generate Mobile Database (Simplest)

```bash
# Navigate to source directory
cd Worker/python/src

# Generate mobile database from live PostgreSQL
python3 generate_mobile_db.py

# Custom output location
python3 generate_mobile_db.py /path/to/custom/shoots.sqlite
```

The simple generator will:
- ✅ Connect to live PostgreSQL database automatically
- ✅ Generate `shoots.sqlite` with all current shooting events
- ✅ Copy to iOS project automatically (if path exists)
- ✅ Show database statistics

### Advanced Usage

```bash
# Default: Use live PostgreSQL database
python3 CreateSqlite.py --sqlite shoots.sqlite

# Use specific PostgreSQL URL
python3 CreateSqlite.py --sqlite shoots.sqlite --database-url "postgres://user:pass@host:5432/db"

# Use CSV file as source (legacy)
python3 CreateSqlite.py --source csv --csv data.csv --sqlite shoots.sqlite

# Show help
python3 CreateSqlite.py --help
```

## Database Schema

The generated SQLite database contains a `shoots` table with the exact schema as PostgreSQL:

- `"Shoot ID"` - Unique identifier
- `"Shoot Name"` - Event name
- `"Event Type"` - NSCA, NSSA, or ATA
- `"Start Date"` / `"End Date"` - Event dates
- `"State"`, `"City"` - Location information
- `"latitude"`, `"longitude"` - GPS coordinates for mapping
- Plus club details, contact info, etc.

## Requirements

```bash
pip install pandas psycopg2-binary python-dotenv
```

## Environment Setup

Create a `.env` file with your PostgreSQL credentials:

```env
DATABASE_URL=postgres://username:password@host:port/database
```

Or the script will look for database credentials in the existing project `.env` files.

## File Structure

- `CreateSqlite.py` - Main script with PostgreSQL and CSV support
- `generate_mobile_db.py` - Simple wrapper for easy deployment
- `shoots.sqlite` - Generated mobile database (3+ MB with 7,000+ events)

## Deployment Workflow

1. **Development**: Use `generate_mobile_db.py` to refresh local database
2. **Production**: Automate with `CreateSqlite.py --sqlite shoots.sqlite`
3. **iOS Build**: Database automatically included in app bundle
4. **App Updates**: App can download fresh SQLite files via URL

## Statistics

Current database contains:
- **7,000+** shooting events
- **3 event types** (NSCA, NSSA, ATA)
- **All 50 US states** represented
- **GPS coordinates** for mapping
- **File size**: ~3 MB compressed SQLite