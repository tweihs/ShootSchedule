SELECT
    EXTRACT(YEAR FROM "Start Date") AS Year,
    COUNT(CASE WHEN "Event Type" = 'NSSA' THEN 1 END) AS NSSA,
    COUNT(CASE WHEN "Event Type" = 'NSCA' THEN 1 END) AS NSCA
FROM
    public.shoots
WHERE
    EXTRACT(YEAR FROM "Start Date") >= 2020
GROUP BY
    EXTRACT(YEAR FROM "Start Date")
ORDER BY
    Year;

WITH year_counts AS (
    SELECT
        "State",
        EXTRACT(YEAR FROM "Start Date") AS Year,
        COUNT(*) AS event_count
    FROM
        public.shoots
    GROUP BY
        "State",
        EXTRACT(YEAR FROM "Start Date")
)
SELECT
    "State",
    COALESCE(SUM(CASE WHEN Year = 2020 THEN event_count END), 0) AS "2020",
    COALESCE(SUM(CASE WHEN Year = 2021 THEN event_count END), 0) AS "2021",
    COALESCE(SUM(CASE WHEN Year = 2022 THEN event_count END), 0) AS "2022",
    COALESCE(SUM(CASE WHEN Year = 2023 THEN event_count END), 0) AS "2023"
FROM
    year_counts
GROUP BY
    "State"
ORDER BY
    "State";

WITH year_counts AS (
    SELECT
        "State",
        EXTRACT(YEAR FROM "Start Date") AS Year,
        COUNT(*) AS event_count
    FROM
        public.shoots
    GROUP BY
        "State",
        EXTRACT(YEAR FROM "Start Date")
),
pivot_data AS (
    SELECT
        "State",
        COALESCE(SUM(CASE WHEN Year = 2020 THEN event_count END), 0) AS "2020",
        COALESCE(SUM(CASE WHEN Year = 2021 THEN event_count END), 0) AS "2021",
        COALESCE(SUM(CASE WHEN Year = 2022 THEN event_count END), 0) AS "2022",
        COALESCE(SUM(CASE WHEN Year = 2023 THEN event_count END), 0) AS "2023"
    FROM
        year_counts
    GROUP BY
        "State"
)
SELECT
    "State",
    "2020",
    "2021",
    "2022",
    "2023",
    ROUND(
        CASE
            WHEN "2020" = 0 THEN NULL
            ELSE (POWER(("2023"::float / NULLIF("2020", 0)), 1.0 / 3) - 1) * 100
        END, 2
    ) AS CAGR
FROM
    pivot_data
ORDER BY
    "State";
