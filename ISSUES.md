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

## Open

- Hierarchical nets, compensation, timed transitions are not in `cpn-spec 1.0`
  (tracked in `ex_cpn`).
- No audit journal; `ExCpn.Instance` journal events are not persisted.
