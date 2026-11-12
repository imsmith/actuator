# Actuator

AS A generic TRANSDUCER, I can convert HTTPS requests into changes to an API
endpoint that is provided by a third-party service or an "actuator-agent" that
is installed on a machine, SO THAT I can control the behavior of the system
remotely.

A TRANSDUCER is defined as a runtime configuration using data models (rendered
in YANG), action models (rendered as Colored Petri Nets), acceptance tests
(rendered as gherkin features), and, optionally, c4like diagrams and anemos
rules.

When created, a TRANSDUCER has its own listener, uri, and supervision tree.
Transducers connect LISTENERS to CLIENTS.

As a CLIENT I make requests and receive responses to an API. AN API is
defined at runtime by an OpenAPIv3 specification.

The transducer can compose multiple API calls together to create a single
action input. When it does this, it is responsible for the appearance and
outcome of ATOMICITY.

## What exists today

The prototype is a Phoenix 1.8 app on SQLite with one admin user. The action
model is the part that runs; YANG types are recorded but not enforced, Gherkin
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
* **API specs** are OpenAPI 3 documents stored as pasted, JSON or YAML, with a
  base URL and an optional auth header. `Actuator.ApiSpecs`.
* **Bindings** attach one transition to one operation. When it fires, the
  consumed token becomes the request and the response becomes the produced
  token. `Actuator.Transducers.Action`.
* **Admin UI** under `/admin`: transducers with live markings and journal
  events, API specs with their operations, bindings, and the listener API doc.
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
