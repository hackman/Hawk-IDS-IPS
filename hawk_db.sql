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

CREATE SCHEMA exim;

SET search_path = exim, pg_catalog;

CREATE TABLE mail_quota (
    id integer NOT NULL,
    date time without time zone NOT NULL,
    username text NOT NULL,
    address text NOT NULL,
    quota bigint NOT NULL,
    used bigint NOT NULL,
    per double precision NOT NULL
);

COMMENT ON COLUMN mail_quota.date IS 'Date added';
COMMENT ON COLUMN mail_quota.username IS 'username ';
COMMENT ON COLUMN mail_quota.address IS 'E-Mail address';
COMMENT ON COLUMN mail_quota.quota IS 'Max mail quota in bytes';
COMMENT ON COLUMN mail_quota.used IS 'Used quota ';
COMMENT ON COLUMN mail_quota.per IS 'Percent used quota';

CREATE SEQUENCE mail_quota_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

ALTER SEQUENCE mail_quota_id_seq OWNED BY mail_quota.id;
ALTER TABLE mail_quota ALTER COLUMN id SET DEFAULT nextval('mail_quota_id_seq'::regclass);

CREATE INDEX date ON mail_quota USING btree (date);

ALTER TABLE exim.mail_quota_id_seq OWNER TO hawk;
ALTER TABLE exim.mail_quota OWNER TO hawk;
