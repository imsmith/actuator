# Issues

Known shortcuts and open work. Each entry names the ceiling and the upgrade
path. Remove the entry when the shortcut is gone.

## Shortcuts

### Instance restart drops in-flight tokens

`Actuator.Transducers.Instances.restart/1` stops and starts the `ExCpn.Instance`
on every definition update. Any tokens in the marking are lost. Fine while a
transducer is pass-through; wrong once an action is mid-flight.
Upgrade: drain to quiescence before stopping, or carry the marking across when
the place set is unchanged.

### `Instances.stop/1` depends on Registry internals

To return only after the name is unregistered, `stop/1` makes a call to the
Registry's partition process by its internal name `<registry>.PIDPartition0`.
Works with the default single partition. Upgrade: track liveness ourselves
(monitor from the caller) instead of relying on Registry cleanup ordering.

### One shared bearer token

`ActuatorWeb.Plugs.ApiAuth` compares every request against the single
`:api_token`. Prototype assumption: the only user is the admin. Upgrade:
per-transducer tokens stored with the definition, then real principals.

### Listener token is the raw JSON body

`POST /t/:name` puts the whole body on the entry place with no schema check.
The place's YANG type is recorded but not enforced. Upgrade: validate the body
against the YANG type via `ex_yang` before accepting.

### API spec `auth_header` is stored in plaintext

`Actuator.ApiSpecs.ApiSpec.auth_header` holds a live credential in the SQLite
row, redacted from inspect but not encrypted. Prototype only. Upgrade: reference
a secret through the credentials broker (`Comn.Secrets`) and resolve at call
time.

### Deleting an API spec silently drops its bindings

`bindings.api_spec_id` is `on_delete: :delete_all`, and the affected
transducers are not restarted, so their running instances keep the old action
until the next sync. Upgrade: restrict the delete while bindings exist, or
restart affected transducers.

### Action response fan-out is uniform

`Actuator.Transducers.Action` produces the same token (input merged with
`status` and `response`) for every out place of the bound transition. The net
cannot route on the response yet. Upgrade: `local` guards on downstream
transitions already can read `$tok(status)`; a per-arc expression language in
`cpn-spec 1.1` would let the transition itself choose.

### CSP allows inline scripts

The browser pipeline sends a Content-Security-Policy, but `script-src` includes
`'unsafe-inline'` because the scaffold's root layout bootstraps the colour
theme with an inline script before first paint. Upgrade: a per-request nonce
via `put_secure_browser_headers` and `csp_nonce` on that one script.

### `core_components.ex` still uses daisyUI

The project rule is hand-written Tailwind, no daisyUI. The admin chrome and
the transducer, API spec, and listener pages use plain Tailwind now, but the
scaffold's `core_components.ex` (`<.button>`, `<.input>`, `<.table>`,
`<.header>`, flash) still carries daisyUI classes, so the plugin stays in
`app.css`. Upgrade: rewrite those components in Tailwind and drop the plugin
and the `daisyui` dep. `priv/static`'s Phoenix logo and the unused
`page_html/home.html.heex` go with it.

## PRD deviations

Where the code as written differs from [docs/prd.md](docs/prd.md). Each entry
names the deviation, why it exists, and the verdict: **rewrite** (the code
moves to the PRD) or **requirement** (the PRD is wrong or incomplete and
should change). Entries that are also shortcuts above are cross-referenced,
not repeated. The lens: a transducer is an HTTP API for one thing. Each
request is processed and answered on its own, as in any web server. Any
coupling between requests is written into the net by its author. The journal
is the record of what each request did.

### Listener returns no run id and does no intake checks

`TransducerController.actuate/2` replies `202 {status, transducer, place}`.
The web-server part of PR-01 is plain intake and stands: `422` on schema
violation, `401` per caller credential, `503` with `Retry-After` on a full
mailbox, a bounded body size. Verdict: **rewrite**, after D3. The code's
`404` for a transducer that is not running is right and missing from PR-01.
Verdict: **requirement**, add it. The rest of PR-01 and PR-06 assume a
run object: a run id in the reply, `200` with the existing run id on a
duplicate detection id. There is no run. The request is the unit, `202` is
its answer, and the journal entries carrying its detection id are its
history. Dedupe is either the thing's own idempotency (set lamp on twice is
one state) or a place in the net the author adds. Verdict: **requirement**,
drop the run id from PR-01 and either drop PR-06 or restate it as a net
pattern.

### One shared bearer token

See the shortcut above. PR-01 and §8 require a credential per caller per
transducer. Verdict: **rewrite**. PR-07 counts corroboration by distinct
callers, and corroboration is a join written in the net, so the listener
must also stamp the authenticated caller onto the request it enqueues or the
net has nothing to join on. Same rewrite, one more field.

### Admin is one HTTP basic user

`Router` guards `/admin` with `Plug.BasicAuth` and the same `:api_token`.
PRD §8 needs named principals with `author` and `approver` roles so PR-13 can
refuse self-approval. Why: "the only user of the multi-user system is the
admin" was the stated prototype assumption. Verdict: **rewrite**. Note the
review finding that run-time relax approval (PR-07) and version approval
(PR-13) are different authorities sharing the name `approver`; settle that
in the PRD before building roles.

### Transducers are enabled on create, no versions, no approval

`Transducer` has `enabled: true` by default and `Transducers.update/2`
rewrites the live definition in place. PR-13 wants versions, a draft that
never touches the running version, and enabling gated on an approver, a
recorded dry run (PR-10) and reversibility (PR-04). Why: a single mutable row
was enough to iterate on the lamp. Verdict: **rewrite**. Default to disabled,
add a versions table, and make `enabled` the result of approval rather than
a checkbox. PR-13's "old version finishes its in-flight runs" is a graceful
restart: stop accepting, let the marking drain, swap. Bandit does the same
for connections. "Instance restart drops in-flight tokens" above is the
runtime side of that.

### Bindings carry no effect, inverse, or scope

`Binding` is transition, api spec, operation id. Per-row and per-operation
facts belong here and are missing: PR-04's `effect` (`tighten`, `relax`,
`observe`) and the inverse operation for a `tighten`, PR-05's scope (which
subjects this row may touch) and the rule for reading a step's target out of
its request (D6). Verdict: **rewrite** (additive), after D1 and D6. Not
here: PR-07's `N` and expiry and PR-06's dedupe window. Those describe how
requests combine, which is the net's job, not a config column. Verdict:
**requirement**, move them into the net (expiry needs D1's timed
transitions).

### Request is the whole token, response fan-out is uniform

`Action.perform/4` sends the consumed token as the request and merges
`status` and `response` into every out place (see "Action response fan-out
is uniform"). PR-02 acknowledges this and defers the request mapping to D2.
What the PRD misses: the **Confirmation** step (§3, PR-09) must judge
whether the readback proves the change, which is a predicate on the
response, and D2 only covers request mapping. Verdict: **requirement** for
D2 (add response predicates), then **rewrite** once `cpn-spec 1.1` settles
the expression language.

### Timeouts and retries are implicit and global

`Action` passes `retry: false` and inherits Req's default receive timeout;
`ExCpn.Instance` has one `max_retries` per instance. PR-03 and NFR-02 want a
declared timeout and retry budget on every step. A step is one HTTP call to
the thing, so its timeout and retry budget are properties of the binding,
not of the net. Verdict: **rewrite**, now: two columns on `Binding`, passed
to Req as `receive_timeout` and `retry`. No `cpn-spec 1.1` dependency. D1
is only needed for net-level time (corroboration expiry).

### Credential in the row, not the broker

See "API spec `auth_header` is stored in plaintext". PR-14 names
`Comn.Secrets`, which exists in the comn dependency. Verdict: **rewrite**;
the spec stores a secret name, `Action.auth/1` resolves it per call.

### Journal is in-memory telemetry

`Instances.start/1` wires the `ExCpn.Instance` journal to
`Telemetry.journal/2` and a PubSub broadcast for the admin page. Nothing is
written to SQLite, nothing is hash-chained, and the `{:fired, transition,
binding, marking}` event carries no request or response body, so even a
persisted copy would not satisfy PR-08. Under this lens the journal is the
only record of what a request did, so it carries more weight, not less.
Verdict: **rewrite**. `Action` must emit request and response events itself,
since ex_cpn does not see HTTP, and each entry must carry the detection id
from the request. One point the PRD must fix first: §4 says Evidence never
blocks enforcement while PR-08 and PR-03 require synchronous writes. Web
servers log asynchronously and alarm on failure; the PRD can choose that or
synchronous, but must choose.

### Deleting an API spec changes a running transducer

See the shortcut above. PRD §4 says Execution only runs an approved version,
which implies the version pins the specs and bindings it was approved with.
The PRD does not say so. Verdict: **requirement**, state that an approved
version is immutable including its api specs; then **rewrite** the delete
to restrict while any version references the spec.

### Outbound TLS can be relaxed by configuration

`Action` merges `Application.get_env(:actuator, :req_options)` into every
request. It exists so tests can plug `Req.Test`, but in prod it can also
disable TLS verification, which NFR-05 forbids. Verdict: **rewrite**, small:
restrict the override to test, or whitelist the keys it may set.

### Telemetry events

`Telemetry` emits fired, failed, accepted, rejected. NFR-06 adds
compensated, contained, approval-pending, journal-write-failed. Contained,
compensated, and approval-pending are places a request reaches in the net,
and the fired event already names the transition that got it there.
Verdict: **requirement**, express those three as "request reached place X"
over existing events; journal-write-failed is new and is a **rewrite** with
the journal.

## Open

- Hierarchical nets, compensation, timed transitions are not in `cpn-spec 1.0`
  (tracked in `ex_cpn`).
- No audit journal; `ExCpn.Instance` journal events are not persisted.
