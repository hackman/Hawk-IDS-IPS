SET client_encoding = 'SQL_ASCII';
SET check_function_bodies = false;
SET SESSION AUTHORIZATION 'postgres';
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;
SET SESSION AUTHORIZATION 'hawk';
SET search_path = public, pg_catalog;

CREATE TABLE broots (
    id serial NOT NULL,
    date timestamp without time zone DEFAULT now() NOT NULL,
    ip inet NOT NULL,
    service text NOT NULL
);

CREATE TABLE failed_log (
    id serial NOT NULL,
    date timestamp without time zone DEFAULT now() NOT NULL,
    ip inet NOT NULL,
    "user" text NOT NULL,
    service text NOT NULL,
    broot boolean DEFAULT false NOT NULL
);


ALTER TABLE ONLY failed_log
    ADD CONSTRAINT failed_log_pkey PRIMARY KEY (id);

SELECT pg_catalog.setval('broots_id_seq', 1, false);
SELECT pg_catalog.setval('failed_log_id_seq', 1, false);


COMMENT ON COLUMN broots.date IS 'When was brootforce detected';
COMMENT ON COLUMN broots.ip IS 'ip from where it was detected';
COMMENT ON COLUMN broots.service IS 'service that was under attack';
COMMENT ON COLUMN failed_log.date IS 'When was detected';
COMMENT ON COLUMN failed_log.ip IS 'ip from where it was detected';
COMMENT ON COLUMN failed_log."user" IS 'username which was under attack';
COMMENT ON COLUMN failed_log.service IS 'service which was under attack';
COMMENT ON COLUMN failed_log.broot IS 'is this a brootforce attack';

CREATE TABLE blacklist (
    id serial NOT NULL,
    date_add timestamp without time zone DEFAULT now() NOT NULL,
    date_rem timestamp without time zone,
    ip inet,
    reason text,
    count integer
);

COMMENT ON TABLE blacklist IS 'Blacklisted IPs';
ALTER TABLE ONLY blacklist ADD CONSTRAINT blacklist_pkey PRIMARY KEY (id);
CREATE INDEX date_added ON blacklist USING btree (date_add);

