-- Keep key-scoped spend and rate-limit identity stable across credential
-- rotation while retaining api_key_id as the concrete audit credential.
ALTER TABLE aethergateway_gateway_requests
    ADD COLUMN quota_subject_id TEXT;

UPDATE aethergateway_gateway_requests
SET quota_subject_id = api_key_id
WHERE api_key_id IS NOT NULL;

CREATE INDEX aethergateway_gateway_requests_quota_subject_created_idx
    ON aethergateway_gateway_requests (quota_subject_id, created_at DESC)
    WHERE quota_subject_id IS NOT NULL;
