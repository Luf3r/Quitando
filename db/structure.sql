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
-- Name: payment_command_receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_command_receipts (
    id uuid DEFAULT uuidv7() NOT NULL,
    payment_id uuid NOT NULL,
    command_type character varying NOT NULL,
    idempotency_key uuid NOT NULL,
    request_fingerprint character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT payment_command_receipts_command_type_valid CHECK (((command_type)::text = ANY ((ARRAY['report'::character varying, 'confirm'::character varying, 'cancel'::character varying])::text[])))
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
-- Name: payment_command_receipts payment_command_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_command_receipts
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
-- Name: index_expenses_on_replaces_expense_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expenses_on_replaces_expense_id ON public.expenses USING btree (replaces_expense_id);


--
-- Name: index_expenses_on_voided_by_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expenses_on_voided_by_user_id ON public.expenses USING btree (voided_by_user_id);


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
-- Name: index_payment_command_receipts_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payment_command_receipts_on_idempotency_key ON public.payment_command_receipts USING btree (idempotency_key);


--
-- Name: index_payment_command_receipts_on_payment_id_and_command_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payment_command_receipts_on_payment_id_and_command_type ON public.payment_command_receipts USING btree (payment_id, command_type);


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
-- Name: payment_command_receipts payment_command_receipts_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER payment_command_receipts_append_only BEFORE DELETE OR UPDATE ON public.payment_command_receipts FOR EACH ROW EXECUTE FUNCTION public.prevent_payment_command_receipt_mutation();


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
-- Name: payment_command_receipts fk_rails_91b374bc21; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_command_receipts
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
-- Name: payments fk_rails_e5637bab11; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_e5637bab11 FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260802150000'),
('20260727120000'),
('20260721165000'),
('20260721161000'),
('20260721160000'),
('20260716180000');
