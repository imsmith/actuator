# Actuator — Product Requirements Document

Release 1: detection-to-containment for a first design partner.

| | |
|---|---|
| Status | Draft 0.1, 2026-11-16 |
| Owner | Ian Smith |
| Derives from | [mrd.md](mrd.md), requirements MR-01..MR-20 |
| Scope | What Release 1 does and how its success is tested. Not an implementation plan. |

## 1. Release 1 in one paragraph

A SIEM or SOAR posts a detection to a transducer's listener. The transducer's workflow, a Colored Petri Net authored and approved ahead of time by the network team, runs steps against enforcement points through their own OpenAPI-described APIs. Every step that tightens access has a declared inverse, so the containment either lands completely or is compensated back to where it started. Every step is checked against the detection's declared scope before it is called. Every token, firing and API exchange goes into a hash-chained journal that produces the incident timeline and the MTTI figure. Relaxing access never happens on a single signal.

## 2. Goals and non-goals

### 2.1 Goals

- **G1.** A design partner runs one real containment end to end (detection in, enforcement point changed, confirmed, journaled) with no human in the path.
- **G2.** Every Must requirement in the MRD (MR-01..06, 08..12, 14, 15) is met and shown by an executable scenario.
- **G3.** MTTI is reported per transducer from the journal, with no manual assembly.
- **G4.** The network team can review, dry-run and approve a workflow without reading Elixir.

### 2.2 Non-goals for Release 1

- **Detection.** Actuator never decides whether something is malicious. It acts on detections it is given.
- **Vendor connectors.** No vendor-specific code. If an enforcement point has no usable OpenAPI document, the partner supplies or writes one.
- **Multi-tenant, multi-user RBAC.** Release 1 has named principals with two roles (§8). Full RBAC comes later.
- **The actuator-agent** installed on hosts. Release 1 drives third-party APIs only.
- **Clustering and HA.** Single node, SQLite. Durability comes from the journal and restart recovery, not from replicas.
- **Automated relaxation.** Release 1 implements the corroboration gate (PR-07), but relaxation always ends in a human approval. Corroboration-only relaxation is Release 2.
- **Graduated containment modes (MR-18), emergency lockdown (MR-07), agent workloads (MR-20).** Release 2.

## 3. Ubiquitous language

One term per concept, used the same way in UI, API, docs and code. Where the code uses a different name today, the code moves to the term below.

| Term | Meaning | Code today |
|---|---|---|
| **Detection** | An inbound message from a SIEM/SOAR asserting that something needs containing. Has a source, a detection id, a subject, and a payload. | listener request body |
| **Detection id** | The source's own identifier for the detection (incident id, alert id). The idempotency key. | none |
| **Subject** | What the detection is about: one or more of workload, network segment, account, identity. | none |
| **Transducer** | The deployable package: a listener, a workflow, its bindings, and its scope policy. One per containment pattern. | `Transducer` |
| **Listener** | The HTTPS endpoint `POST /t/<transducer>` that accepts detections. | `ListenerSpec`, controller |
| **Workflow** | The Colored Petri Net that sequences a transducer's steps. Owns ordering and atomicity. | definition `source` |
| **Step** | A transition bound to an operation. Firing it calls the enforcement point. | `Binding` |
| **Function** | A transition whose body is a rule, not an API call. Decides, does not act. Rules cannot escape their function. | not built |
| **Enforcement point** | A firewall, cloud network controller, DNS resolver, proxy, or any API that changes what traffic is allowed. Described by an API spec. | `ApiSpec` |
| **Operation** | One OpenAPI operation on an enforcement point. | operation in `ApiSpec` |
| **Effect** | A step's declared direction: `tighten`, `relax`, `observe`. Declared by the author, approved by the gatekeeper. | none |
| **Inverse** | The operation that undoes a `tighten` step, with how to derive its request from the step's response. | none |
| **Compensation** | Firing the inverses of completed steps, in reverse order, when a run cannot complete. | none |
| **Scope** | The bound a transducer may act within, expressed as selectors over subjects (which accounts, segments, workloads). A step whose target falls outside is refused. | none |
| **Run** | Everything that happens for one detection id in one transducer, from acceptance to a terminal state. | none |
| **Terminal state** | One of `contained`, `compensated`, `failed`, `rejected`, `pending_approval`. | none |
| **Confirmation** | An `observe` step that reads the enforcement point back and proves the change is in effect. Ends the MTTI clock. | none |
| **Journal** | The append-only, hash-chained record of every run event. | in-memory journal events |
| **MTTI** | Mean time to isolate: detection accepted to confirmation, averaged over `contained` runs. | none |
| **Corroboration** | Independent signals that must agree before a `relax` step may proceed. | none |
| **Dry run** | Executing a workflow against a detection with every operation answered from recorded or declared responses, nothing sent. | none |
| **Author / Approver** | The two Release 1 roles. Authors write workflows, approvers enable them. The same person cannot do both for one version. | single admin |

"Containment", "playbook", "action" and "rule" are not used for product objects. "Containment" describes the outcome, a `contained` run.

## 4. Bounded contexts

```text
   SIEM / SOAR
       |  detection (HTTPS)
       v
+-------------+     +----------------+     +------------------+
|   Intake    | --> |   Execution    | --> | Enforcement edge |--> enforcement point APIs
| listener,   |     | workflow runs, |     | operation calls, |
| auth, schema|     | compensation,  |     | scope check,     |
| idempotency |     | approvals      |     | secrets at call  |
+-------------+     +----------------+     +------------------+
       |                   |                        |
       +-------------------+------------------------+
                           v
                   +---------------+        +--------------------+
                   |   Evidence    |        |     Authoring      |
                   | journal, MTTI,|        | workflows, specs,  |
                   | export        |        | bindings, scope,   |
                   +---------------+        | dry run, approval  |
                                            +--------------------+
```

- **Intake** accepts or rejects a detection and hands Execution a token. It knows nothing about enforcement points.
- **Execution** owns the run's state and the decision to compensate. It knows steps and effects but not HTTP.
- **Enforcement edge** turns a step into an HTTP call. It owns scope checking, secrets resolution, timeouts and retries. It is the only context that talks to the outside.
- **Authoring** owns versions of transducers. Execution only ever runs an approved version.
- **Evidence** is written to by all four and read by none of them during a run. It never blocks enforcement. If it cannot write, it halts new runs rather than run unrecorded (PR-08).

## 5. Users and jobs

| Persona (MRD §7) | Job in Release 1 | Requirements |
|---|---|---|
| Gatekeeper, network lead | Author or review a workflow for their gear, declare effects and inverses, set scope, dry-run, approve | PR-02, 04, 05, 10, 13 |
| Operator, SOC analyst | Wire the SIEM to the listener; watch runs; approve relaxations | PR-01, 07, 12 |
| Champion, security lead | Read MTTI and coverage | PR-09 |
| Auditor | Export a run's timeline and verify it was not altered | PR-08 |
| Economic buyer, CISO | Consume PR-09 output in board and insurer reporting | PR-09 |

## 6. Functional requirements

Each requirement lists the MRD requirement it answers, what it does, and its acceptance scenarios. Scenarios use the language in §3.

### PR-01 Authenticated detection intake — MR-01, MR-17

The listener accepts a detection only with a credential issued for that transducer, and only if the body validates against the transducer's declared detection schema. Accepted detections get `202` and a run id. Rejected ones get `401` or `422` with the validation errors and are journaled as `rejected`. The listener has a bounded request size and a bounded per-transducer queue. A full queue returns `503` with `Retry-After` and never drops silently.

```gherkin
Feature: Detection intake

  Scenario: Accept a valid detection
    Given an approved transducer "egress-isolate" with a detection schema
    And a listener credential issued for "egress-isolate"
    When a detection that matches the schema is posted with that credential
    Then the response status is 202
    And the response contains a run id
    And the journal records the run as accepted

  Scenario: Reject a detection that fails the schema
    Given an approved transducer "egress-isolate" with a detection schema
    When a detection missing its subject is posted
    Then the response status is 422
    And the response lists the schema violations
    And no step is fired

  Scenario: Reject a credential issued for another transducer
    Given a listener credential issued for "dns-sinkhole"
    When a detection is posted to "egress-isolate" with that credential
    Then the response status is 401
```

### PR-02 OpenAPI-defined steps, no vendor code — MR-02

Any operation in a stored API spec can be bound to a transition as a step. The step's request is built from the consumed token by a declared mapping, and the response is merged into the produced token. Adding an enforcement point means storing its spec and binding steps, with no code change and no restart of other transducers. *Exists today, except for the declared request mapping. Today the whole token is the request.*

```gherkin
Feature: Steps bound to enforcement point operations

  Scenario: A new enforcement point without a code change
    Given an API spec for an enforcement point that Actuator has never driven
    When an author binds a step in a draft workflow to one of its operations
    And an approver enables the workflow
    Then a detection causes that operation to be called with the mapped request
```

### PR-03 Atomic runs with compensation — MR-03, MR-04, MR-12

A run either reaches `contained` or every completed `tighten` step is compensated in reverse order and the run ends `compensated`. If an inverse itself fails, the run ends `failed`, the journal names the steps left in effect, and the operator is notified. A run never ends with an unrecorded partial change. Every step has a timeout and a bounded retry count, both declared, and nothing waits indefinitely.

Depends on compensation in `cpn-spec 1.1` (§10, D1).

```gherkin
Feature: Atomic containment

  Scenario: All steps succeed
    Given a workflow with tighten steps "block-egress" then "sinkhole-dns" then confirmation "verify-block"
    When a detection is accepted
    Then all three steps fire in order
    And the run ends contained

  Scenario: A later step fails and earlier steps are compensated
    Given a workflow with tighten steps "block-egress" then "sinkhole-dns"
    And the enforcement point for "sinkhole-dns" returns an error
    When a detection is accepted
    Then the inverse of "block-egress" fires
    And the run ends compensated
    And the journal shows no step left in effect

  Scenario: An inverse fails
    Given a run in which "block-egress" succeeded and "sinkhole-dns" failed
    And the inverse of "block-egress" times out after its declared retries
    Then the run ends failed
    And the journal names "block-egress" as left in effect
    And the operator is notified
```

### PR-04 No tighten step without an inverse — MR-04

A workflow cannot be approved if any `tighten` step lacks a declared inverse. This is enforced at approval, not at run time. It is Breach Lock rule R-04 made mechanical: no change goes live without its rollback.

```gherkin
Feature: Reversibility enforced at approval

  Scenario: Refuse approval of an irreversible workflow
    Given a draft workflow with a tighten step that declares no inverse
    When an approver tries to enable it
    Then approval is refused
    And the refusal names the step without an inverse
```

### PR-05 Scope enforcement — MR-05

Every transducer declares a scope. Before the enforcement edge sends a step's request, it resolves the step's target from the request and refuses the call if the target is outside both the transducer's scope and the detection's subject. A refused step fails the run, which triggers compensation. Scope is checked at the edge on every call, not once per run.

```gherkin
Feature: Scope enforcement

  Scenario: Refuse a step whose target is outside scope
    Given transducer "egress-isolate" is scoped to account "prod-payments"
    And a detection whose subject is a workload in account "prod-ledger"
    When the step "block-egress" would target account "prod-ledger"
    Then the call is not sent
    And the run ends compensated
    And the journal records a scope refusal

  Scenario: Allow a step inside scope
    Given transducer "egress-isolate" is scoped to account "prod-payments"
    And a detection whose subject is workload "build-07" in account "prod-payments"
    When the step "block-egress" targets workload "build-07"
    Then the call is sent
```

### PR-06 Idempotent detections — MR-15

A detection whose detection id already has a run in the same transducer within the dedupe window gets `200` and the existing run id, and starts nothing. The window is declared per transducer.

```gherkin
Feature: Duplicate detections

  Scenario: A SIEM re-fires the same incident
    Given a run exists for detection id "INC-4471" in "egress-isolate"
    When a detection with id "INC-4471" is posted to "egress-isolate" within the dedupe window
    Then the response status is 200
    And the response contains the existing run id
    And no step is fired
```

### PR-07 Tighten freely, relax on corroboration and approval — MR-06

Steps with effect `tighten` or `observe` fire without approval. A run that reaches a `relax` step pauses in `pending_approval` until two conditions hold: at least N independent corroborating sources (N declared per transducer, minimum 2) have posted agreeing signals, and an approver approves. A source is independent if it has a distinct listener credential. Two posts from one SIEM count once. Pending relaxations expire after a declared time and end `rejected`.

```gherkin
Feature: Asymmetric automation

  Scenario: Tightening needs no approval
    Given a workflow whose only effects are tighten and observe
    When a detection is accepted
    Then the run reaches contained without any approval

  Scenario: Relaxing waits for corroboration and approval
    Given a transducer requiring 2 corroborating sources for relax steps
    And a run paused at relax step "restore-egress"
    When one source posts a corroborating signal
    And an approver approves
    Then "restore-egress" does not fire

  Scenario: Relaxing proceeds when both conditions hold
    Given a transducer requiring 2 corroborating sources for relax steps
    And a run paused at relax step "restore-egress"
    When two independent sources post corroborating signals
    And an approver approves
    Then "restore-egress" fires
```

### PR-08 Hash-chained journal and export — MR-08

Every run event is appended to the journal in SQLite before the next event in that run proceeds: acceptance, token placement, firing, request, response, compensation, refusal, approval, terminal state. Each entry carries the hash of the previous entry. Request and response bodies are stored, credentials are not. Export produces one run's or one time window's entries, with a verifier that recomputes the chain. If the journal cannot be written, the listener returns `503` and no new run starts.

```gherkin
Feature: Evidence journal

  Scenario: Export a verifiable run timeline
    Given a contained run for detection id "INC-4471"
    When an auditor exports the run
    Then the export contains every step's request, response and timestamp
    And the chain verifier reports the export intact

  Scenario: Detect an altered entry
    Given an exported run
    When any entry in the export is changed
    Then the chain verifier reports the export altered at that entry

  Scenario: No credentials in the journal
    Given an API spec whose credential is resolved from the secrets broker
    When a step on that enforcement point fires
    Then the journal entry for the request contains no credential value
```

### PR-09 MTTI and coverage reporting — MR-09

MTTI per transducer and per detection class, computed from the journal as the time from acceptance to the first successful confirmation step, over `contained` runs. A transducer with no confirmation step reports no MTTI and says why. Also reported per transducer: run counts by terminal state, and the p50 and p95 of time to isolate. Available in the admin UI and as JSON.

```gherkin
Feature: Mean time to isolate

  Scenario: Report MTTI from confirmed runs
    Given three contained runs with times to isolate of 40, 60 and 80 seconds
    When the MTTI for the transducer is requested
    Then the MTTI is 60 seconds

  Scenario: No confirmation step, no MTTI
    Given a transducer whose workflow has no confirmation step
    When the MTTI for the transducer is requested
    Then no MTTI is reported
    And the reason given is the missing confirmation step
```

### PR-10 Dry run — MR-11

An author or approver runs any workflow version against a sample detection with no operation sent. Each operation answers from a declared or recorded response. The result shows every step that would fire, its rendered request, its target, the scope verdict, and the compensation path if a chosen step is made to fail. Approval of a version requires at least one recorded dry run of that version.

```gherkin
Feature: Dry run before approval

  Scenario: Preview a workflow's effect
    Given a draft workflow and a sample detection
    When an author dry-runs the workflow
    Then the result lists each step that would fire with its request and target
    And no request is sent to any enforcement point

  Scenario: Preview compensation
    Given a draft workflow and a sample detection
    When an author dry-runs it with step "sinkhole-dns" set to fail
    Then the result shows the inverse of each earlier tighten step

  Scenario: Approval requires a dry run
    Given a draft workflow version with no recorded dry run
    When an approver tries to enable it
    Then approval is refused
```

### PR-11 Independence from detection sources — MR-10

Nothing on the run path calls the SIEM, SOAR or IdP. Once a detection is accepted, the run completes or compensates even if every detection source is down. Notifications to the operator are fire-and-forget and never block a run.

```gherkin
Feature: Independence from detection sources

  Scenario: The SIEM goes down mid-run
    Given a run that has been accepted
    When the SIEM that posted it becomes unreachable
    Then the run still reaches a terminal state
```

### PR-12 Run visibility for operators

The admin UI lists runs with live state, the current marking, the step in flight, pending approvals and terminal states. A run links to its journal entries. *Partly exists: live markings and journal events per transducer.*

### PR-13 Versioned authoring with separation of duties — MR-13, MR-16

Transducers are versioned. Editing creates a draft and never touches the running version. Enabling a version requires an approver who is not its author, a recorded dry run (PR-10), and passing scenarios if the version ships any (MR-16, Should). Swapping versions lets in-flight runs finish on the old version: new detections go to the new one, and the old one stops when it is quiescent.

```gherkin
Feature: Versioned authoring

  Scenario: Edit without disturbing in-flight runs
    Given version 3 of "egress-isolate" is enabled and has a run in flight
    When version 4 is approved and enabled
    Then the in-flight run completes on version 3
    And new detections run on version 4

  Scenario: Separation of duties
    Given a draft version authored by "alice"
    When "alice" tries to approve it
    Then approval is refused
```

### PR-14 Credentials resolved at call time — MR-14

API specs reference a secret by name. The enforcement edge resolves it from the secrets broker (`Comn.Secrets`) for each call and never writes it to the database, the journal, logs or telemetry.

```gherkin
Feature: Credentials out of the store

  Scenario: Store a spec without a credential value
    Given an API spec whose authentication references secret "fw-prod-token"
    Then the stored spec contains the reference and not the value
```

## 7. Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-01 | **Overhead budget.** Actuator's own time from acceptance to first step sent is under 250 ms at p95 on the reference node, excluding enforcement point latency. Measured from the journal. |
| NFR-02 | **Bounded everything.** Every outbound call has a timeout. Every retry loop has a declared maximum. Every queue has a capacity. Every request body has a size limit. No unbounded loop on the run path. |
| NFR-03 | **Restart recovery.** After a crash, every run not in a terminal state is resumed from the journal or compensated. No run is lost silently. |
| NFR-04 | **Single node.** One OTP release, SQLite, no external database or broker. Alpine-based container image, run under Podman. |
| NFR-05 | **Transport.** TLS on the listener. Outbound TLS verification is on and cannot be turned off per spec in production builds. |
| NFR-06 | **Telemetry.** `:telemetry` events for accepted, rejected, fired, failed, compensated, contained, approval-pending, journal-write-failed. |
| NFR-07 | **Licensing.** AGPL-3.0-only. SPDX SBOM produced on every release. |

## 8. Roles and authentication in Release 1

- **Listener credentials.** One or more per transducer. Each identifies a detection source, which is how corroboration independence is counted.
- **Principals.** Named admin-UI users with roles `author`, `approver` or both. An approver cannot approve their own version.
- The prototype's single shared token is retired.

## 9. Release slicing

Each slice ships alone, behind the previous one. The order puts the items most likely to block a design partner first.

| Slice | Contents | Why here |
|---|---|---|
| S1 | PR-14 credentials, PR-01 per-transducer credentials and schema validation | A partner will not hand over firewall credentials stored in plaintext |
| S2 | PR-08 journal (hash chain, persistence), NFR-03 restart recovery | Everything after this needs the journal as its record |
| S3 | PR-03 and PR-04 compensation and inverses | Needs `cpn-spec 1.1`. This is the product's core claim. |
| S4 | PR-05 scope, PR-06 idempotency | Makes automated firing safe to enable |
| S5 | PR-10 dry run, PR-13 versioning and approval | What the gatekeeper signs off with |
| S6 | PR-07 relax gate, PR-09 MTTI, PR-12 run views | Completes the loop and the reporting |

## 10. Decisions needed

| ID | Decision | Options | Blocks |
|---|---|---|---|
| D1 | Compensation in the workflow language | (a) `cpn-spec 1.1` adds per-transition `compensate` arcs. (b) Compensation is a convention: the inverse is just another step, and the net routes to it on failure. (b) needs no spec change but puts correctness on every author. | S3 |
| D2 | Request mapping syntax for steps (PR-02) | Expression language in `cpn-spec 1.1` arc inscriptions, or a separate mapping declared on the binding | S3 |
| D3 | Detection schema language (PR-01) | YANG via `ex_yang` (matches README intent), or JSON Schema (what SIEMs already emit). YANG is consistent with the rest of the model. | S1 |
| D4 | Function bodies | Anemos rules inside function transitions per the engine model. Not needed for Release 1 if relaxation is human-approved. | Release 2 |
| D5 | First enforcement points for the design partner | Which two APIs? The pair determines whether their OpenAPI documents are good enough to bind as-is. | G1 |
| D6 | Scope selector model (PR-05) | How targets are resolved from a request: declared JSONPath per operation, or tags on the spec's parameters | S4 |
| D7 | Detection source for the design partner | Sentinel (the author's existing connector work) or another; it fixes the first detection schema | S1, G1 |

## 11. Release 1 acceptance

Release 1 is done when all of the following hold:

1. Every scenario in §6 passes, run by a real Gherkin runner against Req stubs in CI.
2. One design-partner containment has run against real enforcement points. It produced a `contained` run with a confirmation step, an exported journal that verifies, and an MTTI figure.
3. One forced failure on the same workflow produced a `compensated` run with nothing left in effect.
4. `mix precommit` and `mix quality` are clean.
