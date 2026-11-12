# Actuator

AS A generic TRANSDUCER, I can convert HTTPS requests into changes to an API endpoint that is provided by a third-party service or an "actuator-agent" that is installed on a machine, SO THAT I can control the behavior of the system remotely.

A TRANSDUCER is defined as a runtime configuration using data models (rendered in YANG), action models (rendered as Colored Petri Nets), acceptance tests (rendered as gherkin features), and, optionally, c4like diagrams and anemos rules.

When created, a TRANSDUCER has it's own listener, uri, and supervision tree.

Transducers connect LISTENERS to CLIENTS.


As a CLIENT I make requests and recieve responses to an API.   

AN API is defined at runtime by an OpenAPIv3 specification.


The transducer can compose multiple API calls together to create a single action input.  When it does this, it is responsible for the appearance and outcome of ATOMICITY.

