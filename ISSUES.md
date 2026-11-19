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
The entry place's YANG type now resolves to a stored module node, but the
body is not checked against it: `ex_yang` has no RFC 7951 instance validator
yet. Upgrade: when it does, validate the body against the entry place's node
before accepting, and derive the listener spec's request schema from it.

### Place types are only checked when the net imports

`Actuator.YangModules.resolve/1` skips a net with no `yang import` lines, so
the lamp demo's `home:request` passes with nothing stored. Upgrade: once
every net in use imports its modules, make an untyped prefix an error.

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
`app.css`. Upgrade: the design-system pass below replaces them with
`gos-ui` components and drops the plugin and the `daisyui` dep.
`priv/static`'s Phoenix logo and the unused `page_html/home.html.heex` go
with it.

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

## Design system deviations

Where the admin UI differs from the GRID·OPS design system: the
[imsmith/design-system](https://github.com/imsmith/design-system) manual
(meaning) and its `tokens/**/*.edn` (values), condensed for agents in that
repo's `design.md`. The system already has a Phoenix consumer,
[imsmith/gos-ui](https://github.com/imsmith/gos-ui): vendored `styles.css`,
fonts, mark sprite, `GosUi.Tokens`, and HEEx components whose class names
mirror the reference React set. Each entry names the deviation and the
verdict: **adopt** (gos-ui carries it, swap the component in), **rewrite**
(Actuator code changes on its own), or **system** (the system has no answer
yet and should grow one). The lens: the admin UI is an operations console
for the things behind the gateway. Data-legible first; mono is the voice;
status is never color alone; no invented values.

### The stylesheet is Tailwind plus daisyUI, not the system's tokens

`assets/css/app.css` imports Tailwind, the heroicons plugin, and two daisyUI
themes with their own oklch palette. Nothing links `styles.css` or sets
`--bg`, `--surface`, `--accent`, `--font-mono`. Every color in the templates
is a Tailwind name (`zinc-*`, `emerald-*`, `amber-*`, `sky-*`) and every
spacing step a Tailwind step. The contract forbids inventing a value the
system names. Verdict: **adopt**. Add `{:gos_ui, github: "imsmith/gos-ui"}`,
serve its static root at `/gos-ui`, link `styles.css` from the root layout,
put `<.sprite />` once in the layout, register `GosUiHooks`. Keep Tailwind
for layout utilities only, or drop it with daisyUI once nothing uses it. This
closes the "`core_components.ex` still uses daisyUI" shortcut.

### No theme or mode attribute, and the toggle is daisyUI's

`root.html.heex` sets `data-theme` to `light`/`dark` from a daisyUI theme
pair. The system wants `data-theme="tron|matrix|compaq"` on the root and
`data-mode="light"` for light, dark being the default. The dark theme is
never reachable from the admin pages: `theme_toggle/1` is only rendered on
the unused Phoenix welcome page. Verdict: **adopt**. `GosUi.theme_attrs/2`
on `<html>`, `<.theme_switch>` in the shell head, one theme per deployment
chosen in config. The inline theme bootstrap script in `root.html.heex`
goes with it, which also removes the reason the CSP carries
`'unsafe-inline'` for scripts (see the CSP shortcut above).

### Typography is the browser sans, mono only where hand-applied

No font is declared anywhere. Body text falls to Tailwind's default sans,
and `font-mono` is sprinkled on names and paths by hand. The system's
voice is MartianMono Nerd Font for headings, labels, data, and UI, with
Martian Grotesk for long-form prose only. The type scale in use is
Tailwind's (`text-xs`, `text-sm`, `text-lg`, `text-[11px]`, `text-[10px]`),
not the 40→11 modular scale. Verdict: **adopt**. `base.css` sets mono as the
body voice, so most `font-mono` classes become redundant; the UPPERCASE
section headings become `.ds-label`.

### Status is color alone, with Tailwind colors, outside the ramp

`TransducerLive.Index.status_badge/1` and the marking header render
`quiescent` green, `busy` amber, `running` sky, stopped grey, as a pill with
the word inside. The system's hard invariant is color + glyph + text, the
five status steps bound to OASIS CAP, and the five sign-shapes reserved for
them. Pills are reserved for meters and toggles. The instance states are not
severities, so mapping them onto the ramp is also wrong: `running` is not an
alert. Verdict: **rewrite** using `<.tag>` (a chrome-colored chip) for
instance state, with `<.status_badge step={:critical}>` reserved for a
transducer whose instance crashed or whose last action failed. Needs the
instance state to carry that distinction.

### The net diagram uses an ad-hoc categorical palette

`NetDiagram` colors marked places amber, enabled transitions green, bound
transitions sky, and the caption says so in words. Those three are a
categorical palette of unrelated things, which the spectrum rule forbids,
and the legend is prose instead of a glyph. The diagram is also light-only:
`fill-white` places and `zinc` strokes on a dark surface disappear.
Verdict: **rewrite**. Chrome roles for structure (`--text` strokes,
`--surface` fills, `--muted` labels), `--accent` fill with glow for an
enabled transition, an `accent-tint` ring for a bound one, and the token
count as the marking signal, which it already is. Marks from the sprite
instead of the caption. The system has no net or graph component.
Verdict for that: **system**, a "Petri net" or "graph" entry in the
catalog once this is drawn right.

### Tables are three different hand-styled tables

`<.table>` in `core_components.ex` is daisyUI `table table-zebra`. The
transducer show page has two more tables styled with arbitrary-variant
Tailwind selectors. None has a density mode, a caption, or the empty /
loading / error triad; the index pages render a bare `<tbody>` when there
are no rows. Verdict: **adopt** `GosUi.Components.table/1` with
`density={:compact}` for the index pages and `:dense` for the marking and
bindings tables, `<.state_panel>` for the empty row. gos-ui's table takes a
list of rows and puts `:rest` on `<table>`, so it cannot host a
`LiveStream`. The index pages are small enough to pass lists; stream
support in gos-ui's table (an id and `phx-update` on `tbody`) is
**system**.

### Forms are daisyUI fieldsets, not the form pattern

`<.input>` wraps everything in daisyUI `fieldset`/`label`/`input` classes,
errors are a red line with a heroicon, and the source textarea gets a
hand-written Tailwind class that overrides the component. The pattern is a
single column at the prose measure, inline error state (critical border +
`m-critical` + message), primary + ghost actions bottom-right, primary in
loading state with `aria-busy` on submit. Verdict: **adopt** `<.input>`,
`<.textarea>`, `<.checkbox>`, `<.fieldset>` from gos-ui and `<.button
variant={:ghost}>` for Cancel.

### File drop is hand-built against a catalog entry

`file_drop/1` in `core_components.ex` was written against Phoenix's upload
primitives with Tailwind classes. The catalog has a "File drop" entry with
`ds-drop*` classes: `m-upload`, title, a hint line stating types and size,
accent edge on hover/focus/drag-over, chosen files listed beneath with
`m-close`, progress bar. gos-ui vendors the `ds-drop*` CSS but has no
HEEx component for it. Verdict: **rewrite** `file_drop/1` on the `ds-drop`
classes with `<.mark name="m-upload">`, keeping the LiveView upload wiring;
the hint line is missing today and the system requires it. A `file_drop`
component that takes an `UploadConfig` belongs in gos-ui: **system**.

### Buttons are daisyUI variants

`<.button>` emits `btn btn-primary` or `btn btn-primary btn-soft`. The
system has primary / ghost / danger / text, with `danger` the only place
`status/critical` is allowed on a control, and the state matrix for hover,
focus, active, disabled, loading. Delete links on the index pages are plain
anchors, not danger buttons. Verdict: **adopt** `GosUi.Components.button/1`,
which has the four variants and a `loading` attr. It renders a `<button>`
only; the navigating buttons (Back, Edit, Cancel) become `<.link>` with the
`ds-btn` classes, or gos-ui grows `navigate` on its button: **system**.

### Destructive actions use the browser confirm with "Are you sure?"

Every Delete is a link with `data-confirm="Are you sure?"`, the exact
phrase the voice chapter lists under Don't. The destructive-confirm flow is
a danger button opening a modal (or inline confirm when the action is one
of many on a page) that names the target and states irreversibility, with
verb buttons `Delete` / `Cancel`. Deleting a transducer stops a running
instance and deleting an API spec breaks bindings, so both are high-stakes
and want the type-the-name gate. Verdict: **adopt** `<.modal destructive>`
from gos-ui (inline confirm is CSS only there, no component), copy per the
voice chapter:
"Delete lights-2? Its instance stops and its bindings are removed. This
can't be undone."

### Flash and error copy breaks the voice rules

The scaffold's flash titles are "Something went wrong!", "We can't find the
internet", and the example "oh no!". Submit buttons say "Saving...". The
voice is impersonal, no "we", no exclamation points, no filler; success is
the shortest true statement. Flash is a daisyUI toast with heroicons rather
than the toast stack with `aria-live` and auto-dismiss. Verdict: **adopt**
`<.flash_toasts>` and the `GosUiHooks` timer; **rewrite** the strings:
"Connection lost. Reconnecting." for both disconnect cases, `Saving` with
the loading state instead of an ellipsis, "Saved." on success.

### Icons are heroicons; marks are the sprite

Every icon is `hero-*` from the Tailwind heroicons plugin: arrow-left,
pencil-square, plus, arrow-up-tray, exclamation-circle, x-mark, arrow-path.
The system's marks are a 24px monoline sprite referenced by id with
unicode and ascii fallbacks, and the status silhouettes are reserved.
Verdict: **adopt** `<.mark name="m-...">`. Where the sprite lacks a mark
the fallback is a text label, not a heroicon. Drop the `heroicons` dep with
the plugin.

### Page shell is a hand-made header, not the app shell

`Layouts.app/1` is a white header bar with a green dot and four nav links,
over a `max-w-5xl` column. The system's app shell is brand, summary, meta,
actions in the head, a nav, and `main#main`, with the skip link first.
Content width: prose constrained to the measure, data tables full width.
Verdict: **adopt** `<.app_shell>` with `<.skip_link>`, `<.menu>` for the
nav, `<.breadcrumb>` on show and edit pages per the detail-view pattern.
The green dot is not a mark in the sprite and carries no meaning; it goes.

### Code and source are `<pre>` with Tailwind, JSON is `Jason.encode!`

Source on the show pages, the curl example on the listener page, and the
node chips on the YANG page are hand-styled `<pre>` and `<span>` elements.
Tokens in the marking table are inline JSON strings. The catalog has a
code block with head row and copy button, a data viewer for JSON/edn, and
`<.key_value>` for property grids. gos-ui has `key_value` but only the
CSS for code block, copy button, and data viewer. Verdict: **adopt**
`<.key_value>` for the show-page headers; **rewrite** the `<pre>` blocks on
the `ds-code` classes; code block, copy button (needs a client hook), and
data viewer components are **system**. `Jason.encode!` in a dense table
cell is acceptable until the data viewer exists.

### Recent events is a list, not a log view

The event stream on the transducer page is a `<ul>` of mono lines with
failed lines in `text-red-600`. The system has `<.log_view>` with
timestamp, severity column, tail-following, and `--critical` lines, and the
critical word must agree with the color and glyph. Verdict: **adopt**.
Failed events map to `critical`, fired to `low`, which also fixes the
status-lexicon mismatch of a red line with no glyph.

### No empty, loading, or error states anywhere

The index pages show headers over nothing when empty; the listener page
says "No enabled transducers yet." in muted text with no action; a stopped
transducer says "Not running. Enable the transducer to start it." which is
the right shape but unstyled. Nothing shows a loading state, and a failed
action is a red log line. The rule is every data view defines all three.
Verdict: **adopt** `<.state_panel>` for the triad, with the primary action
in the empty state ("No transducers. Upload a net to create one." with a
New button).

### Radii and shapes outside the edge tokens

`rounded-full` on badges and the file-drop chip, `rounded-lg` on `<pre>`,
`rounded-md` on controls. The system allows 0 / 2 / 4 / 6 and nothing
rounder, pills only for meters and toggles. Verdict: covered by **adopt**
of the components above; the remaining hand-written classes get
`--radius-sm` / `--radius-md` / `--radius-lg` as part of the rewrite.

### Light-only

Every hand-styled element assumes a white page (`bg-white`, `fill-white`,
`bg-zinc-100`, `text-zinc-900`). The system is dark by default and treats
light as the second mode of the same theme. Verdict: covered by the
stylesheet **adopt**; the remaining hand-written SVG and tables are the
diagram and table rewrites above.

### The Phoenix welcome page and logo are still shipped

`page_html/home.html.heex`, the orange Phoenix hero SVG, `priv/static`'s
logo, and `GET /` serving them. Not a design-system deviation so much as a
violation of "no imagery, no gradients", and it is the one place the theme
toggle is reachable. Verdict: **rewrite**, `GET /` redirects to
`/admin/transducers` and the page, template, and logo go. This is also the
daisyUI shortcut's last item.

## Open

- Hierarchical nets, compensation, timed transitions are not in `cpn-spec 1.0`
  (tracked in `ex_cpn`).
- No audit journal; `ExCpn.Instance` journal events are not persisted.
