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
-- Name: apns_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.apns_devices (
    user_id uuid NOT NULL,
    session_token uuid NOT NULL,
    device_id bytea NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: disliked_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disliked_profiles (
    by_user_id uuid NOT NULL,
    user_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.emails (
    email character varying(255) NOT NULL
);


--
-- Name: interests_overlap; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interests_overlap (
    user_id_1 uuid NOT NULL,
    user_id_2 uuid NOT NULL,
    score integer NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
-- Name: match_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_messages (
    match_id uuid NOT NULL,
    id uuid NOT NULL,
    author_id uuid NOT NULL,
    kind character varying(255) NOT NULL,
    data jsonb NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matches (
    id uuid NOT NULL,
    user_id_1 uuid NOT NULL,
    user_id_2 uuid NOT NULL,
    "alive?" boolean DEFAULT true NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    "pending?" boolean
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
-- Name: profile_feeds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profile_feeds (
    user_id uuid NOT NULL,
    date date NOT NULL,
    profiles jsonb NOT NULL,
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
    city text,
    occupation text,
    job text,
    university text,
    major text,
    most_important_in_life text,
    interests text[] DEFAULT ARRAY[]::text[],
    first_date_idea text,
    free_form text,
    tastes jsonb DEFAULT '{}'::jsonb NOT NULL,
    times_liked integer DEFAULT 0 NOT NULL,
    "hidden?" boolean DEFAULT true NOT NULL,
    last_active timestamp(0) without time zone DEFAULT '2021-01-16 14:00:30.859495'::timestamp without time zone NOT NULL
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
-- Name: seen_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seen_profiles (
    by_user_id uuid NOT NULL,
    user_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL
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
    phone_number character varying(255) NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    blocked_at timestamp(0) without time zone,
    onboarded_at timestamp(0) without time zone,
    deleted_at timestamp with time zone
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
-- Name: apns_devices apns_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apns_devices
    ADD CONSTRAINT apns_devices_pkey PRIMARY KEY (user_id, session_token);


--
-- Name: disliked_profiles disliked_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disliked_profiles
    ADD CONSTRAINT disliked_profiles_pkey PRIMARY KEY (by_user_id, user_id);


--
-- Name: interests_overlap interests_overlap_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interests_overlap
    ADD CONSTRAINT interests_overlap_pkey PRIMARY KEY (user_id_1, user_id_2);


--
-- Name: liked_profiles liked_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.liked_profiles
    ADD CONSTRAINT liked_profiles_pkey PRIMARY KEY (by_user_id, user_id);


--
-- Name: match_messages match_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_messages
    ADD CONSTRAINT match_messages_pkey PRIMARY KEY (match_id, id);


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
-- Name: profile_feeds profile_feeds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profile_feeds
    ADD CONSTRAINT profile_feeds_pkey PRIMARY KEY (user_id, date);


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
-- Name: seen_profiles seen_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seen_profiles
    ADD CONSTRAINT seen_profiles_pkey PRIMARY KEY (by_user_id, user_id);


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
-- Name: interests_overlap_user_id_1_user_id_2_score_desc_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX interests_overlap_user_id_1_user_id_2_score_desc_index ON public.interests_overlap USING btree (user_id_1, user_id_2, score DESC) WHERE (score > 0);


--
-- Name: interests_overlap_user_id_2_user_id_1_score_desc_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX interests_overlap_user_id_2_user_id_1_score_desc_index ON public.interests_overlap USING btree (user_id_2, user_id_1, score DESC) WHERE (score > 0);


--
-- Name: liked_profiles_user_id_by_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX liked_profiles_user_id_by_user_id_index ON public.liked_profiles USING btree (user_id, by_user_id);


--
-- Name: matches_user_id_1_pending_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX matches_user_id_1_pending_index ON public.matches USING btree (user_id_1, "pending?") WHERE ("pending?" = true);


--
-- Name: matches_user_id_1_user_id_2_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX matches_user_id_1_user_id_2_index ON public.matches USING btree (user_id_1, user_id_2);


--
-- Name: matches_user_id_2_pending_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX matches_user_id_2_pending_index ON public.matches USING btree (user_id_2, "pending?") WHERE ("pending?" = true);


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
-- Name: profiles_date_trunc__day___last_active__timestamp_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX profiles_date_trunc__day___last_active__timestamp_index ON public.profiles USING btree (date_trunc('day'::text, last_active));


--
-- Name: profiles_gender_hidden_times_liked_desc_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX profiles_gender_hidden_times_liked_desc_index ON public.profiles USING btree (gender, "hidden?", times_liked DESC) WHERE ("hidden?" = false);


--
-- Name: user_id_1_alive_match; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_id_1_alive_match ON public.matches USING btree (user_id_1, "alive?") WHERE ("alive?" = true);


--
-- Name: user_id_2_alive_match; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_id_2_alive_match ON public.matches USING btree (user_id_2, "alive?") WHERE ("alive?" = true);


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
-- Name: apns_devices apns_devices_session_token_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apns_devices
    ADD CONSTRAINT apns_devices_session_token_fkey FOREIGN KEY (session_token) REFERENCES public.users_tokens(id) ON DELETE CASCADE;


--
-- Name: apns_devices apns_devices_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apns_devices
    ADD CONSTRAINT apns_devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: disliked_profiles disliked_profiles_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disliked_profiles
    ADD CONSTRAINT disliked_profiles_by_user_id_fkey FOREIGN KEY (by_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: disliked_profiles disliked_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disliked_profiles
    ADD CONSTRAINT disliked_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: interests_overlap interests_overlap_user_id_1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interests_overlap
    ADD CONSTRAINT interests_overlap_user_id_1_fkey FOREIGN KEY (user_id_1) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: interests_overlap interests_overlap_user_id_2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interests_overlap
    ADD CONSTRAINT interests_overlap_user_id_2_fkey FOREIGN KEY (user_id_2) REFERENCES public.users(id) ON DELETE CASCADE;


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
-- Name: match_messages match_messages_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_messages
    ADD CONSTRAINT match_messages_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: match_messages match_messages_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_messages
    ADD CONSTRAINT match_messages_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


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
-- Name: profile_feeds profile_feeds_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profile_feeds
    ADD CONSTRAINT profile_feeds_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: seen_profiles seen_profiles_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seen_profiles
    ADD CONSTRAINT seen_profiles_by_user_id_fkey FOREIGN KEY (by_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: seen_profiles seen_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seen_profiles
    ADD CONSTRAINT seen_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


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

INSERT INTO public."schema_migrations" (version) VALUES (20201212122150);
INSERT INTO public."schema_migrations" (version) VALUES (20201212122212);
INSERT INTO public."schema_migrations" (version) VALUES (20201212184331);
INSERT INTO public."schema_migrations" (version) VALUES (20201214124702);
INSERT INTO public."schema_migrations" (version) VALUES (20201215141153);
INSERT INTO public."schema_migrations" (version) VALUES (20201219095342);
INSERT INTO public."schema_migrations" (version) VALUES (20201219112614);
INSERT INTO public."schema_migrations" (version) VALUES (20201223080010);
INSERT INTO public."schema_migrations" (version) VALUES (20201231001626);
INSERT INTO public."schema_migrations" (version) VALUES (20201231002022);
INSERT INTO public."schema_migrations" (version) VALUES (20201231002323);
INSERT INTO public."schema_migrations" (version) VALUES (20210113151839);
INSERT INTO public."schema_migrations" (version) VALUES (20210113153633);
INSERT INTO public."schema_migrations" (version) VALUES (20210113212327);
INSERT INTO public."schema_migrations" (version) VALUES (20210113220005);
INSERT INTO public."schema_migrations" (version) VALUES (20210113224758);
INSERT INTO public."schema_migrations" (version) VALUES (20210113230120);
INSERT INTO public."schema_migrations" (version) VALUES (20210114212305);
INSERT INTO public."schema_migrations" (version) VALUES (20210117175420);
INSERT INTO public."schema_migrations" (version) VALUES (20210117182435);
INSERT INTO public."schema_migrations" (version) VALUES (20210118001343);
INSERT INTO public."schema_migrations" (version) VALUES (20210130101400);
INSERT INTO public."schema_migrations" (version) VALUES (20210130101533);
INSERT INTO public."schema_migrations" (version) VALUES (20210130101812);
