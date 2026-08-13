SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: prevent_expense_description_revision_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_expense_description_revision_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN RAISE EXCEPTION 'expense description revisions are append-only' USING ERRCODE = '55000'; END; $$;


--
-- Name: prevent_expense_share_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_expense_share_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN RAISE EXCEPTION 'expense shares are append-only' USING ERRCODE = '55000'; END; $$;


--
-- Name: prevent_future_expense_description_revision(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_future_expense_description_revision() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF NEW.created_at > clock_timestamp() THEN RAISE EXCEPTION 'expense description revision cannot be future-dated' USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: prevent_payment_command_receipt_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_payment_command_receipt_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'payment command receipts are append-only'
    USING ERRCODE = '55000';
END;
$$;


--
-- Name: protect_expense_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_expense_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'expenses are append-only' USING ERRCODE = '55000'; END IF;
  IF NEW.created_at IS DISTINCT FROM OLD.created_at OR NEW.group_id IS DISTINCT FROM OLD.group_id OR NEW.paid_by_user_id IS DISTINCT FROM OLD.paid_by_user_id OR NEW.created_by_user_id IS DISTINCT FROM OLD.created_by_user_id OR NEW.amount_cents IS DISTINCT FROM OLD.amount_cents OR NEW.occurred_on IS DISTINCT FROM OLD.occurred_on OR NEW.replaces_expense_id IS DISTINCT FROM OLD.replaces_expense_id THEN RAISE EXCEPTION 'financial expense history is immutable' USING ERRCODE = '55000'; END IF;
  IF OLD.voided_at IS NULL THEN
    IF NEW.voided_at IS NULL AND NEW.voided_by_user_id IS NULL AND NEW.void_reason IS NULL THEN RETURN NEW; END IF;
    IF NEW.voided_at IS NULL OR NEW.voided_by_user_id IS NULL OR NEW.void_reason IS NULL THEN RAISE EXCEPTION 'expense void metadata must transition atomically' USING ERRCODE = '55000'; END IF;
    RETURN NEW;
  END IF;
  IF NEW.voided_at IS DISTINCT FROM OLD.voided_at OR NEW.voided_by_user_id IS DISTINCT FROM OLD.voided_by_user_id OR NEW.void_reason IS DISTINCT FROM OLD.void_reason THEN RAISE EXCEPTION 'expense void metadata is immutable' USING ERRCODE = '55000'; END IF;
  RETURN NEW;
END;
$$;


--
-- Name: require_expense_description_revision(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.require_expense_description_revision() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.description IS NOT DISTINCT FROM OLD.description THEN RETURN NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM (SELECT previous_description, new_description FROM expense_description_revisions WHERE expense_id = NEW.id ORDER BY created_at DESC, id DESC LIMIT 1) latest_revision WHERE latest_revision.previous_description = OLD.description AND latest_revision.new_description = NEW.description) THEN RAISE EXCEPTION 'expense description update requires the latest append-only revision' USING ERRCODE = '23514'; END IF;
  RETURN NULL;
END;
$$;


--
-- Name: validate_expense_replacement(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_expense_replacement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE original_group_id uuid; original_voided_at timestamp; original_voided_by_user_id uuid;
BEGIN
  IF NEW.replaces_expense_id IS NULL THEN RETURN NULL; END IF;
  SELECT group_id, voided_at, voided_by_user_id INTO original_group_id, original_voided_at, original_voided_by_user_id FROM expenses WHERE id = NEW.replaces_expense_id;
  IF original_group_id IS NULL OR original_group_id IS DISTINCT FROM NEW.group_id OR original_voided_at IS NULL OR original_voided_by_user_id IS DISTINCT FROM NEW.created_by_user_id THEN RAISE EXCEPTION 'expense replacement must preserve the voiding actor in the same group' USING ERRCODE = '23514'; END IF;
  RETURN NULL;
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
-- Name: expense_description_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expense_description_revisions (
    id uuid DEFAULT uuidv7() NOT NULL,
    expense_id uuid NOT NULL,
    actor_user_id uuid NOT NULL,
    previous_description character varying NOT NULL,
    new_description character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: expense_shares; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expense_shares (
    id uuid DEFAULT uuidv7() NOT NULL,
    expense_id uuid NOT NULL,
    user_id uuid NOT NULL,
    amount_owed_cents bigint NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT expense_shares_amount_positive CHECK ((amount_owed_cents > 0))
);


--
-- Name: expenses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expenses (
    id uuid DEFAULT uuidv7() NOT NULL,
    group_id uuid NOT NULL,
    paid_by_user_id uuid NOT NULL,
    created_by_user_id uuid NOT NULL,
    amount_cents bigint NOT NULL,
    description character varying NOT NULL,
    occurred_on date NOT NULL,
    voided_at timestamp(6) without time zone,
    voided_by_user_id uuid,
    void_reason character varying,
    replaces_expense_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT expenses_amount_positive CHECK ((amount_cents > 0)),
    CONSTRAINT expenses_no_self_replacement CHECK (((replaces_expense_id IS NULL) OR (replaces_expense_id <> id))),
    CONSTRAINT expenses_void_metadata_complete CHECK ((((voided_at IS NULL) AND (voided_by_user_id IS NULL) AND (void_reason IS NULL)) OR ((voided_at IS NOT NULL) AND (voided_by_user_id IS NOT NULL) AND (void_reason IS NOT NULL))))
);


--
-- Name: financial_command_receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.financial_command_receipts (
    id uuid DEFAULT uuidv7() CONSTRAINT payment_command_receipts_id_not_null NOT NULL,
    payment_id uuid,
    command_type character varying CONSTRAINT payment_command_receipts_command_type_not_null NOT NULL,
    idempotency_key uuid CONSTRAINT payment_command_receipts_idempotency_key_not_null NOT NULL,
    request_fingerprint character varying CONSTRAINT payment_command_receipts_request_fingerprint_not_null NOT NULL,
    created_at timestamp(6) without time zone CONSTRAINT payment_command_receipts_created_at_not_null NOT NULL,
    updated_at timestamp(6) without time zone CONSTRAINT payment_command_receipts_updated_at_not_null NOT NULL,
    expense_id uuid,
    CONSTRAINT financial_command_receipts_result_matches_type CHECK (((((command_type)::text = ANY ((ARRAY['report'::character varying, 'confirm'::character varying, 'cancel'::character varying])::text[])) AND (payment_id IS NOT NULL) AND (expense_id IS NULL)) OR (((command_type)::text = 'expense_correct'::text) AND (payment_id IS NULL) AND (expense_id IS NOT NULL))))
);


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groups (
    id uuid DEFAULT uuidv7() NOT NULL,
    name character varying NOT NULL,
    currency_code character varying NOT NULL,
    financial_state_version bigint DEFAULT 0 NOT NULL,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT groups_financial_state_version_nonnegative CHECK ((financial_state_version >= 0))
);


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id uuid DEFAULT uuidv7() NOT NULL,
    group_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role character varying NOT NULL,
    status character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    "position" integer NOT NULL,
    CONSTRAINT memberships_position_nonnegative CHECK (("position" >= 0)),
    CONSTRAINT memberships_role_valid CHECK (((role)::text = ANY ((ARRAY['owner'::character varying, 'member'::character varying])::text[]))),
    CONSTRAINT memberships_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id uuid DEFAULT uuidv7() NOT NULL,
    group_id uuid NOT NULL,
    from_user_id uuid NOT NULL,
    to_user_id uuid NOT NULL,
    amount_cents bigint NOT NULL,
    status character varying NOT NULL,
    idempotency_key uuid NOT NULL,
    request_fingerprint character varying NOT NULL,
    source_financial_state_version bigint NOT NULL,
    reported_by_user_id uuid NOT NULL,
    reported_at timestamp(6) without time zone NOT NULL,
    confirmed_by_user_id uuid,
    confirmed_at timestamp(6) without time zone,
    cancelled_by_user_id uuid,
    cancelled_at timestamp(6) without time zone,
    cancellation_reason character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT payments_amount_positive CHECK ((amount_cents > 0)),
    CONSTRAINT payments_audit_metadata_matches_status CHECK (((((status)::text = 'reported'::text) AND (confirmed_by_user_id IS NULL) AND (confirmed_at IS NULL) AND (cancelled_by_user_id IS NULL) AND (cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR (((status)::text = 'confirmed'::text) AND (confirmed_by_user_id IS NOT NULL) AND (confirmed_at IS NOT NULL) AND (cancelled_by_user_id IS NULL) AND (cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR (((status)::text = 'cancelled'::text) AND (confirmed_by_user_id IS NULL) AND (confirmed_at IS NULL) AND (cancelled_by_user_id IS NOT NULL) AND (cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL)))),
    CONSTRAINT payments_distinct_participants CHECK ((from_user_id <> to_user_id)),
    CONSTRAINT payments_source_version_nonnegative CHECK ((source_financial_state_version >= 0)),
    CONSTRAINT payments_status_valid CHECK (((status)::text = ANY ((ARRAY['reported'::character varying, 'confirmed'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT uuidv7() NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: expense_description_revisions expense_description_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_description_revisions
    ADD CONSTRAINT expense_description_revisions_pkey PRIMARY KEY (id);


--
-- Name: expense_shares expense_shares_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_shares
    ADD CONSTRAINT expense_shares_pkey PRIMARY KEY (id);


--
-- Name: expenses expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_pkey PRIMARY KEY (id);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: financial_command_receipts payment_command_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_command_receipts
    ADD CONSTRAINT payment_command_receipts_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


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
-- Name: idx_on_expense_id_created_at_4bec3b7817; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_expense_id_created_at_4bec3b7817 ON public.expense_description_revisions USING btree (expense_id, created_at);


--
-- Name: index_expense_description_revisions_on_actor_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expense_description_revisions_on_actor_user_id ON public.expense_description_revisions USING btree (actor_user_id);


--
-- Name: index_expense_shares_on_expense_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_expense_shares_on_expense_id_and_user_id ON public.expense_shares USING btree (expense_id, user_id);


--
-- Name: index_expense_shares_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expense_shares_on_user_id ON public.expense_shares USING btree (user_id);


--
-- Name: index_expenses_on_created_by_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expenses_on_created_by_user_id ON public.expenses USING btree (created_by_user_id);


--
-- Name: index_expenses_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expenses_on_group_id ON public.expenses USING btree (group_id);


--
-- Name: index_expenses_on_paid_by_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expenses_on_paid_by_user_id ON public.expenses USING btree (paid_by_user_id);


--
-- Name: index_expenses_on_replaces_expense_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_expenses_on_replaces_expense_id_unique ON public.expenses USING btree (replaces_expense_id) WHERE (replaces_expense_id IS NOT NULL);


--
-- Name: index_expenses_on_voided_by_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expenses_on_voided_by_user_id ON public.expenses USING btree (voided_by_user_id);


--
-- Name: index_financial_command_receipts_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_financial_command_receipts_on_idempotency_key ON public.financial_command_receipts USING btree (idempotency_key);


--
-- Name: index_financial_receipts_on_expense_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_financial_receipts_on_expense_and_type ON public.financial_command_receipts USING btree (expense_id, command_type) WHERE (expense_id IS NOT NULL);


--
-- Name: index_financial_receipts_on_payment_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_financial_receipts_on_payment_and_type ON public.financial_command_receipts USING btree (payment_id, command_type) WHERE (payment_id IS NOT NULL);


--
-- Name: index_memberships_on_group_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_group_id_and_position ON public.memberships USING btree (group_id, "position");


--
-- Name: index_memberships_on_group_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_group_id_and_user_id ON public.memberships USING btree (group_id, user_id);


--
-- Name: index_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_user_id ON public.memberships USING btree (user_id);


--
-- Name: index_payments_on_cancelled_by_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_cancelled_by_user_id ON public.payments USING btree (cancelled_by_user_id);


--
-- Name: index_payments_on_confirmed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_confirmed_at ON public.payments USING btree (confirmed_at);


--
-- Name: index_payments_on_confirmed_by_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_confirmed_by_user_id ON public.payments USING btree (confirmed_by_user_id);


--
-- Name: index_payments_on_from_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_from_user_id ON public.payments USING btree (from_user_id);


--
-- Name: index_payments_on_group_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_group_id_and_status ON public.payments USING btree (group_id, status);


--
-- Name: index_payments_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_idempotency_key ON public.payments USING btree (idempotency_key);


--
-- Name: index_payments_on_reported_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_reported_at ON public.payments USING btree (reported_at);


--
-- Name: index_payments_on_reported_by_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_reported_by_user_id ON public.payments USING btree (reported_by_user_id);


--
-- Name: index_payments_on_to_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_to_user_id ON public.payments USING btree (to_user_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: expenses expense_description_revision_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER expense_description_revision_guard AFTER UPDATE OF description ON public.expenses DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.require_expense_description_revision();


--
-- Name: expense_description_revisions expense_description_revisions_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER expense_description_revisions_append_only BEFORE DELETE OR UPDATE ON public.expense_description_revisions FOR EACH ROW EXECUTE FUNCTION public.prevent_expense_description_revision_mutation();


--
-- Name: expense_description_revisions expense_description_revisions_no_future_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER expense_description_revisions_no_future_timestamp BEFORE INSERT ON public.expense_description_revisions FOR EACH ROW EXECUTE FUNCTION public.prevent_future_expense_description_revision();


--
-- Name: expenses expense_replacement_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER expense_replacement_integrity AFTER INSERT OR UPDATE OF replaces_expense_id, group_id ON public.expenses DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.validate_expense_replacement();


--
-- Name: expense_shares expense_shares_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER expense_shares_append_only BEFORE DELETE OR UPDATE ON public.expense_shares FOR EACH ROW EXECUTE FUNCTION public.prevent_expense_share_mutation();


--
-- Name: expenses expenses_history_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER expenses_history_guard BEFORE DELETE OR UPDATE ON public.expenses FOR EACH ROW EXECUTE FUNCTION public.protect_expense_history();


--
-- Name: financial_command_receipts payment_command_receipts_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER payment_command_receipts_append_only BEFORE DELETE OR UPDATE ON public.financial_command_receipts FOR EACH ROW EXECUTE FUNCTION public.prevent_payment_command_receipt_mutation();


--
-- Name: expense_shares fk_rails_0387bff53a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_shares
    ADD CONSTRAINT fk_rails_0387bff53a FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: expenses fk_rails_055d529e26; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT fk_rails_055d529e26 FOREIGN KEY (voided_by_user_id) REFERENCES public.users(id);


--
-- Name: payments fk_rails_091d7ed4b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_091d7ed4b5 FOREIGN KEY (cancelled_by_user_id) REFERENCES public.users(id);


--
-- Name: financial_command_receipts fk_rails_35500df921; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_command_receipts
    ADD CONSTRAINT fk_rails_35500df921 FOREIGN KEY (expense_id) REFERENCES public.expenses(id);


--
-- Name: payments fk_rails_59e66e9b2e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_59e66e9b2e FOREIGN KEY (from_user_id) REFERENCES public.users(id);


--
-- Name: payments fk_rails_642144a4ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_642144a4ff FOREIGN KEY (reported_by_user_id) REFERENCES public.users(id);


--
-- Name: expense_description_revisions fk_rails_64c01e6603; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_description_revisions
    ADD CONSTRAINT fk_rails_64c01e6603 FOREIGN KEY (actor_user_id) REFERENCES public.users(id);


--
-- Name: expenses fk_rails_659d0f5465; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT fk_rails_659d0f5465 FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: payments fk_rails_7708d7cda2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_7708d7cda2 FOREIGN KEY (confirmed_by_user_id) REFERENCES public.users(id);


--
-- Name: expenses fk_rails_812c7bde5c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT fk_rails_812c7bde5c FOREIGN KEY (paid_by_user_id) REFERENCES public.users(id);


--
-- Name: financial_command_receipts fk_rails_91b374bc21; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_command_receipts
    ADD CONSTRAINT fk_rails_91b374bc21 FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: payments fk_rails_96e5ce2596; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_96e5ce2596 FOREIGN KEY (to_user_id) REFERENCES public.users(id);


--
-- Name: memberships fk_rails_99326fb65d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_99326fb65d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: expenses fk_rails_9c619cf8aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT fk_rails_9c619cf8aa FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: memberships fk_rails_aaf389f138; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_aaf389f138 FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: expenses fk_rails_bb6f0ceaa9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT fk_rails_bb6f0ceaa9 FOREIGN KEY (replaces_expense_id) REFERENCES public.expenses(id);


--
-- Name: expense_shares fk_rails_d579d2fb80; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_shares
    ADD CONSTRAINT fk_rails_d579d2fb80 FOREIGN KEY (expense_id) REFERENCES public.expenses(id);


--
-- Name: expense_description_revisions fk_rails_d5bff462c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_description_revisions
    ADD CONSTRAINT fk_rails_d5bff462c0 FOREIGN KEY (expense_id) REFERENCES public.expenses(id);


--
-- Name: payments fk_rails_e5637bab11; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_e5637bab11 FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260803170000'),
('20260802150000'),
('20260727120000'),
('20260721165000'),
('20260721161000'),
('20260721160000'),
('20260716180000');
