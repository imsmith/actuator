# Actuator — Market Requirements Document

Detection-to-containment: closing the loop from SIEM/SOAR into the network.

| | |
|---|---|
| Status | Draft 0.1, 2026-11-16 |
| Owner | Ian Smith |
| Scope | Market problem, buyer, requirements. Not a design. |
| Sources | Second-brain vault, cited inline as `[V:n]`, listed in §13 |

## 1. The incident

It is 02:10 on a Saturday. Microsoft Sentinel raises a high-severity incident: a build host in the payments VPC is resolving a domain registered nine days ago and pushing 40 MB/hour to it over TLS. The on-call analyst sees it. The analyst can disable the user in Entra ID with one playbook click. The analyst cannot touch the egress firewall, the cloud network controller, or the DNS resolver. Those belong to the network team, on another P&L, behind a change ticket. The playbook stops at the edge of the SIEM vendor's own estate.

So the analyst pages someone. That person has to work out whether quarantining the VPC will break the Monday payroll run, which nobody can answer at 02:10. The safe-looking choice is to wait, and the bytes keep leaving while they do.

That pause is the market. Turning it all off is the best response, but they don't do that because they believe it costs more than continued data exfil — this is the true vulnerability being exploited `[V:1]`. Attackers are not exploiting a missing detection. They are exploiting the cost, delay and political risk of acting on a detection that already fired.

A 40-hour staffed week covers 24% of the 168 hours in a week. The other 76% is nights and weekends, and that is where a human-gated response loop is at its slowest.

## 2. Thesis

The detection half of security and the enforcement half of security are sold by different vendors with different control planes, policy grammars, and log formats. Nobody owns the link between them. The missing link is the link... it all doesn't fit together and doesn't have the orchestration, choreography, and improvisation to manifest business policy into reality `[V:2]`.

Actuator is that link. A SEIM detection or SOAR event sends a message that arrives as an HTTPS request. Actuator runs a workflow whose transitions are bound to operations in third-party APIs, each described by an OpenAPI document loaded at runtime. Those APIs are firewalls, cloud network controllers, DNS resolvers and proxies. The net owns sequencing and atomicity: either every step of the containment lands, or the completed steps are compensated.

Humans exercise discretion when they *author* the workflow, and again when they decide what happens after containment. The step from verdict to enforcement is mechanical. Exceptions to the rule, come from the rule makers, not the rule enforcers" `[V:3]`.

## 3. Why the gap persists

Every adjacent category can see the gap, and each has a structural reason not to close it.

| Category | What it does | Why it stops short |
|---|---|---|
| SIEM / XDR | Correlates telemetry into detections | Downstream of enforcement; correlation, not control. It reconstructs reality from exhaust that infrastructure already shaped. |
| SOAR | Runs playbooks on alerts | It assumes the remediation target is well defined. Playbooks are vendor-scoped. |
| Firewall / SSE vendors | Enforce their own policy grammar | Vendors build appliances, not circuits. Each box is an island with its own control plane. None will orchestrate a competitor's. |
| Hyperscaler native controls | Security groups, NACLs, route tables, DNS firewall | A neutral cross-cloud layer breaks product silos and reduces SKU differentiation. |
| General workflow engines (n8n etc.) | Event-to-API glue | Doesn't reconcile at all. It's purely reactive. No atomicity, no compensation, no notion of drift. |

## 4. Why the network is the enforcement point

- **The chokepoint is unavoidable.** All cybersecurity is fraud facilitated by trespass, which is only possible over the network. The attacker can vary payload, identity and timing. The attacker cannot avoid traversing a path.
- **It acts before the logs are flattened.** The network is where intent first collides with reality.
- **It is reachable by API.** Every major firewall, cloud network controller and DNS service now exposes an HTTP API with an OpenAPI or equivalent description. Policy is comprehensible, therefore reducible, therefore something you can quickly, programmatically abstract to a common denominator.
- **Disconnection is the outcome.** A disconnected adversary is a defeated adversary.

## 5. Why buyers pay

### 5.1 Precision makes the "turn it off" decision cheap

The buyer already knows how to stop exfiltration: pull the plug. They don't, because blunt containment costs more than they believe the breach does. Precise, scoped, reversible containment changes that arithmetic. It is the difference between surgery and amputation. The product being sold is a smaller cost of acting, not better detection.

The litmus test for every feature: Does this help us make a correct, bounded decision faster under stress — and undo it safely if wrong?

### 5.2 They are not buying detection

Explicitly out of scope for the buyer: 'AI-powered' anything, massive SOC teams, perfect detection, total prevention, zero false positives. What they pay for: Fast, scoped, reversible control; provable outcomes; predictable behavior under stress.

### 5.3 Evidence is a deliverable

After an incident, the CISO answers to the board, the regulator and the insurer. If the evidence is "screenshots or Slack archaeology," the response has already failed. A Petri-net run is a timeline by construction: every token, every transition, every API call with its request, response and before/after state. That turns 'we think we stopped it' into defensible truth.

### 5.4 Governance budget, not security budget

Security is a subset of policy, and policy is a subset of governance. We have products that pay you back for governance, not products that sell you security. Actuator turns a written policy ("a compromised build host is isolated from egress within N minutes") into an executable, tested, audited mechanism. That is a governance control, and it can be bought from that budget.

### 5.5 It names the number

The industry can't prove prevention, so it sells vocabulary. The questions to a buyer are: "How many bytes will you let be exfiltrated this year? How many minutes of downtime because of incident response? How many minutes of unauthorized access before detection?". Actuator makes one of those numbers measurable and contractable: **MTTI, mean time to isolate**. Detection without isolation is a vanity metric.

### 5.6 Complexity priced in dollars

Each additional vendor console in the response path multiplies incident cost. Complexity is the most important factor in any decision point, and for business that must be presented in units of dollars, and the industry isn't pricing it, which is why it's interesting and an opportunity. The design rule follows from that: Build systems to be minimally complex in maximal stress situations.

### 5.7 Buying signals

The fertile-ground test is at least two of these:

- They can't confidently see data leaving.
- They detect more than they prevent.
- They have felt audit, breach, board or regulator pressure.
- Their tools are too noisy / too static / too hard to manage.
- They admit detection exists but prevention is weak, brittle, or political.

## 6. The agentic world and the Containment Era

### 6.1 Agents make old things faster

Nothing about agents is new, but what they do largely is make old things faster. An agent calls the same APIs, opens the same sockets and reads the same files a human operator did. When a human was in that loop, the human *was* the control substrate. The agent removed the human, and nothing replaced them. Containment has to become an explicit, enforceable, auditable runtime function, because the judgment that used to sit in a person's head is gone.

This works in both directions. Attackers run agents, and defenders deploy agents that become workloads in need of containment. Either way, the decision to isolate arrives at machine speed, and a human approving each enforcement action at that speed is the same theater as a human in a loop running at machine speed.

### 6.2 The era sequence

Aviatrix's April 2026 Containment Era whitepaper reads security history as a sequence of answers to one tactical question: where does the enforcement point go?

1. **Perimeter Era.** Enforce at the edge. It ended when traffic stopped respecting the edge.
2. **Detection Era.** Assume the edge leaks, and find the bad thing. The question is "Can we detect it?"
3. **Containment Era.** Assume some code in the estate is already compromised, and detection may never flag it. The question becomes "What can it reach?"

The proof event is **the Cascade**: TeamPCP's campaign through Trivy, Checkmarx KICS, LiteLLM, Telnyx and CanisterWorm, across five package registries in twelve days. Each step arrived through a trusted update channel. Trusted code does not look suspicious. The Cascade forces what they call **the Fork**: keep spending primarily on detection, or build the containment that limits the damage when detection misses.  Detection always misses.

These eras exist inside a **Governance Eon**. Each era is a different answer to whether identity, policy and context fit together. Point-in-time **Chokepoint Compliance** gives way to continuous **Containment Governance**.

### 6.3 Where Actuator sits relative to that frame

The end state is preventive: default-deny egress at every workload, one policy propagated everywhere, blast radius as the primary metric. In that frame, SIEM, SOAR, XDR and EDR all belong to the outgoing detection thesis, and detection is an event logger, documenting what happened after the damage is done.

Actuator does not claim to be the Containment Era's enforcement layer. It covers the years in between, and the gaps that never close:

- **Most estates are not default-deny yet.** A detection that fires today has to be able to narrow reachability today, on whatever enforcement points exist, including a default-deny fabric where one is deployed.
- **Detection still fires, and its findings are wasted.** Under the containment thesis, a detection is the signal to shrink the allowed set. Actuator turns each detection into a tightening of what the compromised workload can reach. It is the answer to the question "What can it reach?", driven by the evidence the detection stack already produced.
- **Default-deny policy drifts toward permissive.** Exceptions accumulate. The tighten-automatically, relax-on-corroboration loop (§6.5) is how a default-deny estate stays default-deny.

Actuator does not compete with the SIEM's detection, and it does not compete with the enforcement fabric. It makes the SIEM's detections change what the fabric permits.

### 6.4 Tempo

The threat space has a faster OODA loop than the governing institutions and is mutating faster than the regulatory observation loop can close. Compliance is a point-in-time snapshot, and every Cascade victim was, almost certainly, in compliance with something. Containment has to be built by the operators and the platform providers, not waited for from the regulators. The buyer cannot wait for a mandate, and the first mandates (EU Cyber Resilience Act, federal procurement, cyber-insurance underwriting) are already moving toward continuous evidence.

### 6.5 Asymmetric automation is what makes it safe

The design that makes automated enforcement acceptable to a risk-averse buyer comes from the semantic supply-chain work:

- **Tightening is automatic.** Removing a permission cannot grant new access. Automated tightening is safe to do continuously.
- **Relaxing needs corroboration.** Restoring access requires several independent sources to agree. Single-source observations should not drive relaxation.
- **Emergency lockdown is a first-class operation.** Revert to the last known-good baseline in one action.

This answers the buyer's main objection ("automation will break production"): automation only moves in the safe direction without corroboration, and every move it makes is reversible within a declared bound.

### 6.6 The economics just flipped

Problems that were genuinely unaffordable to solve two years ago are now unaffordable not to solve. This is not a gradual shift. It is a discontinuity. Cheap model-assisted analysis means every organization now produces more high-confidence detections than its humans can act on. The bottleneck has moved from finding to acting.

## 7. Buyers and users

| Role | Who | What they say | What they need from Actuator |
|---|---|---|---|
| Economic buyer | CISO, sometimes CIO or Risk | "Who answers to the board?" | MTTI as a reportable number; evidence for regulators and insurers |
| Champion | Security leader "tired of alerts with no control" | "We detect it and then file a ticket." | Detections that end in enforcement without a cross-team page |
| Gatekeeper | Network / platform engineering lead | "Who approves blocking traffic in real time?" | Scoped, reversible, pre-approved actions on their gear, authored with them |
| Operator | SOC / IR analyst under cognitive overload — will mis-click, overreact, hesitate | | One decision, not a coordination exercise |
| Auditor | Internal audit, insurer, regulator | | A replayable record of what was decided, by which rule, with which effect |

The deciding question in discovery is **"Who must approve blocking data movement in real time?"**. If the answer is a meeting, the deal depends on moving that approval to authoring time.

Competition is mostly not other products. It is inaction and existing tools, and DIY scripts glued to SOAR webhooks.

## 8. Market requirements

Priority: **M** must for first paying customer, **S** should, **C** could. "Traces to" links each requirement to the vault argument it answers.

| ID | Requirement | Pri | Traces to |
|---|---|---|---|
| MR-01 | Accept a detection from any SIEM/SOAR as an authenticated HTTPS request, with no SIEM-side plugin required | M | §3, §6.2 |
| MR-02 | Drive any enforcement point whose API is described by an OpenAPI document supplied at runtime; no vendor-specific code in the core | M | §3, §4 |
| MR-03 | Execute multi-step containment atomically: all steps land, or completed steps are compensated | M | §5.1, P-04 |
| MR-04 | Every enforcement action is reversible within a declared time bound without manual repair | M | P-04 |
| MR-05 | Scope every action to a declared blast radius (workload, VPC, account, identity) and refuse actions outside it | M | P-03, §5.1 |
| MR-06 | Tightening actions run without human approval; relaxing actions require N independent corroborating signals or an authorized human | M | §6.5 |
| MR-07 | Emergency lockdown to the last known-good baseline as a single operation | S | §6.5 |
| MR-08 | Record a tamper-evident journal of every token, transition and API exchange, with before/after state, exportable for IR, audit and regulators | M | §5.3 |
| MR-09 | Report MTTI per workflow and per detection class | M | §5.5 |
| MR-10 | Keep enforcing when the SIEM, SOAR or IdP is down; inbound integrations are loose, and nothing on the action path depends on them | M | §5.3 |
| MR-11 | Dry-run any workflow against a detection and show the actions and blast radius it would produce, before it is enabled | M | §7 gatekeeper, P-05 |
| MR-12 | Fail in documented, testable ways: an action that cannot complete yields an explicit error state, never a hang or partial silent change | M | P-05 |
| MR-13 | Change workflows and API bindings through auditable configuration without restarting in-flight containments | S | P-06 |
| MR-14 | Keep outbound credentials for enforcement points out of the workflow store; resolve them at call time from a secrets broker | M | §7 gatekeeper |
| MR-15 | Idempotent handling of duplicate detections (SIEMs re-fire) | M | MR-03 |
| MR-16 | Executable acceptance tests (Gherkin) shipped with each workflow, runnable against stubs in CI | S | P-07 |
| MR-17 | Validate inbound detection payloads against a declared schema before accepting them | S | MR-01 |
| MR-18 | Graduated containment modes (rate-limit, then isolate, then quarantine) with explicit entry and exit criteria | S | P-02 |
| MR-19 | Self-hostable, single-node deployment with no external database | S | buyer control of the action path |
| MR-20 | Contain AI agent workloads by identity and egress, using the same workflows as for any other workload | C | §6.1 |

## 9. Objections and answers

| Objection | Answer | Requirement |
|---|---|---|
| "Automated blocking will take down production." | Tightening is scoped to a declared blast radius, previewed in dry-run, reversible in bounded time. Relaxation and broad actions need corroboration. | MR-04, 05, 06, 11 |
| "Our SOAR already does this." | It runs playbooks for its own vendor's estate. Ask it to isolate a VPC in the other cloud through the network team's controller and roll back if step three fails. | MR-02, 03 |
| "The network team won't give the SOC write access." | They don't. They author and approve the workflows. The SOC triggers them. Discretion moves to authoring time. | §2, MR-11 |
| "We'll wait for the regulation." | Regulation lags the threat loop. The Cascade victims were compliant. | §6.4 |
| "Another tool adds complexity." | It removes consoles from the incident path. The measure is consoles touched per containment, before and after. | §5.6 |
| "AWS support won't help with your custom daemon at 3 a.m." | Actuator calls the provider's own APIs. The resulting state is native config that the provider can support. | MR-02 |

## 10. Success metrics

No targets yet. The vault's candidate targets are unsourced (§12). These are the measures to agree with a design partner:

- **MTTI**: time from detection received to containment confirmed by the enforcement point's own API.
- **Consoles touched per containment**: before and after.
- **Unrolled-back false containments**: actions later judged wrong that were not reversed within the declared bound. Target zero.
- **Detections with no bound workflow**: coverage gap, as a share of high-severity detection classes.
- **Evidence assembly time**: from incident close to auditor-ready record.

## 11. Fit of the current prototype

| Requirement | State today |
|---|---|
| MR-01 inbound HTTPS | Built: `POST /t/<name>`, single shared bearer token |
| MR-02 OpenAPI-defined actions | Built: stored specs, transition-to-operation bindings, Req-backed calls |
| MR-03 atomicity / compensation | Not built; `cpn-spec 1.0` has no compensation (tracked in `ex_cpn`) |
| MR-08 journal | Live journal events in the admin UI; not persisted or tamper-evident |
| MR-13 change without dropping in-flight | Not met; restart drops tokens (ISSUES.md) |
| MR-14 credentials broker | Not met; `auth_header` stored in plaintext (ISSUES.md) |
| MR-17 payload validation | Not met; YANG type recorded but not enforced |
| MR-16 Gherkin | Not wired |
| MR-06 tighten/relax asymmetry | Not built; candidate is rules inside function blocks |
| MR-19 self-hosted single node | Met: Phoenix on SQLite |

The prototype covers the plumbing: listener, net, binding, outbound call. The things buyers pay for in §5 (atomicity, reversibility, scoping, evidence) are the unbuilt part.
