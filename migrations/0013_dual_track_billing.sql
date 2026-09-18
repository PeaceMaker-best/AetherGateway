-- Keep operational estimates separate from reconciled and governed charges.
-- Existing cost_amount_microunits remains the estimate column for backward
-- compatible dashboards; neither new column is backfilled from an estimate.
ALTER TABLE aethergateway_gateway_requests
    ADD COLUMN actual_cost_microunits BIGINT,
    ADD COLUMN billable_cost_microunits BIGINT,
    ADD COLUMN pricing_evidence JSONB,
    ADD CONSTRAINT aethergateway_gateway_requests_reconciled_cost_check CHECK (
        (actual_cost_microunits IS NULL OR actual_cost_microunits >= 0)
        AND (billable_cost_microunits IS NULL OR billable_cost_microunits >= 0)
        AND (billable_cost_microunits IS NULL OR pricing_evidence IS NOT NULL)
    );

ALTER TABLE aethergateway_provider_attempts
    ADD COLUMN actual_cost_microunits BIGINT,
    ADD COLUMN billable_cost_microunits BIGINT,
    ADD COLUMN pricing_evidence JSONB,
    ADD CONSTRAINT aethergateway_provider_attempts_reconciled_cost_check CHECK (
        (actual_cost_microunits IS NULL OR actual_cost_microunits >= 0)
        AND (billable_cost_microunits IS NULL OR billable_cost_microunits >= 0)
        AND (billable_cost_microunits IS NULL OR pricing_evidence IS NOT NULL)
    );

CREATE INDEX aethergateway_gateway_requests_billable_created_idx
    ON aethergateway_gateway_requests (created_at DESC, billable_cost_microunits)
    WHERE billable_cost_microunits IS NOT NULL;

CREATE INDEX aethergateway_provider_attempts_unreconciled_idx
    ON aethergateway_provider_attempts (updated_at)
    WHERE state <> 'started' AND actual_cost_microunits IS NULL;
