#!/usr/bin/env zsh

# Generic PostgreSQL Schema Dumper
# Extracts clean schema from PostgreSQL database using pg_dump
# Reads database URL from ../.env file
# Outputs to ../sql/create_schema.sql

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}PostgreSQL Schema Dumper${NC}"
echo "=========================="

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"
OUTPUT_FILE="$PROJECT_ROOT/sql/create_schema.sql"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    echo "Please create a .env file in your project root with database URL:"
    echo ""
    echo -e "${BLUE}DATABASE_URL=postgresql://username:password@localhost:5432/database_name${NC}"
    echo ""
    echo "Alternative formats supported:"
    echo "  postgres://username:password@localhost:5432/database_name"
    echo "  postgresql://username@localhost/database_name"
    echo "  postgresql://username:password@localhost/database_name"
    exit 1
fi

# Load environment variables
echo "Loading database config from .env..."
export $(grep -v '^#' "$ENV_FILE" | grep -v '^

# Validate required environment variable
if [ -z "$DATABASE_URL" ]; then
    echo -e "${RED}Error: DATABASE_URL not found in .env file${NC}"
    echo "Please add DATABASE_URL to your .env file:"
    echo ""
    echo -e "${BLUE}DATABASE_URL=postgresql://username:password@localhost:5432/database_name${NC}"
    exit 1
fi

# Parse database info from URL for display (without password)
DB_INFO=$(echo "$DATABASE_URL" | sed 's/:\/\/[^:]*:[^@]*@/:\/\/[user]:[password]@/')
echo "Database URL: $DB_INFO"

# Create output directory if it doesn't exist
OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR"

# Check if pg_dump is available
if ! command -v pg_dump &> /dev/null; then
    echo -e "${RED}Error: pg_dump not found${NC}"
    echo "Please install PostgreSQL client tools"
    exit 1
fi

# Create output directory if it doesn't exist
OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR"

# Check if pg_dump is available
if ! command -v pg_dump &> /dev/null; then
    echo -e "${RED}Error: pg_dump not found${NC}"
    echo "Please install PostgreSQL client tools"
    exit 1
fi

# Test database connection
echo ""
echo "Testing database connection..."

if ! psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to database${NC}"
    echo "Please check your DATABASE_URL and ensure the database is running"
    echo ""
    echo "Common issues:"
    echo "  - Check username/password are correct"
    echo "  - Ensure database server is running"
    echo "  - Verify host and port are accessible"
    echo "  - Confirm database name exists"
    exit 1
fi

echo -e "${GREEN}✓ Database connection successful${NC}"

# Extract database name for display
DB_NAME=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')

# Dump the schema
echo ""
echo "Dumping schema to $OUTPUT_FILE..."

# Create a clean, portable schema dump
pg_dump \
    "$DATABASE_URL" \
    --schema-only \
    --no-owner \
    --no-privileges \
    --no-tablespaces \
    --no-security-labels \
    --schema=public \
    | sed 's/public\.//g' \
    | sed '/^--/d' \
    | sed '/^SET /d' \
    | sed '/^SELECT pg_catalog/d' \
    | sed '/^$/N;/^\n$/d' \
    > "$OUTPUT_FILE.tmp"

# Add header to the file
cat > "$OUTPUT_FILE" << EOF
-- Database Schema
-- Generated on $(date '+%Y-%m-%d %H:%M:%S')
-- Source: PostgreSQL database '$DB_NAME'
--
-- This is a clean, portable schema suitable for Flyway migrations
-- All PostgreSQL-specific elements have been cleaned for portability
--

EOF

# Append the cleaned schema
cat "$OUTPUT_FILE.tmp" >> "$OUTPUT_FILE"
rm "$OUTPUT_FILE.tmp"

echo -e "${GREEN}✓ Schema dump completed successfully!${NC}"
echo ""
echo "Output file: $OUTPUT_FILE"
echo "File size: $(wc -l < "$OUTPUT_FILE") lines"

# Show first few tables found
echo ""
echo "Tables found:"
grep -E "^CREATE TABLE" "$OUTPUT_FILE" | sed 's/CREATE TABLE /  - /' | sed 's/ ($//' | head -10

TOTAL_TABLES=$(grep -c "^CREATE TABLE" "$OUTPUT_FILE")
if [ "$TOTAL_TABLES" -gt 10 ]; then
    echo "  ... and $((TOTAL_TABLES - 10)) more tables"
fi

echo ""
echo -e "${YELLOW}Next steps for Flyway setup:${NC}"
echo "1. Review the generated schema in $OUTPUT_FILE"
echo "2. Create your Flyway migrations directory (e.g., src/main/resources/db/migration/)"
echo "3. Copy/rename this file to V1__baseline.sql in your migrations directory"
echo "4. Run 'flyway baseline' to mark the current database state"
echo "5. Future schema changes should be new migration files (V2__, V3__, etc.)"

echo ""
echo -e "${BLUE}Usage in other projects:${NC}"
echo "1. Copy this script to any project's /shell directory"
echo "2. Add DATABASE_URL to the project's .env file"
echo "3. Run ./shell/dump_schema.sh" | xargs)

# Validate required environment variable
if [ -z "$DATABASE_URL" ]; then
    echo -e "${RED}Error: DATABASE_URL not found in .env file${NC}"
    echo "Please add DATABASE_URL to your .env file:"
    echo ""
    echo -e "${BLUE}DATABASE_URL=postgresql://username:password@localhost:5432/database_name${NC}"
    exit 1
fi

# Parse database info from URL for display (without password)
DB_INFO=$(echo "$DATABASE_URL" | sed 's/:\/\/[^:]*:[^@]*@/:\/\/[user]:[password]@/')
echo "Database URL: $DB_INFO"

# Create output directory if it doesn't exist
OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR"

# Check if pg_dump is available
if ! command -v pg_dump &> /dev/null; then
    echo -e "${RED}Error: pg_dump not found${NC}"
    echo "Please install PostgreSQL client tools"
    exit 1
fi

# Create output directory if it doesn't exist
OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR"

# Check if pg_dump is available
if ! command -v pg_dump &> /dev/null; then
    echo -e "${RED}Error: pg_dump not found${NC}"
    echo "Please install PostgreSQL client tools"
    exit 1
fi

# Test database connection
echo ""
echo "Testing database connection..."

if ! psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to database${NC}"
    echo "Please check your DATABASE_URL and ensure the database is running"
    echo ""
    echo "Common issues:"
    echo "  - Check username/password are correct"
    echo "  - Ensure database server is running"
    echo "  - Verify host and port are accessible"
    echo "  - Confirm database name exists"
    exit 1
fi

echo -e "${GREEN}✓ Database connection successful${NC}"

# Extract database name for display
DB_NAME=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')

# Dump the schema
echo ""
echo "Dumping schema to $OUTPUT_FILE..."

# Create a clean, portable schema dump
pg_dump \
    "$DATABASE_URL" \
    --schema-only \
    --no-owner \
    --no-privileges \
    --no-tablespaces \
    --no-security-labels \
    --schema=public \
    | sed 's/public\.//g' \
    | sed '/^--/d' \
    | sed '/^SET /d' \
    | sed '/^SELECT pg_catalog/d' \
    | sed '/^$/N;/^\n$/d' \
    > "$OUTPUT_FILE.tmp"

# Add header to the file
cat > "$OUTPUT_FILE" << EOF
-- Database Schema
-- Generated on $(date '+%Y-%m-%d %H:%M:%S')
-- Source: PostgreSQL database '$DB_NAME'
--
-- This is a clean, portable schema suitable for Flyway migrations
-- All PostgreSQL-specific elements have been cleaned for portability
--

EOF

# Append the cleaned schema
cat "$OUTPUT_FILE.tmp" >> "$OUTPUT_FILE"
rm "$OUTPUT_FILE.tmp"

echo -e "${GREEN}✓ Schema dump completed successfully!${NC}"
echo ""
echo "Output file: $OUTPUT_FILE"
echo "File size: $(wc -l < "$OUTPUT_FILE") lines"

# Show first few tables found
echo ""
echo "Tables found:"
grep -E "^CREATE TABLE" "$OUTPUT_FILE" | sed 's/CREATE TABLE /  - /' | sed 's/ ($//' | head -10

TOTAL_TABLES=$(grep -c "^CREATE TABLE" "$OUTPUT_FILE")
if [ "$TOTAL_TABLES" -gt 10 ]; then
    echo "  ... and $((TOTAL_TABLES - 10)) more tables"
fi

echo ""
echo -e "${YELLOW}Next steps for Flyway setup:${NC}"
echo "1. Review the generated schema in $OUTPUT_FILE"
echo "2. Create your Flyway migrations directory (e.g., src/main/resources/db/migration/)"
echo "3. Copy/rename this file to V1__baseline.sql in your migrations directory"
echo "4. Run 'flyway baseline' to mark the current database state"
echo "5. Future schema changes should be new migration files (V2__, V3__, etc.)"

echo ""
echo -e "${BLUE}Usage in other projects:${NC}"
echo "1. Copy this script to any project's /shell directory"
echo "2. Add DATABASE_URL to the project's .env file"
echo "3. Run ./shell/dump_schema.sh"