--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

DROP INDEX public.date_added;
SET search_path = exim, pg_catalog;

DROP INDEX exim.date;
SET search_path = public, pg_catalog;

ALTER TABLE ONLY public.failed_log DROP CONSTRAINT failed_log_pkey;
ALTER TABLE ONLY public.blacklist DROP CONSTRAINT blacklist_pkey;
ALTER TABLE public.failed_log ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.broots ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.blacklist ALTER COLUMN id DROP DEFAULT;
SET search_path = exim, pg_catalog;

ALTER TABLE exim.mail_quota ALTER COLUMN id DROP DEFAULT;
SET search_path = public, pg_catalog;

DROP SEQUENCE public.failed_log_id_seq;
DROP TABLE public.failed_log;
DROP SEQUENCE public.broots_id_seq;
DROP TABLE public.broots;
DROP SEQUENCE public.blacklist_id_seq;
DROP TABLE public.blacklist;
SET search_path = exim, pg_catalog;

DROP SEQUENCE exim.mail_quota_id_seq;
DROP TABLE exim.mail_quota;
DROP SCHEMA public;
DROP SCHEMA exim;
--
-- Name: exim; Type: SCHEMA; Schema: -; Owner: hawk_local
--

CREATE SCHEMA exim;


ALTER SCHEMA exim OWNER TO hawk_local;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


SET search_path = exim, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: mail_quota; Type: TABLE; Schema: exim; Owner: hawk_local; Tablespace: 
--

CREATE TABLE mail_quota (
    id integer NOT NULL,
    date time without time zone NOT NULL,
    username text NOT NULL,
    address text NOT NULL,
    quota bigint NOT NULL,
    used bigint NOT NULL,
    per double precision NOT NULL
);


ALTER TABLE exim.mail_quota OWNER TO hawk_local;

--
-- Name: COLUMN mail_quota.date; Type: COMMENT; Schema: exim; Owner: hawk_local
--

COMMENT ON COLUMN mail_quota.date IS 'Date added';


--
-- Name: COLUMN mail_quota.username; Type: COMMENT; Schema: exim; Owner: hawk_local
--

COMMENT ON COLUMN mail_quota.username IS 'username ';


--
-- Name: COLUMN mail_quota.address; Type: COMMENT; Schema: exim; Owner: hawk_local
--

COMMENT ON COLUMN mail_quota.address IS 'E-Mail address';


--
-- Name: COLUMN mail_quota.quota; Type: COMMENT; Schema: exim; Owner: hawk_local
--

COMMENT ON COLUMN mail_quota.quota IS 'Max mail quota in bytes';


--
-- Name: COLUMN mail_quota.used; Type: COMMENT; Schema: exim; Owner: hawk_local
--

COMMENT ON COLUMN mail_quota.used IS 'Used quota ';


--
-- Name: COLUMN mail_quota.per; Type: COMMENT; Schema: exim; Owner: hawk_local
--

COMMENT ON COLUMN mail_quota.per IS 'Percent used quota';


--
-- Name: mail_quota_id_seq; Type: SEQUENCE; Schema: exim; Owner: hawk_local
--

CREATE SEQUENCE mail_quota_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE exim.mail_quota_id_seq OWNER TO hawk_local;

--
-- Name: mail_quota_id_seq; Type: SEQUENCE OWNED BY; Schema: exim; Owner: hawk_local
--

ALTER SEQUENCE mail_quota_id_seq OWNED BY mail_quota.id;


SET search_path = public, pg_catalog;

--
-- Name: blacklist; Type: TABLE; Schema: public; Owner: hawk_local; Tablespace: 
--

CREATE TABLE blacklist (
    id integer NOT NULL,
    date_add timestamp without time zone DEFAULT now() NOT NULL,
    date_rem timestamp without time zone,
    ip inet,
    reason text,
    count integer
);


ALTER TABLE public.blacklist OWNER TO hawk_local;

--
-- Name: TABLE blacklist; Type: COMMENT; Schema: public; Owner: hawk_local
--

COMMENT ON TABLE blacklist IS 'Blacklisted IPs';


--
-- Name: blacklist_id_seq; Type: SEQUENCE; Schema: public; Owner: hawk_local
--

CREATE SEQUENCE blacklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.blacklist_id_seq OWNER TO hawk_local;

--
-- Name: blacklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hawk_local
--

ALTER SEQUENCE blacklist_id_seq OWNED BY blacklist.id;


--
-- Name: broots; Type: TABLE; Schema: public; Owner: hawk_local; Tablespace: 
--

CREATE TABLE broots (
    id integer NOT NULL,
    date timestamp without time zone DEFAULT now() NOT NULL,
    ip inet NOT NULL,
    service integer NOT NULL
);


ALTER TABLE public.broots OWNER TO hawk_local;

--
-- Name: COLUMN broots.date; Type: COMMENT; Schema: public; Owner: hawk_local
--

COMMENT ON COLUMN broots.date IS 'When was brootforce detected';


--
-- Name: COLUMN broots.ip; Type: COMMENT; Schema: public; Owner: hawk_local
--

COMMENT ON COLUMN broots.ip IS 'ip from where it was detected';


--
-- Name: COLUMN broots.service; Type: COMMENT; Schema: public; Owner: hawk_local
--

COMMENT ON COLUMN broots.service IS 'service that was under attack';


--
-- Name: broots_id_seq; Type: SEQUENCE; Schema: public; Owner: hawk_local
--

CREATE SEQUENCE broots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.broots_id_seq OWNER TO hawk_local;

--
-- Name: broots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hawk_local
--

ALTER SEQUENCE broots_id_seq OWNED BY broots.id;


--
-- Name: failed_log; Type: TABLE; Schema: public; Owner: hawk_local; Tablespace: 
--

CREATE TABLE failed_log (
    id integer NOT NULL,
    date timestamp without time zone DEFAULT now() NOT NULL,
    ip inet NOT NULL,
    "user" text NOT NULL,
    service integer NOT NULL,
    broot boolean DEFAULT false NOT NULL
);


ALTER TABLE public.failed_log OWNER TO hawk_local;

--
-- Name: COLUMN failed_log.date; Type: COMMENT; Schema: public; Owner: hawk_local
--

COMMENT ON COLUMN failed_log.date IS 'When was detected';


--
-- Name: COLUMN failed_log.ip; Type: COMMENT; Schema: public; Owner: hawk_local
--

COMMENT ON COLUMN failed_log.ip IS 'ip from where it was detected';


--
-- Name: COLUMN failed_log."user"; Type: COMMENT; Schema: public; Owner: hawk_local
--

COMMENT ON COLUMN failed_log."user" IS 'username which was under attack';


--
-- Name: COLUMN failed_log.service; Type: COMMENT; Schema: public; Owner: hawk_local
--

COMMENT ON COLUMN failed_log.service IS 'service which was under attack';


--
-- Name: COLUMN failed_log.broot; Type: COMMENT; Schema: public; Owner: hawk_local
--

COMMENT ON COLUMN failed_log.broot IS 'is this a brootforce attack';


--
-- Name: failed_log_id_seq; Type: SEQUENCE; Schema: public; Owner: hawk_local
--

CREATE SEQUENCE failed_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.failed_log_id_seq OWNER TO hawk_local;

--
-- Name: failed_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hawk_local
--

ALTER SEQUENCE failed_log_id_seq OWNED BY failed_log.id;


SET search_path = exim, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: exim; Owner: hawk_local
--

ALTER TABLE mail_quota ALTER COLUMN id SET DEFAULT nextval('mail_quota_id_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: hawk_local
--

ALTER TABLE blacklist ALTER COLUMN id SET DEFAULT nextval('blacklist_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: hawk_local
--

ALTER TABLE broots ALTER COLUMN id SET DEFAULT nextval('broots_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: hawk_local
--

ALTER TABLE failed_log ALTER COLUMN id SET DEFAULT nextval('failed_log_id_seq'::regclass);


--
-- Name: blacklist_pkey; Type: CONSTRAINT; Schema: public; Owner: hawk_local; Tablespace: 
--

ALTER TABLE ONLY blacklist
    ADD CONSTRAINT blacklist_pkey PRIMARY KEY (id);


--
-- Name: failed_log_pkey; Type: CONSTRAINT; Schema: public; Owner: hawk_local; Tablespace: 
--

ALTER TABLE ONLY failed_log
    ADD CONSTRAINT failed_log_pkey PRIMARY KEY (id);


SET search_path = exim, pg_catalog;

--
-- Name: date; Type: INDEX; Schema: exim; Owner: hawk_local; Tablespace: 
--

CREATE INDEX date ON mail_quota USING btree (date);


SET search_path = public, pg_catalog;

--
-- Name: date_added; Type: INDEX; Schema: public; Owner: hawk_local; Tablespace: 
--

CREATE INDEX date_added ON blacklist USING btree (date_add);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

