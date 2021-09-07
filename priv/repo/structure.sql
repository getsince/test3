--
-- PostgreSQL database dump
--

-- Dumped from database version 13.1 (Debian 13.1-1.pgdg100+1)
-- Dumped by pg_dump version 13.4

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
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


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
    notice = json_build_object('queue', NEW.queue);

    PERFORM pg_notify(channel, notice::text);
  END IF;

  RETURN NULL;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_sessions (
    flake uuid NOT NULL,
    user_id uuid NOT NULL,
    expires_at timestamp with time zone NOT NULL
);


--
-- Name: apns_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.apns_devices (
    user_id uuid NOT NULL,
    token_id uuid NOT NULL,
    device_id bytea NOT NULL,
    locale character varying(255),
    topic character varying(255),
    env character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: call_invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.call_invites (
    by_user_id uuid NOT NULL,
    user_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: calls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calls (
    id uuid NOT NULL,
    caller_id uuid NOT NULL,
    called_id uuid NOT NULL,
    ended_at timestamp with time zone,
    accepted_at timestamp with time zone,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: gender_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gender_preferences (
    user_id uuid NOT NULL,
    gender character varying(255) NOT NULL
);


--
-- Name: liked_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.liked_profiles (
    by_user_id uuid NOT NULL,
    user_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: match_timeslot; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_timeslot (
    match_id uuid NOT NULL,
    picker_id uuid NOT NULL,
    slots timestamp(0) without time zone[] DEFAULT ARRAY[]::timestamp without time zone[],
    selected_slot timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matches (
    id uuid NOT NULL,
    user_id_1 uuid NOT NULL,
    user_id_2 uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: oban_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oban_jobs (
    id bigint NOT NULL,
    state public.oban_job_state DEFAULT 'available'::public.oban_job_state NOT NULL,
    queue text DEFAULT 'default'::text NOT NULL,
    worker text NOT NULL,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    errors jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    attempt integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 20 NOT NULL,
    inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    scheduled_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    attempted_at timestamp without time zone,
    completed_at timestamp without time zone,
    attempted_by text[],
    discarded_at timestamp without time zone,
    priority integer DEFAULT 0 NOT NULL,
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    meta jsonb DEFAULT '{}'::jsonb,
    cancelled_at timestamp without time zone,
    CONSTRAINT attempt_range CHECK (((attempt >= 0) AND (attempt <= max_attempts))),
    CONSTRAINT positive_max_attempts CHECK ((max_attempts > 0)),
    CONSTRAINT priority_range CHECK (((priority >= 0) AND (priority <= 3))),
    CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128))),
    CONSTRAINT worker_length CHECK (((char_length(worker) > 0) AND (char_length(worker) < 128)))
);


--
-- Name: TABLE oban_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oban_jobs IS '10';


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
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    user_id uuid NOT NULL,
    name text,
    gender text,
    location public.geography(Point,4326),
    "hidden?" boolean DEFAULT true NOT NULL,
    last_active timestamp(0) without time zone NOT NULL,
    story jsonb,
    filters jsonb DEFAULT '{}'::jsonb
);


--
-- Name: pushkit_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pushkit_devices (
    user_id uuid NOT NULL,
    token_id uuid NOT NULL,
    device_id bytea NOT NULL,
    topic character varying(255),
    env character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: user_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_reports (
    on_user_id uuid NOT NULL,
    from_user_id uuid NOT NULL,
    reason text NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    apple_id character varying(255),
    blocked_at timestamp(0) without time zone,
    onboarded_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
-- Name: oban_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs ALTER COLUMN id SET DEFAULT nextval('public.oban_jobs_id_seq'::regclass);


--
-- Name: active_sessions active_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_sessions
    ADD CONSTRAINT active_sessions_pkey PRIMARY KEY (user_id);


--
-- Name: apns_devices apns_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apns_devices
    ADD CONSTRAINT apns_devices_pkey PRIMARY KEY (user_id, token_id);


--
-- Name: call_invites call_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call_invites
    ADD CONSTRAINT call_invites_pkey PRIMARY KEY (by_user_id, user_id);


--
-- Name: calls calls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calls
    ADD CONSTRAINT calls_pkey PRIMARY KEY (id);


--
-- Name: gender_preferences gender_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gender_preferences
    ADD CONSTRAINT gender_preferences_pkey PRIMARY KEY (user_id, gender);


--
-- Name: liked_profiles liked_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.liked_profiles
    ADD CONSTRAINT liked_profiles_pkey PRIMARY KEY (by_user_id, user_id);


--
-- Name: match_timeslot match_timeslot_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_timeslot
    ADD CONSTRAINT match_timeslot_pkey PRIMARY KEY (match_id);


--
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


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
-- Name: pushkit_devices pushkit_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pushkit_devices
    ADD CONSTRAINT pushkit_devices_pkey PRIMARY KEY (user_id, token_id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: user_reports user_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_reports
    ADD CONSTRAINT user_reports_pkey PRIMARY KEY (on_user_id, from_user_id);


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
-- Name: active_sessions_flake_asc_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX active_sessions_flake_asc_index ON public.active_sessions USING btree (flake);


--
-- Name: apns_devices_device_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX apns_devices_device_id_index ON public.apns_devices USING btree (device_id);


--
-- Name: liked_profiles_user_id_by_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX liked_profiles_user_id_by_user_id_index ON public.liked_profiles USING btree (user_id, by_user_id);


--
-- Name: matches_user_id_1_user_id_2_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX matches_user_id_1_user_id_2_index ON public.matches USING btree (user_id_1, user_id_2);


--
-- Name: oban_jobs_args_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_args_index ON public.oban_jobs USING gin (args);


--
-- Name: oban_jobs_meta_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_meta_index ON public.oban_jobs USING gin (meta);


--
-- Name: oban_jobs_queue_state_priority_scheduled_at_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_queue_state_priority_scheduled_at_id_index ON public.oban_jobs USING btree (queue, state, priority, scheduled_at, id);


--
-- Name: profiles_location_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX profiles_location_index ON public.profiles USING gist (location);


--
-- Name: pushkit_devices_device_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pushkit_devices_device_id_index ON public.pushkit_devices USING btree (device_id);


--
-- Name: users_apple_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_apple_id_index ON public.users USING btree (apple_id) WHERE (apple_id IS NOT NULL);


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
-- Name: active_sessions active_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_sessions
    ADD CONSTRAINT active_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: apns_devices apns_devices_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apns_devices
    ADD CONSTRAINT apns_devices_token_id_fkey FOREIGN KEY (token_id) REFERENCES public.users_tokens(id) ON DELETE CASCADE;


--
-- Name: apns_devices apns_devices_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apns_devices
    ADD CONSTRAINT apns_devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: call_invites call_invites_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call_invites
    ADD CONSTRAINT call_invites_by_user_id_fkey FOREIGN KEY (by_user_id) REFERENCES public.active_sessions(user_id) ON DELETE CASCADE;


--
-- Name: call_invites call_invites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call_invites
    ADD CONSTRAINT call_invites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.active_sessions(user_id) ON DELETE CASCADE;


--
-- Name: calls calls_called_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calls
    ADD CONSTRAINT calls_called_id_fkey FOREIGN KEY (called_id) REFERENCES public.profiles(user_id) ON DELETE CASCADE;


--
-- Name: calls calls_caller_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calls
    ADD CONSTRAINT calls_caller_id_fkey FOREIGN KEY (caller_id) REFERENCES public.profiles(user_id) ON DELETE CASCADE;


--
-- Name: gender_preferences gender_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gender_preferences
    ADD CONSTRAINT gender_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: liked_profiles liked_profiles_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.liked_profiles
    ADD CONSTRAINT liked_profiles_by_user_id_fkey FOREIGN KEY (by_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: liked_profiles liked_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.liked_profiles
    ADD CONSTRAINT liked_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: match_timeslot match_timeslot_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_timeslot
    ADD CONSTRAINT match_timeslot_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: match_timeslot match_timeslot_picker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_timeslot
    ADD CONSTRAINT match_timeslot_picker_id_fkey FOREIGN KEY (picker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: matches matches_user_id_1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_user_id_1_fkey FOREIGN KEY (user_id_1) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: matches matches_user_id_2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_user_id_2_fkey FOREIGN KEY (user_id_2) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: pushkit_devices pushkit_devices_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pushkit_devices
    ADD CONSTRAINT pushkit_devices_token_id_fkey FOREIGN KEY (token_id) REFERENCES public.users_tokens(id) ON DELETE CASCADE;


--
-- Name: pushkit_devices pushkit_devices_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pushkit_devices
    ADD CONSTRAINT pushkit_devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_reports user_reports_from_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_reports
    ADD CONSTRAINT user_reports_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_reports user_reports_on_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_reports
    ADD CONSTRAINT user_reports_on_user_id_fkey FOREIGN KEY (on_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users_tokens users_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20201212184331);
INSERT INTO public."schema_migrations" (version) VALUES (20201219095342);
INSERT INTO public."schema_migrations" (version) VALUES (20201219112614);
INSERT INTO public."schema_migrations" (version) VALUES (20201231002022);
INSERT INTO public."schema_migrations" (version) VALUES (20201231002323);
INSERT INTO public."schema_migrations" (version) VALUES (20210117175420);
INSERT INTO public."schema_migrations" (version) VALUES (20210117182435);
INSERT INTO public."schema_migrations" (version) VALUES (20210323124108);
INSERT INTO public."schema_migrations" (version) VALUES (20210624195942);
INSERT INTO public."schema_migrations" (version) VALUES (20210721105547);
INSERT INTO public."schema_migrations" (version) VALUES (20210721111936);
INSERT INTO public."schema_migrations" (version) VALUES (20210723120936);
