-- Database Schema
-- Generated on 2025-07-19 09:11:53
-- Source: PostgreSQL database ''
--
-- This is a clean, portable schema suitable for Flyway migrations
-- All PostgreSQL-specific elements have been cleaned for portability
--

CREATE SCHEMA public;

COMMENT ON SCHEMA public IS 'standard public schema';
CREATE TABLE shoots (
    "Shoot ID" integer NOT NULL,
    "Shoot Name" character varying,
    "Shoot Type" character varying,
    "Start Date" date,
    "End Date" date,
    "Club Name" character varying,
    "Address 1" character varying,
    "Address 2" character varying,
    "City" character varying,
    "State" character varying,
    "Zip" character varying,
    "Country" character varying,
    "Zone" integer,
    "Club E-Mail" character varying,
    "POC Name" character varying,
    "POC Phone" character varying,
    "POC E-Mail" character varying,
    "ClubID" integer,
    "Event Type" character varying,
    "Region" character varying,
    full_address character varying,
    latitude double precision,
    longitude double precision
);

CREATE SEQUENCE "shoots_Shoot ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "shoots_Shoot ID_seq" OWNED BY shoots."Shoot ID";

ALTER TABLE ONLY shoots ALTER COLUMN "Shoot ID" SET DEFAULT nextval('"shoots_Shoot ID_seq"'::regclass);

ALTER TABLE ONLY shoots
    ADD CONSTRAINT shoots_pkey PRIMARY KEY ("Shoot ID");
