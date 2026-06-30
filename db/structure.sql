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
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: enqueue_outbox_event(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enqueue_outbox_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    INSERT INTO outbox_events (id, aggregate_type, aggregate_id, event_type, payload, created_at)
    VALUES (gen_random_uuid(), TG_ARGV[0], NEW.id, 'created',
            jsonb_build_object('status', NEW.status, 'country', NEW.country), now());
  ELSIF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
    INSERT INTO outbox_events (id, aggregate_type, aggregate_id, event_type, payload, created_at)
    VALUES (gen_random_uuid(), TG_ARGV[0], NEW.id, 'status_changed',
            jsonb_build_object('from', OLD.status, 'to', NEW.status, 'country', NEW.country), now());
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: write_audit_log(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.write_audit_log() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  rec_id uuid;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    rec_id := OLD.id;
  ELSE
    rec_id := NEW.id;
  END IF;

  INSERT INTO audit_logs (id, table_name, record_id, action, old_data, new_data, changed_at)
  VALUES (
    gen_random_uuid(), TG_TABLE_NAME, rec_id, TG_OP,
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('UPDATE', 'INSERT') THEN to_jsonb(NEW) ELSE NULL END,
    now()
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name character varying NOT NULL,
    record_id uuid NOT NULL,
    action character varying NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: bank_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bank_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    credit_application_id uuid NOT NULL,
    provider character varying NOT NULL,
    total_debt numeric(15,2),
    credit_score integer,
    account_status character varying,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    fetched_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: credit_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    country character varying NOT NULL,
    full_name text NOT NULL,
    document_number text NOT NULL,
    monthly_income text NOT NULL,
    document_type character varying NOT NULL,
    document_fingerprint character varying NOT NULL,
    amount_requested numeric(15,2) NOT NULL,
    requested_at timestamp(6) without time zone,
    status character varying DEFAULT 'received'::character varying NOT NULL,
    risk_score integer,
    flags jsonb DEFAULT '{}'::jsonb NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: outbox_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.outbox_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    aggregate_type character varying NOT NULL,
    aggregate_id uuid NOT NULL,
    event_type character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    processed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: state_transitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.state_transitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    credit_application_id uuid NOT NULL,
    from_state character varying,
    to_state character varying NOT NULL,
    actor_id uuid,
    reason character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email public.citext NOT NULL,
    password_digest character varying NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: webhook_deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_deliveries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    credit_application_id uuid NOT NULL,
    endpoint character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    last_response jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    idempotency_key character varying NOT NULL,
    source character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    processed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: bank_records bank_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_records
    ADD CONSTRAINT bank_records_pkey PRIMARY KEY (id);


--
-- Name: credit_applications credit_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_applications
    ADD CONSTRAINT credit_applications_pkey PRIMARY KEY (id);


--
-- Name: outbox_events outbox_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.outbox_events
    ADD CONSTRAINT outbox_events_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: state_transitions state_transitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.state_transitions
    ADD CONSTRAINT state_transitions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webhook_deliveries webhook_deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT webhook_deliveries_pkey PRIMARY KEY (id);


--
-- Name: webhook_events webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_events
    ADD CONSTRAINT webhook_events_pkey PRIMARY KEY (id);


--
-- Name: idx_on_credit_application_id_created_at_3f4bcfd81e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_credit_application_id_created_at_3f4bcfd81e ON public.state_transitions USING btree (credit_application_id, created_at);


--
-- Name: index_audit_logs_on_table_name_and_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_logs_on_table_name_and_record_id ON public.audit_logs USING btree (table_name, record_id);


--
-- Name: index_bank_records_on_credit_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bank_records_on_credit_application_id ON public.bank_records USING btree (credit_application_id);


--
-- Name: index_credit_applications_on_country_and_status_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_applications_on_country_and_status_and_created_at ON public.credit_applications USING btree (country, status, created_at);


--
-- Name: index_credit_applications_on_document_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_credit_applications_on_document_fingerprint ON public.credit_applications USING btree (document_fingerprint);


--
-- Name: index_outbox_events_on_aggregate_type_and_aggregate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_outbox_events_on_aggregate_type_and_aggregate_id ON public.outbox_events USING btree (aggregate_type, aggregate_id);


--
-- Name: index_outbox_events_unprocessed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_outbox_events_unprocessed ON public.outbox_events USING btree (created_at) WHERE (processed_at IS NULL);


--
-- Name: index_state_transitions_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_state_transitions_on_actor_id ON public.state_transitions USING btree (actor_id);


--
-- Name: index_state_transitions_on_credit_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_state_transitions_on_credit_application_id ON public.state_transitions USING btree (credit_application_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_webhook_deliveries_on_credit_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_deliveries_on_credit_application_id ON public.webhook_deliveries USING btree (credit_application_id);


--
-- Name: index_webhook_events_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_webhook_events_on_idempotency_key ON public.webhook_events USING btree (idempotency_key);


--
-- Name: credit_applications credit_applications_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER credit_applications_audit AFTER INSERT OR DELETE OR UPDATE ON public.credit_applications FOR EACH ROW EXECUTE FUNCTION public.write_audit_log();


--
-- Name: credit_applications credit_applications_outbox; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER credit_applications_outbox AFTER INSERT OR UPDATE ON public.credit_applications FOR EACH ROW EXECUTE FUNCTION public.enqueue_outbox_event('CreditApplication');


--
-- Name: webhook_deliveries fk_rails_450596b634; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT fk_rails_450596b634 FOREIGN KEY (credit_application_id) REFERENCES public.credit_applications(id);


--
-- Name: state_transitions fk_rails_4ca5f71e5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.state_transitions
    ADD CONSTRAINT fk_rails_4ca5f71e5b FOREIGN KEY (credit_application_id) REFERENCES public.credit_applications(id);


--
-- Name: state_transitions fk_rails_7d0ec74aae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.state_transitions
    ADD CONSTRAINT fk_rails_7d0ec74aae FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: bank_records fk_rails_9fcaf3cb38; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_records
    ADD CONSTRAINT fk_rails_9fcaf3cb38 FOREIGN KEY (credit_application_id) REFERENCES public.credit_applications(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260630120002'),
('20260630120001'),
('20260629120005'),
('20260629120004'),
('20260629120003'),
('20260629120002'),
('20260629120001');

