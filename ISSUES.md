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

## Open

- Hierarchical nets, compensation, timed transitions are not in `cpn-spec 1.0`
  (tracked in `ex_cpn`).
- No audit journal; `ExCpn.Instance` journal events are not persisted.
