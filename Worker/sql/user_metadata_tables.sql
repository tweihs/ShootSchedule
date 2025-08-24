-- Function to check if an index exists
CREATE OR REPLACE FUNCTION index_exists(idx_name text)
    RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE indexname = idx_name
    );
END;
$$ LANGUAGE plpgsql;

-- Create user_metadata table if it doesn't exist
DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT FROM pg_tables
            WHERE schemaname = 'public'
              AND tablename = 'user_metadata'
        ) THEN
            CREATE TABLE user_metadata (
                                           id SERIAL PRIMARY KEY,
                                           user_id UUID NOT NULL,
                                           user_agent TEXT,
                                           platform TEXT,
                                           language TEXT,
                                           screen_resolution TEXT,
                                           timezone TEXT,
                                           timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                                           created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );

            RAISE NOTICE 'Created user_metadata table';
        ELSE
            RAISE NOTICE 'user_metadata table already exists';
        END IF;
    END $$;

-- Create filter_settings table if it doesn't exist
DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT FROM pg_tables
            WHERE schemaname = 'public'
              AND tablename = 'filter_settings'
        ) THEN
            CREATE TABLE filter_settings (
                                             id SERIAL PRIMARY KEY,
                                             user_id UUID NOT NULL,
                                             filter_settings JSONB NOT NULL,
                                             timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                                             created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );

            RAISE NOTICE 'Created filter_settings table';
        ELSE
            RAISE NOTICE 'filter_settings table already exists';
        END IF;
    END $$;

-- Create indexes if they don't exist
DO $$
    BEGIN
        -- Index for user_metadata.user_id
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_user_metadata_user_id') THEN
            CREATE INDEX idx_user_metadata_user_id ON user_metadata(user_id);
            RAISE NOTICE 'Created index idx_user_metadata_user_id';
        ELSE
            RAISE NOTICE 'Index idx_user_metadata_user_id already exists';
        END IF;

        -- Index for filter_settings.user_id
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_filter_settings_user_id') THEN
            CREATE INDEX idx_filter_settings_user_id ON filter_settings(user_id);
            RAISE NOTICE 'Created index idx_filter_settings_user_id';
        ELSE
            RAISE NOTICE 'Index idx_filter_settings_user_id already exists';
        END IF;

        -- Index for filter_settings.timestamp
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_filter_settings_timestamp') THEN
            CREATE INDEX idx_filter_settings_timestamp ON filter_settings(timestamp);
            RAISE NOTICE 'Created index idx_filter_settings_timestamp';
        ELSE
            RAISE NOTICE 'Index idx_filter_settings_timestamp already exists';
        END IF;
    END $$;

-- Add any missing columns to user_metadata
DO $$
    BEGIN
        -- Check and add user_agent column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = 'user_metadata'
              AND column_name = 'user_agent'
        ) THEN
            ALTER TABLE user_metadata ADD COLUMN user_agent TEXT;
            RAISE NOTICE 'Added user_agent column to user_metadata';
        END IF;

        -- Add similar checks for other columns as needed
    END $$;

-- Add any missing columns to filter_settings
DO $$
    BEGIN
        -- Check and add filter_settings column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = 'filter_settings'
              AND column_name = 'filter_settings'
        ) THEN
            ALTER TABLE filter_settings ADD COLUMN filter_settings JSONB NOT NULL DEFAULT '{}';
            RAISE NOTICE 'Added filter_settings column to filter_settings';
        END IF;

        -- Add similar checks for other columns as needed
    END $$;