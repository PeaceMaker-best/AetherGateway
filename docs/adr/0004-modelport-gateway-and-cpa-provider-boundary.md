# ADR-0004: ModelDock Gateway And CPA Provider Boundary

- Status: Accepted
- Date: 2026-07-27

## Context

Some deployments need to use Codex and Claude Code OAuth accounts through
CLIProxyAPI, commonly abbreviated CPA. ModelDock already owns the client API,
authentication, model resolution, smart routing, policy, quota, fallback,
health, accounting, and operational evidence.

Putting CPA or LiteLLM in front of ModelDock, or treating several gateways as
equal control planes, would create ambiguous ownership. Retries could multiply,
health and quota decisions could disagree, credentials could cross trust
boundaries, and no single ledger would explain a client request.

CPA still provides useful account-specific behavior: OAuth lifecycle,
multi-account credential selection, and protocol translation for Codex and
Claude accounts.

## Decision

ModelDock remains the only client-facing gateway and the source of truth for
policy, routing, retry/fallback, quota, health, and request evidence.

CPA is optional and appears only as two internal ModelDock Providers:

- `cpa_codex` uses the OpenAI-compatible client API with a Base URL ending in
  `/v1`;
- `cpa_claude` uses the Anthropic client API with a Base URL that omits `/v1`;
- both may query CPA's shared OpenAI-compatible `GET /v1/models` catalog;
- both may authenticate with the same CPA client API key, but configuration,
  health, routing, model allowlists, and evidence remain separate.

ModelDock stores only CPA's client key. CPA owns OAuth tokens, auth files,
account cooldown, and bounded credential selection. CPA's management API is
not a ModelDock Provider endpoint and is not integrated into the ModelDock
control plane.

CPA Providers require explicit model allowlists. Unknown-model passthrough and
model-prefix ownership are rejected. Operators use Provider-qualified names
during acceptance and whenever model IDs overlap another Provider.

CPA may use plaintext HTTP only on a trusted local transport: loopback, a
single-label private service name, or `host.docker.internal`. Public hostnames
still require HTTPS. CPA is not exposed to application clients.

ModelDock owns request-level retry and cross-Provider fallback. CPA starts with
request retries disabled and credential retries bounded so a single recorded
ModelDock attempt cannot silently fan out without a reviewed operational
limit.

LiteLLM is not a runtime dependency or deployment component. Provider
abstraction, normalized error, routing, budget, and observability ideas may be
evaluated independently and reimplemented only when they fit ModelDock's typed
and auditable contracts.

## Consequences

- Applications keep one ModelDock endpoint and one scoped client credential.
- Provider health and request evidence distinguish CPA Codex from CPA Claude.
- CPA can evolve or be removed without changing the public ModelDock API.
- CPA account-level attempts are not currently first-class ModelDock ledger
  rows; CPA retry bounds are therefore an operational contract.
- CPA model discovery proves catalog visibility, not account entitlement or
  protocol compatibility.
- Adding CPA to smart routing requires the same non-stream, stream, Tool Use,
  error, cost, and billing-evidence acceptance as any other Provider.

## Rejected Alternatives

- CPA in front of ModelDock: bypasses ModelDock's client governance and makes
  ModelDock an upstream implementation detail.
- ModelDock and CPA as equal public gateways: creates two policy, credential,
  retry, and evidence surfaces.
- Generic `cpa` Provider: mixes protocols and account health into one
  operational identity.
- LiteLLM as an additional runtime hop: adds another router and translation
  boundary without a required capability.
- Unbounded CPA credential traversal: makes one ModelDock attempt have
  unbounded latency and upstream billing exposure.
