--
-- PostgreSQL database dump
--

-- Dumped from database version 13.1
-- Dumped by pg_dump version 13.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: oban_job_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oban_job_state AS ENUM (
    'available',
    'scheduled',
    'executing',
    'retryable',
    'completed',
    'discarded',
    'cancelled'
);


--
-- Name: oban_jobs_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oban_jobs_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  channel text;
  notice json;
BEGIN
  IF NEW.state = 'available' THEN
    channel = 'public.oban_insert';
    notice = json_build_object('queue', NEW.queue, 'state', NEW.state);

    PERFORM pg_notify(channel, notice::text);
  END IF;

  RETURN NULL;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.emails (
    email character varying(255) NOT NULL
);


--
-- Name: oban_beats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oban_beats (
    node text NOT NULL,
    queue text NOT NULL,
    nonce text NOT NULL,
    "limit" integer NOT NULL,
    paused boolean DEFAULT false NOT NULL,
    running bigint[] DEFAULT ARRAY[]::integer[] NOT NULL,
    inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    started_at timestamp without time zone NOT NULL
);


--
-- Name: oban_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oban_jobs (
    id bigint NOT NULL,
    state public.oban_job_state DEFAULT 'available'::public.oban_job_state NOT NULL,
    queue text DEFAULT 'default'::text NOT NULL,
    worker text NOT NULL,
    args jsonb NOT NULL,
    errors jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    attempt integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 20 NOT NULL,
    inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    scheduled_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    attempted_at timestamp without time zone,
    completed_at timestamp without time zone,
    attempted_by text[],
    discarded_at timestamp without time zone,
    priority integer DEFAULT 0,
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    meta jsonb DEFAULT '{}'::jsonb,
    cancelled_at timestamp without time zone,
    CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128))),
    CONSTRAINT worker_length CHECK (((char_length(worker) > 0) AND (char_length(worker) < 128)))
);


--
-- Name: TABLE oban_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oban_jobs IS '9';


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oban_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oban_jobs_id_seq OWNED BY public.oban_jobs.id;


--
-- Name: phones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phones (
    phone_number character varying(255) NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    user_id uuid NOT NULL,
    name text,
    photos text[] DEFAULT ARRAY[]::text[],
    gender text,
    birthdate date,
    height integer,
    home_city text,
    occupation text,
    job text,
    university text,
    major text,
    most_important_in_life text,
    interests text[] DEFAULT ARRAY[]::text[],
    first_date_idea text,
    free_form text,
    music text[] DEFAULT ARRAY[]::text[],
    sports text[] DEFAULT ARRAY[]::text[],
    alcohol text,
    smoking text,
    books text[] DEFAULT ARRAY[]::text[],
    currently_studying text[] DEFAULT ARRAY[]::text[],
    tv_shows text[] DEFAULT ARRAY[]::text[],
    languages text[] DEFAULT ARRAY[]::text[],
    musical_instruments text[] DEFAULT ARRAY[]::text[],
    movies text[] DEFAULT ARRAY[]::text[],
    social_networks text[] DEFAULT ARRAY[]::text[],
    cuisines text[] DEFAULT ARRAY[]::text[],
    pets text[] DEFAULT ARRAY[]::text[]
);


--
-- Name: referral_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referral_codes (
    code character varying(255) NOT NULL,
    meta jsonb,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    phone_number character varying(255) NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    blocked_at timestamp(0) without time zone,
    onboarded_at timestamp(0) without time zone
);


--
-- Name: users_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token bytea NOT NULL,
    context character varying(255) NOT NULL,
    sent_to character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visits (
    id uuid NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: oban_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs ALTER COLUMN id SET DEFAULT nextval('public.oban_jobs_id_seq'::regclass);


--
-- Name: oban_jobs oban_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs
    ADD CONSTRAINT oban_jobs_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (user_id);


--
-- Name: referral_codes referral_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_codes
    ADD CONSTRAINT referral_codes_pkey PRIMARY KEY (code);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_tokens users_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_pkey PRIMARY KEY (id);


--
-- Name: oban_beats_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_beats_inserted_at_index ON public.oban_beats USING btree (inserted_at);


--
-- Name: oban_jobs_attempted_at_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_attempted_at_id_index ON public.oban_jobs USING btree (attempted_at DESC, id) WHERE (state = ANY (ARRAY['completed'::public.oban_job_state, 'discarded'::public.oban_job_state]));


--
-- Name: oban_jobs_queue_state_priority_scheduled_at_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_queue_state_priority_scheduled_at_id_index ON public.oban_jobs USING btree (queue, state, priority, scheduled_at, id);


--
-- Name: users_phone_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_phone_number_index ON public.users USING btree (phone_number);


--
-- Name: users_tokens_context_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_tokens_context_token_index ON public.users_tokens USING btree (context, token);


--
-- Name: users_tokens_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_tokens_user_id_index ON public.users_tokens USING btree (user_id);


--
-- Name: oban_jobs oban_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER oban_notify AFTER INSERT ON public.oban_jobs FOR EACH ROW EXECUTE FUNCTION public.oban_jobs_notify();


--
-- Name: profiles profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users_tokens users_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20201212122150);
INSERT INTO public."schema_migrations" (version) VALUES (20201212122212);
INSERT INTO public."schema_migrations" (version) VALUES (20201212184331);
INSERT INTO public."schema_migrations" (version) VALUES (20201214124702);
INSERT INTO public."schema_migrations" (version) VALUES (20201215141153);
INSERT INTO public."schema_migrations" (version) VALUES (20201219095342);
INSERT INTO public."schema_migrations" (version) VALUES (20201219112614);
INSERT INTO public."schema_migrations" (version) VALUES (20201223080010);
