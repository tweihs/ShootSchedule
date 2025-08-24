CREATE TABLE IF NOT EXISTS public.shoots
(
    "Shoot ID"               serial PRIMARY KEY,
    "Shoot Name"             varchar,
    "Shoot Type"             varchar,
    "Start Date"             date,
    "End Date"               date,
    "Club Name"              varchar,
    "Address 1"              varchar,
    "Address 2"              varchar,
    "City"                   varchar,
    "State"                  varchar,
    "Zip"                    varchar,
    "Country"                varchar,
    "Zone"                   integer,
    "Club E-Mail"            varchar,
    "POC Name"               varchar,
    "POC Phone"              varchar,
    "POC E-Mail"             varchar,
    "ClubID"                 integer,
    "Event Type"             varchar,
    "Region"                 varchar,
    full_address             varchar,
    latitude                 double precision,
    longitude                double precision,
    textsearchable_index_col tsvector,
    insert_date   timestamp DEFAULT CURRENT_TIMESTAMP,
    update_date             timestamp DEFAULT CURRENT_TIMESTAMP
);

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_set_timestamp ON public.shoots;

-- Only create the new trigger for setting timestamps
CREATE TRIGGER trg_set_timestamp
    BEFORE INSERT OR UPDATE
    ON public.shoots
    FOR EACH ROW
EXECUTE FUNCTION set_timestamp();


ALTER TABLE public.shoots
    ADD COLUMN IF NOT EXISTS insert_date timestamp DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS update_date timestamp DEFAULT CURRENT_TIMESTAMP;