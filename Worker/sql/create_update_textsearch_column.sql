CREATE OR REPLACE FUNCTION update_textsearch_column() RETURNS trigger
LANGUAGE plpgsql
AS
$$
BEGIN
    NEW.textsearchable_index_col :=
            setweight(to_tsvector('english', coalesce(NEW."State", '')), 'A') ||
            setweight(to_tsvector('english', coalesce(NEW."Shoot Name", '')), 'B') ||
            setweight(to_tsvector('english', coalesce(NEW."Club Name", '')), 'C') ||
            setweight(to_tsvector('english', coalesce(NEW."Shoot Type", '')), 'D');
--             || setweight(to_tsvector('english', coalesce(lower(to_char(NEW."Start Date", 'Mon')), '')), 'D'); -- Changed 'E' to 'D'
    RETURN NEW;
END;
$$;

ALTER FUNCTION update_textsearch_column() OWNER TO kzmotecycnjjqw;