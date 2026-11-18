# Actuator

Actuator is a project to make it easy to control a system remotely, using a generic
transducer that converts HTTPS requests into changes to an API endpoint.  This permits building systems that can have a relatively simple API that abstracts away the complexity of the system or systems being controlled.

## What exists today

The prototype is a Phoenix 1.8 app on SQLite with one admin user. The action
model is the part that runs; YANG modules are stored and place types resolve
against them, but request bodies are not yet checked against them. Gherkin
and Anemos are not wired in yet.

```text
HTTPS request ──▶ POST /t/<name> ──▶ token on the entry place
                                          │
                       ExCpn.Instance (one gen_statem per transducer)
                                          │ transition fires
                       bound? ──▶ Actuator.Transducers.Action ──▶ Req ──▶ third-party API
                                          │ response merged into the token
                                     downstream places
```

* **Definitions** are `cpn-spec 1.0` nets, stored with a name and an entry
  place and validated with [`ex_cpn`](https://github.com/imsmith/ex_cpn) on
  every change. `Actuator.Transducers`.
* **Instances** run under a `DynamicSupervisor`, one per enabled definition,
  found by name in a `Registry`. Create starts, update restarts, disable and
  delete stop. `Actuator.Transducers.Instances`.
* **Listener** `POST /t/<name>` puts the JSON body on the entry place and
  replies `202`. `ActuatorWeb.TransducerController`.
* **API specs** are OpenAPI 3 documents, JSON or YAML, with a base URL and an
  optional auth header. `Actuator.ApiSpecs`.
* **YANG modules** are stored as given, name and prefix read from the source.
  A net that says `yang import home` must have `home` stored, and every
  `place -type hm:request` must name a top-level node, typedef, or grouping
  of it. A net with no imports is not checked. `Actuator.YangModules`.
* **Bindings** attach one transition to one operation. When it fires, the
  consumed token becomes the request and the response becomes the produced
  token. `Actuator.Transducers.Action`.
* **Admin UI** under `/admin`: transducers with live markings and journal
  events, API specs with their operations, YANG modules, bindings, and the
  listener API doc. Every source form takes a pasted document or a dropped
  file.
* **Published listener API** at `GET /t/openapi.json`.
* **Telemetry** events for fired, failed, accepted, rejected, with counters on
  LiveDashboard. `Actuator.Transducers.Telemetry`.

## Running it

```sh
mix setup
mix phx.server
```

Then:

* Admin UI: <http://localhost:4000/admin/transducers>, HTTP basic auth, user
  `admin`, password `dev-token`.
* Listener: bearer token `dev-token`.

```sh
curl -X POST http://localhost:4000/t/lights \
  -H "Authorization: Bearer dev-token" \
  -H "Content-Type: application/json" \
  -d '{"device": "lamp-1", "state": "on"}'
```

A minimal transducer source to paste into the form:

```tcl
cpn-spec 1.0
place inbox -type home:request
place done  -type home:request
transition handle {
  in  {inbox r}
  out {done $r}
}
```

Entry place `inbox`. Bind `handle` to an operation on the transducer page
once an API spec exists, and the request body is sent to that operation.

## Demo: a lamp to transduce

`demo/lamp.tcl` is a pretend device with an HTTP API and an OpenAPI spec, so
there is something real to drive. In one terminal:

```sh
tclsh demo/lamp.tcl        # http://localhost:4100, prints every state change
```

Then, in the admin UI:

1. API specs, New: name `lamp`, paste `curl http://localhost:4100/openapi.json`.
2. Transducers, New: name `lights`, entry place `inbox`, the source above.
3. On the `lights` page, bind `handle` to `lamp:setState`.

Now a listener request changes the lamp, and the lamp says so:

```sh
curl -X POST http://localhost:4000/t/lights \
  -H "Authorization: Bearer dev-token" \
  -H "Content-Type: application/json" \
  -d '{"id": "lamp-2", "state": "on"}'
# lamp terminal:  14:03:21  lamp-2: off -> on
```

The `id` fills the `{id}` path parameter, `state` goes in the JSON body, and
the lamp's response lands on `done` with the token.

## Configuration

| Setting | Dev and test | Prod |
|---|---|---|
| API token (listener bearer, admin password) | `dev-token` | `ACTUATOR_API_TOKEN` |
| Database | `actuator_dev.db` beside the project | `DATABASE_PATH` |
| Outbound HTTP options | `Req.Test` stub in test | none |

## Development

```sh
mix precommit   # compile --warnings-as-errors, unused deps, format, test
mix quality     # credo --strict, sobelow --skip --exit, dialyzer
mix docs
```

Sobelow runs with `--skip` so that `# sobelow_skip` comments in the source
apply; each one states why.

Known shortcuts and their upgrade paths are in [ISSUES.md](ISSUES.md).

## License

AGPL-3.0-only.
