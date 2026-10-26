---
title: "COAZ-RAR: COAZ Binding for OAuth 2.0 Rich Authorization Requests - Draft 1"
abbrev: "coaz-rar"
category: std
ipr: none
docname: draft-gazitt-authzen-coaz-rar-latest
workgroup: OpenID AuthZEN
consensus: true
v: 3
stand_alone: true
smart_quotes: no
pi: [toc, sortrefs, symrefs, private]
keyword:
 - authorization
 - AuthZEN
 - OAuth
 - rich authorization requests
 - fine-grained authorization
author:
 -
    fullname: "Omri Gazitt"
    organization: "Independent"
    email: "ogazitt@gmail.com"
normative:
  RFC2119:
  RFC8174:
  RFC9396:
  AUTHZEN:
    title: "Authorization API 1.0"
    target: "https://openid.net/specs/authorization-api-1_0-final.html"
    date: 2026-01-11
    author:
      - ins: "OpenID Foundation AuthZEN Working Group"
        org: "OpenID Foundation"
  COAZFW:
    title: "COAZ: A Framework for Mapping Information Models to AuthZEN Authorization Requests"
    target: "https://openid.github.io/authzen/authzen-coaz-framework-1_0.html"
    date: 2026
    author:
      - name: "Alex Olivier"
        org: "Cerbos"
      - name: "Atul Tulshibagwale"
        org: "CrowdStrike"
  ISSUANCE:
    title: "AuthZEN Profile for OAuth 2.0 Token Issuance"
    target: "https://openid.github.io/authzen/authzen-oauth-token-issuance-1_0.html"
    date: 2026
    author:
      - name: "Omri Gazitt"
        org: "Independent"
  RARMETA: I-D.ietf-oauth-rar-metadata-remediation
  CEL:
    title: "Common Expression Language"
    target: "https://cel.dev/"
    date: 2024
    author:
      - name: "Google"
informative:
  RFC6750:
  RFC7662:
  RFC9068:
  RFC9728:
  AUTHMETA: I-D.zehavi-oauth-authority-metadata
  COAZMCP:
    title: "COAZ-MCP: COAZ Binding for the Model Context Protocol"
    target: "https://openid.github.io/authzen/authzen-coaz-mcp-binding-1_0.html"
    date: 2026
    author:
      - name: "Atul Tulshibagwale"
        org: "CrowdStrike"
      - name: "Alex Olivier"
        org: "Cerbos"
  MCP:
    title: "Model Context Protocol Specification"
    target: "https://modelcontextprotocol.io/specification"
    date: 2025
--- abstract

This specification defines COAZ-RAR, the COAZ binding, as defined by the COAZ
Framework {{COAZFW}}, for OAuth 2.0 Rich Authorization Requests {{RFC9396}}.
An authorization details type is typically defined by one party and processed
by others: an authorization server decides whether to grant an entry of that
type, and a resource server decides whether a call is permitted under it.
This binding lets the definer of a type publish, once, how an entry of that
type maps onto an OpenID AuthZEN Authorization API request {{AUTHZEN}}, and
lets both enforcement points apply that mapping. The authorization server
applies it at token issuance, under the AuthZEN profile for OAuth 2.0 token
issuance {{ISSUANCE}}; the resource server applies it when a call arrives.
Both ask the Policy Decision Point their questions in one vocabulary. The
mapping is published as a member of the type's entry in the authorization
details types metadata defined by {{RARMETA}}.

--- middle

# Introduction

Rich Authorization Requests {{RFC9396}} let a client ask for structured,
fine-grained access: a payment to a named creditor for a stated amount, read
access to one patient's records, a set of file paths. Each entry in an
`authorization_details` array has a `type`, and the type determines which
members the entry may carry and what they mean.

A type is usually defined by someone other than the authorization server (AS)
that processes it. Open banking and health ecosystems define types that many
servers must handle, which is why {{Section 2.1 of RFC9396}} recommends
collision-resistant type names for APIs "expected to be deployed across
different servers." The resource server (RS) whose API a type describes is
another definer. So is a Model Context Protocol {{MCP}} server, whose tool
input schemas are type definitions in all but name.

RFC 9396 leaves the decision to grant an entry, and the RS's decision on a
call made under it, to each server. Two pieces of adjacent work narrow that
gap from different sides:

- The AuthZEN profile for OAuth 2.0 token issuance {{ISSUANCE}} lets an AS
  externalize the issuance decision to a Policy Decision Point (PDP). It
  decomposes an entry along RFC 9396's common data fields (`locations`,
  `actions`, `datatypes`) and asks one question per cell. It does not decompose
  `identifier`, `privileges`, or any type-specific member, so for a type whose
  meaning lives in its own members, such as the creditor and amount of a
  payment, the PDP never sees what the decision is about.

- {{RARMETA}} defines an AS metadata endpoint that publishes a JSON Schema for
  each type, and a challenge with which an RS that refuses a call tells the
  client exactly which entry to request.

Neither says how an entry of a given type becomes an authorization question.
The party that knows is the type's definer. The COAZ Framework {{COAZFW}}
exists for exactly this split between a party that describes an operation and
a party that enforces it: COAZ-MCP {{COAZMCP}} lets an MCP server declare, in
a tool's input schema, how a call to that tool maps onto an AuthZEN request,
so that a gateway with no knowledge of the server's business logic can
enforce it.

This specification is COAZ-RAR, the COAZ binding for authorization details. It
treats an authorization details type as the operation description, and the
types metadata of {{RARMETA}} as the place a mapping is published. Two
enforcement points apply it:

- The AS, at issuance, for each cell of each requested entry, in place of the
  per-cell projection of {{ISSUANCE}}.

- The RS, when a call arrives, for the entry the call amounts to.

Because both apply the same mapping, both ask the PDP in one vocabulary. Where
the entry names a specific resource, as it does when the RS built it from a
call it refused, the AS and the RS ask the same question. Where it doesn't, as
with a standing grant, the AS asks about the class of resource and the RS asks
about the member of it that the call touches.

## Requirements Notation and Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in BCP 14 {{RFC2119}} {{RFC8174}}
when, and only when, they appear in all capitals, as shown here.

## Terminology

This specification uses the terms defined in the COAZ Framework {{COAZFW}},
notably binding, information model, input variable, mapping, literal,
expression, default mapping, declared mapping, PEP, and PDP, and the terms
authorization details, authorization details type, and common data fields
defined by {{RFC9396}}. It adds the following:

Entry:
: One object in an `authorization_details` array.

Cell:
: One combination of a `locations` value, an `actions` value, and, where
  present, a `datatypes` value of an entry. {{Section 2.2 of RFC9396}} defines an
  entry as the product of these values; a cell is one element of that product.

Type Definer:
: The party that defines an authorization details type and its meaning: an
  ecosystem, a resource server operator, or an MCP server.

Issuance PEP:
: The AS, acting as a PEP when it decides whether to grant an entry under
  {{ISSUANCE}}.

Resource PEP:
: The RS, or a gateway in front of it, acting as a PEP when it decides whether
  to permit a call.

Projection:
: The entry and cell that an RS determines a call amounts to.

Prospective Token:
: The set of claims the AS will place in the access token it is about to
  issue, as known before the PDP is asked.

# Relationship to the COAZ Framework

This binding fulfils the binding conformance requirements of the COAZ
Framework {{COAZFW}} as summarized below; each row is specified in the
referenced section.

| Framework requirement | This binding |
|---|---|
| Information model | `detail`, `cell`, `token`, `params` ({{information-model}}) |
| Mapping location | `authzen_mapping` in the type's metadata entry, else `x-authzen-mapping` in the type's schema, else the default ({{declaring}}) |
| Literal/expression discriminator | Framework default: `$` prefix, `$$` escape ({{expressions}}) |
| Expression language | Framework default: CEL {{CEL}} ({{expressions}}) |
| Envelopes | `evaluation` and `evaluations` ({{envelopes}}) |
| Operations in scope | One cell of one entry; no pass-through set ({{operations}}) |
| Default mapping behavior | The per-cell projection of {{ISSUANCE}} ({{default-mapping}}) |
| Declared mapping behavior | The type definer MAY declare a mapping; it overrides the default for that type ({{declared-mappings}}) |
| Trust-anchored fields | `subject.id`, by verification ({{declared-mappings}}) |
| Error transport | OAuth error responses at the AS, HTTP status at the RS ({{errors}}) |
| Discoverability | The types metadata endpoint of {{RARMETA}} ({{declaring}}) |

## Architecture {#architecture}

~~~ ascii-art
 Type definer -----> AS types metadata endpoint, read by both PEPs
 (ecosystem, RS,     { "<type>": { "schema": {...},
  MCP server)                      "authzen_mapping": {...} } }

 +--------+
 |        |                        +----------------+
 |        |  (1) call              |  Resource PEP  |
 |        |----------------------->| (RS / gateway) |
 |        |<-----------------------|                |
 |        |  (2) 401, remediation  +----------------+
 |        |
 |        |                        +----------------+      +-------+
 |        |  (3) token request     |  Issuance PEP  | (4)  |       |
 | Client |----------------------->|      (AS)      |----->|       |
 |        |<-----------------------|                |      |       |
 |        |  token                 +----------------+      |       |
 |        |                                                |  PDP  |
 |        |                        +----------------+      |       |
 |        |  (5) retry             |  Resource PEP  | (6)  |       |
 |        |----------------------->| (RS / gateway) |----->|       |
 |        |<-----------------------|                |      |       |
 |        |  200                   +----------------+      +-------+
 +--------+
~~~
{: #fig-architecture title="One mapping, two enforcement points"}

1. The client calls the RS with a token that does not cover the call.
2. The RS projects the call onto an entry and answers with the remediation
   challenge of {{RARMETA}}, carrying that entry.
3. The client requests a token for the entry.
4. The AS applies the type's mapping to each cell of the entry and asks the
   PDP, under {{ISSUANCE}}. It issues a token for what the PDP permits.
5. The client retries the call with the new token.
6. The RS applies the same mapping to its projection of the call and asks
   the PDP before permitting it.

Steps 1 and 2 are absent when a client requests an entry without having been
refused, as with a standing grant. Step 6 occurs on every call the token
covers, whether or not the entry came from a remediation.

The PDP at step 4 and the PDP at step 6 need not be the same. In a
cross-domain deployment the AS's PDP holds the policy of the organization
whose user or agent is asking, and the RS's PDP holds the policy of the
organization that owns the resource. The mapping gives them a common
vocabulary without requiring a common policy.

# Information Model {#information-model}

This binding exposes four input variables to expressions. Each is populated
differently at the two enforcement points.

| Variable | At the Issuance PEP | At the Resource PEP |
|---|---|---|
| `detail` | The entry being evaluated, after any enrichment by the AS ({{enrichment}}) | The entry of the projection ({{projection}}) |
| `cell` | The cell being evaluated ({{cells}}) | The cell of the projection |
| `token` | The prospective token ({{prospective-token}}) | The claims of the presented access token |
| `params` | `{"name": <type>, "arguments": <detail>}` | The same, or the MCP `params` object where the Resource PEP is an MCP gateway |

`detail`:
: A map holding the entry, with every member it carries, including `type`.

`cell`:
: A map with a `location` key (string), an `action` key (string), a
  `datatype` key (string) that is present only when the cell has a datatype,
  and a `name` key (string) holding the action name {{ISSUANCE}} forms for the
  cell: the action alone, or the action and datatype joined by a colon.

`token`:
: A map of access token claims. At the Resource PEP these are the decoded
  claims of a JWT access token {{RFC9068}} or the members of a token
  introspection response {{RFC7662}}.

`params`:
: A map holding the operation's name and arguments in the shape COAZ-MCP
  {{COAZMCP}} exposes for `tools/call`. It exists so that a mapping written for
  an MCP tool runs unchanged when that tool is also used as an authorization
  details type ({{mcp-tools}}).

## Cells {#cells}

At the Issuance PEP, the cells of an entry and their order are those of the
Authorization Detail Tuple section of {{ISSUANCE}}, including its substitutions
for absent members: an absent `locations` takes each requested target, an
absent `actions` takes the reserved name `authorization_detail`, and an absent
`datatypes` yields cells without a `datatype` key. This binding does not change
how many cells an entry has; it changes only how each cell becomes evaluations.

At the Resource PEP, the cell is the location, action, and datatype that the
call occupies, in the type's own vocabulary.

## The Resource PEP's Projection {#projection}

A Resource PEP MUST be able to project each call it authorizes under this
binding onto an entry and a cell. The entry's `type` is the type that
describes the call, and its other members are the values the call supplies
for that type's members.

Where a call addresses a specific resource and the type allows `identifier`
({{Section 2.2 of RFC9396}}: "a specific resource available at the API"), the
projection MUST set `identifier` to that resource. This is what lets a mapping
ask about the instance at the RS while the AS, given an entry without an
`identifier`, asks about the class ({{granularity}}).

The projection is also the basis of the remediation entry of {{RARMETA}},
which that document says is "built using the failed resource request." A
Resource PEP that issues a remediation challenge SHOULD construct its entry
from the projection, adding `locations`, `actions`, and `datatypes` from the
cell only where the type's schema allows those members. Building the
remediation from the projection is what makes the AS evaluate, at issuance,
the question the RS will ask when the call is retried.

## The Prospective Token {#prospective-token}

At issuance there is no token yet. The Issuance PEP binds `token` to the
claims it will place in the token it is about to issue: at least `sub`,
`client_id`, and `aud`, and any other claim it will mint that does not depend
on the PDP's response. Claims that the PDP's response would add, such as those
of the `claims` key of {{ISSUANCE}}, are not available.

A mapping intended for both enforcement points MUST use optional selection
(`.?`) for any claim other than `sub`, so that an AS that does not mint the
claim produces an absent value rather than a mapping error.

## Enrichment {#enrichment}

{{Section 7.1 of RFC9396}} allows an AS to enrich an entry with values the user
selects during the interaction, such as a specific record. At the Issuance PEP,
`detail` MUST be the entry after enrichment. A mapping that selects a member
the client did not send, such as `identifier`, would otherwise fail on every
request from a client that relies on enrichment.

# Expressions and Literals {#expressions}

This binding uses the framework's defaults unchanged: expressions are written
in CEL {{CEL}}, a string value beginning with `$` is an expression, and `$$`
escapes a literal `$`. An expression yields **absent** by CEL optional
selection or by `optional.none()`, and the containing member is omitted.

Every mapping in this binding, including the default, contains expressions, so
a conforming PEP MUST include a CEL evaluator. An Issuance PEP SHOULD compile
a type's mapping when it adopts the type ({{declaring}}) rather than per
request.

# Mapping Envelopes {#envelopes}

This binding permits both envelope keys defined by the framework:

- `evaluation`, for a cell that needs one decision. The default mapping uses
  it, and it is RECOMMENDED for declared mappings that need one decision.

- `evaluations`, for a cell that needs several, such as a transfer that must be
  authorized both as a debit of the source account and as a payment to the
  payee. The `evaluations` array MUST be a literal array; an expression in its
  place is a mapping error, as Section 2.6 of {{COAZFW}} requires.

Any other envelope key is a mapping error.

## Operations in Scope {#operations}

The COAZ operation for this binding is **one cell of one entry**. A mapping is
applied once per cell, and the cell is permitted only if every evaluation the
mapping produces for it is a permit, which is the fail-closed rule of the
framework applied to the cell.

At the Issuance PEP, the number of cells is set by the entry and by
{{ISSUANCE}}, not by the mapping. That is how this binding keeps the number of
decisions fixed by the envelope, as the framework requires, while an entry
still yields as many questions as its product contains. How the cells of an
entry combine into what is granted, and what the AS does when some are
denied, is defined by {{ISSUANCE}} ("A Denied Cell Narrows an Entry") and is
outside this binding.

There is no pass-through set. Every cell of every entry is authorized. An
entry whose type the AS does not support is rejected under {{Section 5 of RFC9396}}
before any mapping is selected.

# Declaring a Mapping {#declaring}

A type's mapping is published in the response of the
`authorization_details_types_metadata_endpoint` of {{RARMETA}}, as a member of
the object describing that type:

`authzen_mapping`:
: OPTIONAL. A COAZ mapping, as defined by {{COAZFW}} and constrained by this
  binding, for entries of this type.

A PEP selects the mapping for a type as follows:

1. If the type's metadata object has an `authzen_mapping` member, use it.

2. Otherwise, if the type's `schema` (or the document at its `schema_uri`)
   has an `x-authzen-mapping` member at its top level, use it. This is where
   COAZ-MCP places a tool's mapping, so a tool's input schema adopted as a
   type's schema brings its mapping with it.

3. Otherwise, use the default mapping ({{default-mapping}}).

The mapping is authored by the type definer, which is the authority for it
as it is for the type's schema. The type definer may be an ecosystem, an RS,
or an MCP server. An AS operator **adopts** the mapping in the same act by
which it adopts the type's schema today, and takes it on as configuration; the
AS does not fetch a mapping from a type definer at request time. The AS's
types metadata endpoint is the channel through which the mapping is
distributed, not the source of its authority. A Resource PEP obtains the
mapping from that endpoint, so that both enforcement points apply the type
definer's mapping.

Where one type is used by several RSs, possibly under different operators,
the type and its mapping are their shared vocabulary. Each RS brings its own
PDP and policy ({{architecture}}).

The types metadata endpoint is not access-controlled. Publishing a mapping
there discloses which members of a type the policy considers, which is the
shape of the authorization question and not the policy that answers it. An AS
that considers even that shape sensitive can omit `authzen_mapping` from the
published metadata and provision the Resource PEP with it by other means.

# Default Mapping {#default-mapping}

Where a type declares no mapping, a PEP applies the following default to each
cell. It is the per-cell projection of the Authorization Detail Tuple section
of {{ISSUANCE}}, expressed as a COAZ mapping:

~~~ json
{
  "evaluation": {
    "action": { "name": "$cell.name" },
    "resource": { "type": "$detail.type", "id": "$cell.location" }
  }
}
~~~
{: #fig-default title="The default mapping"}

The subject and the top-level context are supplied by the PEP: by
{{ISSUANCE}} at the Issuance PEP, and from the presented token at the Resource
PEP ({{declared-mappings}}). Where {{ISSUANCE}} declines to compound a
datatype into an action name (a `datatypes` value containing a colon),
`cell.name` is the action alone.

The default asks about the location, so it aligns the two enforcement points
at the level of the class of resource only. A type that needs the RS to ask
about a specific resource declares a mapping ({{granularity}}).

# Declared Mappings {#declared-mappings}

A type definer MAY declare a mapping for a type. A declared mapping overrides
the default for every cell of every entry of that type, and for no other type.

`subject.id` is trust-anchored, enforced by verification. A declared mapping
MAY set `subject.id`; if it does, it MUST set it to `$token.sub`, and the PEP
MUST verify that the resolved value equals the authenticated subject: at the
Issuance PEP, the subject {{ISSUANCE}} places in the request; at the Resource
PEP, the `sub` claim of the presented token. A mismatch is a mapping error. If
a declared mapping omits `subject` or `subject.id`, the PEP supplies them as it
would for the default mapping.

A declared mapping using the `evaluations` envelope MUST NOT set `subject` in
any entry of its `evaluations` array; a PEP MUST treat one that does as a
mapping error.

Every attribute a declared mapping supplies other than the verified
`subject.id`, including `subject.type` and every `properties` member, is
untrusted input under Section 2.9 of {{COAZFW}}. A policy that grants on the
basis of an elevated role or privilege MUST rely on the verified `subject.id`,
not on a declared `subject.type`.

## Payment Initiation {#ex-payment}

The `payment_initiation` type of RFC 9396 Figure 2. The decision is about the
creditor and the amount, both type-specific members that the default mapping
does not reach. The declared mapping puts the creditor in the five-tuple and
the amount, a parameter of the act, in `action.properties`:

~~~ json
{
  "evaluation": {
    "action": {
      "name": "$cell.action",
      "properties": {
        "amount": "$detail.instructedAmount.amount",
        "currency": "$detail.instructedAmount.currency"
      }
    },
    "resource": {
      "type": "creditor_account",
      "id": "$detail.creditorAccount.iban"
    },
    "context": { "agent": "$token.?client_id" }
  }
}
~~~
{: #fig-payment title="A declared mapping for payment_initiation"}

A mapping can branch per action where actions concern different entities; a
`cancel` cell, for instance, might be asked about the payment rather than the
creditor. The CEL conditional operator serves for that, as COAZ-MCP's examples
show.

For the `initiate` cell of the Figure 2 entry, the Issuance PEP produces:

~~~ json
{
  "action": {
    "name": "initiate",
    "properties": { "amount": "123.50", "currency": "EUR" }
  },
  "resource": {
    "type": "creditor_account",
    "id": "DE02100100109307118603"
  },
  "context": { "agent": "fintech-app" }
}
~~~

When the client retries `POST /payments` with the token, the Resource PEP
projects the request body onto the same entry and produces the same
evaluation.

## Two Decisions per Cell {#ex-two}

A transfer type with no common data fields at all, so each entry is a single
cell with the substituted action `authorization_detail`. The mapping ignores
that action and asks two questions:

~~~ json
{
  "evaluations": {
    "context": { "agent": "$token.?client_id" },
    "evaluations": [
      {
        "action": {
          "name": "debit",
          "properties": {
            "amount": "$detail.instructed_amount.amount",
            "currency": "$detail.instructed_amount.currency"
          }
        },
        "resource": {
          "type": "account",
          "id": "$detail.debtor_account.account_id"
        }
      },
      {
        "action": {
          "name": "pay",
          "properties": {
            "amount": "$detail.instructed_amount.amount",
            "currency": "$detail.instructed_amount.currency"
          }
        },
        "resource": {
          "type": "pix_key",
          "id": "$detail.creditor_account.pix_key"
        }
      }
    ]
  }
}
~~~
{: #fig-two title="A declared mapping with two decisions per cell"}

## Class and Instance {#granularity}

The `customer_information` type of RFC 9396 Figure 5, with `identifier`
allowed. A client requesting a standing grant sends no `identifier`; a call to
`GET /customers/c-77/contacts` names one. The mapping asks about the
collection in the first case and about the customer in the second:

~~~ json
{
 "evaluation": {
  "action": { "name": "$cell.name" },
  "resource": {
   "type":
    "$has(detail.identifier) ? 'customer' : 'customer_information'",
   "id":
    "$has(detail.identifier) ? detail.identifier : cell.location"
  }
 }
}
~~~
{: #fig-class-instance title="One mapping, two levels of detail"}

At issuance the PDP is asked `read:contacts` on
`customer_information:https://example.com/customers`, which today's policy may
answer by role. At the RS it is asked `read:contacts` on `customer:c-77`, which
a policy may answer by the subject's relationship to that customer. The policy
can move from the first answer to the second without either enforcement point
changing, because the RS was asking about the instance all along. A PDP that
does not hold the relation between a customer and the collection can be given
it by the mapping, as a resource property set only when `identifier` is
present.

A token granted on the class does not cover every instance. A call about a
customer the subject has no relationship with is refused by the Resource PEP's
own evaluation, even though the token covers the call. When an RS remediates a
refused call ({{projection}}), the entry carries the `identifier`, and the AS
asks about the instance as well.

## MCP Tools as Authorization Details Types {#mcp-tools}

An MCP tool can be used as an authorization details type: its `type` is a URI
naming the tool, its members are the tool's arguments, and its schema is the
tool's input schema. If that input schema carries a COAZ-MCP `x-authzen-mapping`,
step 2 of {{declaring}} selects it, and the `params` variable lets it run
unchanged: `params.arguments` is the entry at the Issuance PEP and the
`tools/call` arguments at an MCP gateway, and `token.sub` is the authenticated
subject at both.

An MCP gateway that refuses a `tools/call` can therefore remediate with an
entry built from the call's arguments, and the AS evaluates, at issuance, the
call the gateway will see on retry. This gives issuance a decision on the
concrete arguments of a specific call, which it otherwise does not have.

# PEP Behavior {#pep-behavior}

## Issuance PEP

When an AS processes a token request carrying `authorization_details` under
{{ISSUANCE}}, it MUST, for each entry:

1. Apply any enrichment ({{enrichment}}).

2. Select the type's mapping ({{declaring}}).

3. Form the entry's cells ({{cells}}).

4. For each cell, populate the input variables ({{information-model}}),
   resolve the mapping, verify the trust-anchored `subject.id`
   ({{declared-mappings}}), and add the resulting evaluations to the batch in
   place of the evaluation {{ISSUANCE}} would form for that cell.

The AS then sends the batch, including the gate tuples {{ISSUANCE}} defines,
and composes the result as {{ISSUANCE}} defines, treating a cell as permitted
only if every evaluation the mapping produced for it is a permit. The response
shaping, no-broadening, and structural-check rules of {{ISSUANCE}} are
unchanged.

## Resource PEP

When an RS receives a call it authorizes under this binding, it MUST:

1. Validate the access token as it otherwise would.

2. Project the call onto an entry and a cell ({{projection}}).

3. Determine whether the token's `authorization_details` cover the projection,
   using the details the AS made available to it ({{Section 9 of RFC9396}}). If they do not, the RS SHOULD
   answer with the remediation challenge of {{RARMETA}}, built from the
   projection, and MUST NOT perform the call.

4. Select the type's mapping, populate the input variables, resolve the
   mapping, and verify the trust-anchored `subject.id`.

5. Send the constructed request to the PDP and permit the call only if every
   decision is a permit.

6. Before performing the call, confirm that the call's projection is
   unchanged from the one evaluated, as COAZ-MCP requires of a message, and
   re-evaluate or refuse it otherwise.

Step 3 asks whether the token covers the call; step 5 asks whether policy
permits it. Both are required. A token is evidence of what was granted at
issuance; it is not evidence that the call, as made, is permitted now.

# Error Handling {#errors}

The framework's three categories are reported as follows.

| Category | Issuance PEP | Resource PEP |
|---|---|---|
| Mapping error | `invalid_authorization_details` {{RFC9396}} | HTTP 500 |
| Authorization denial | As {{ISSUANCE}} defines for denied cells and gates | HTTP 403 |
| PDP communication error | As {{ISSUANCE}} defines: HTTP 503 with `Retry-After` | HTTP 503 |

A mapping error at the Issuance PEP is reported as
`invalid_authorization_details` because the entry, as received and enriched,
cannot be evaluated; the client can do nothing with it but change the entry.
An AS MUST NOT relay the text of a mapping error to the client, for the same
reason {{ISSUANCE}} forbids relaying PDP reasons.

A denial at the Resource PEP of a call the token covers is answered with HTTP
403 and not with a remediation challenge: no token would change the decision.
An RS MAY include an `error` value as {{RFC6750}} allows, and MUST NOT include
PDP reasons.

# Guidance for Mapping Authors {#guidance}

This section is non-normative.

| The member is | Put it in | Example |
|---|---|---|
| An entity the decision is about | `resource` (`type` and `id`) | `creditor_account:DE02...` |
| The specific resource, when the entry or call names one | `resource.id`, from `identifier` | `customer:c-77` |
| A quantity or parameter of the act | `action.properties` | `{"amount": "123.50", "currency": "EUR"}` |
| A second entity the act touches | A second evaluation | a debit of the source and a payment to the payee |
| A filter the client placed on its request | `resource.properties` | a sensitivity filter on a records request |
| An assertion about who is asking | `subject.properties` or `context` | a practitioner role |

Entities belong in the five-tuple because every PDP, including one that
reasons over relationships, can use them. A quantity does not: an amount has
no identity and no relationships, and a relationship-based engine takes such a
value as request context for a condition rather than as an object.
Section 5.3.1 of {{AUTHZEN}} provides for it directly: action properties "can include ...
parameters of the action that is being requested."

Do not reduce a value the policy might compare into a category in the mapping.
A mapping that sends `"sensitivity": "high"` for any amount over a threshold
lets the PDP distinguish small payments from large ones, but not 25,000 from
60,000. COAZ-MCP's discussion of authorization granularity applies equally
here: an input a mapping does not project is not evaluated by the PDP.

A filter the client places on its request (a set of sensitivity labels, say)
exists in the entry but not in a call, so the AS and RS will see different
properties for it. That is expected and is one reason decision-critical inputs
belong in the five-tuple.

An assertion about who is asking, carried in an entry, is client-supplied and
untrusted. The AS has to verify it against an authoritative source; the
mapping cannot make it trustworthy.

# Security Considerations

## Trust in the Type Definer

A declared mapping determines what the PDP is asked. A mapping that omits a
decision-critical member, or projects it lossily, yields permits that do not
reflect that member. An AS or RS that uses a type relies on the type definer
for its mapping, and the trust it places there is the same trust it already
places in the type's schema; deployments SHOULD review a mapping when adopting
a type, as they would review the schema.

A type definer that is also the RS addressed by the resulting token can, by a
poor mapping, only weaken tokens addressed to itself, provided the AS
restricts each token's audience to the evaluated resource as {{ISSUANCE}}
requires.

## Remediation Entries Are Client-Carried

The remediation entry passes through the client, which can alter it before
requesting a token. The AS evaluates the entry it receives, so an altered entry
yields at most a token for what the altered entry describes, and only if
policy permits that. When the call is retried, the RS projects it afresh and
checks both coverage and policy, so a token for an altered entry does not
cover the original call unless the alteration was immaterial to it.

## Staleness

A permit at issuance holds for the life of the token, and policy or
relationships can change in that time. The Resource PEP's evaluation on each
call is what bounds the consequence. This binding does not make an issuance
decision a substitute for a decision at the RS.

## Fail-Closed Enforcement

As the framework requires, a mapping error, a denial, or a PDP communication
failure results in the cell, and therefore the call or the corresponding part
of the grant, being refused.

# IANA Considerations

This document has no IANA actions.

{{RARMETA}} does not establish a registry for the members of an authorization
details type metadata object. Should it establish one, `authzen_mapping`
({{declaring}}) is a candidate for registration there.

--- back

# Relationship to Other Specifications

## COAZ Framework and COAZ-MCP

This document is a binding of {{COAZFW}} and follows the structure of
{{COAZMCP}}. It reuses COAZ-MCP's mapping location, the tool input schema, as
its second selection step, and its `params` variable, so that a tool's mapping
can be used unchanged.

## AuthZEN Profile for OAuth 2.0 Token Issuance

{{ISSUANCE}} defines the issuance decision this binding plugs into: the batch,
the gate tuples, the cell decomposition, and how decisions shape the token.
This binding replaces only the per-cell projection, and only for types that
declare a mapping. Its default mapping is that projection.

## OAuth 2.0 RAR Metadata and Error Remediation

{{RARMETA}} defines the types metadata endpoint where a mapping is published,
and the remediation challenge whose entry this binding builds from the RS's
projection. It defines no consumer of the types metadata within its own flow;
this binding adds two.

## OAuth 2.0 Authority Metadata

{{AUTHMETA}} publishes, in protected resource metadata {{RFC9728}}, what the
actions of a scope or authorization details type mean. That is information a
PDP can use when answering; a mapping is how a PEP forms the question. The two
are complementary and independent.

# Open Issues

This section is to be removed before publication. Each item is tracked as
an issue in the editor's repository.

1. Should the default mapping use `identifier` as `resource.id` when it is
   present? ([#15](https://github.com/ogazitt/oauth-authzen/issues/15)) Types built only from common data fields would then get
   instance-level questions at the RS without a declared mapping. The default
   can only use the type as `resource.type`, so a collection and its members
   would share a type and differ only by identifier.

2. {{RARMETA}} has no extension point for type metadata members, so
   `authzen_mapping` has no registered home. ([#16](https://github.com/ogazitt/oauth-authzen/issues/16))

3. A type that carries its multiplicity in a type-specific array ({{Section 2.1 of RFC9396}},
   Figure 4) cannot be decomposed: the framework forbids an expression from
   setting the number of decisions, and even a binding-defined fan-out would
   leave the AS unable to rebuild a narrower array from the permitted items
   without knowing the type. ([#17](https://github.com/ogazitt/oauth-authzen/issues/17))

4. Should the mapping be able to name the claims it requires of the
   prospective token, instead of relying on optional selection?
   ([#18](https://github.com/ogazitt/oauth-authzen/issues/18))

# Acknowledgments

The approach follows COAZ-MCP, by Atul Tulshibagwale and Alex Olivier, and
builds on Yaron Zehavi's work on authorization details type metadata and
remediation.

# Document History

## -00

* Initial version.

# Notices

Copyright (c) 2026 The OpenID Foundation.

The OpenID Foundation (OIDF) grants to any Contributor, developer, implementer,
or other interested party a non-exclusive, royalty free, worldwide copyright
license to reproduce, prepare derivative works from, distribute, perform and
display, this Implementers Draft, Final Specification, or Final Specification
Incorporating Errata Corrections solely for the purposes of (i) developing
specifications, and (ii) implementing Implementers Drafts, Final
Specifications, and Final Specification Incorporating Errata Corrections based
on such documents, provided that attribution be made to the OIDF as the source
of the material, but that such attribution does not indicate an endorsement by
the OIDF.

The technology described in this specification was made available from
contributions from various sources, including members of the OpenID Foundation
and others. Although the OpenID Foundation has taken steps to help ensure that
the technology is available for distribution, it takes no position regarding
the validity or scope of any intellectual property or other rights that might
be claimed to pertain to the implementation or use of the technology described
in this specification or the extent to which any license under such rights
might or might not be available; neither does it represent that it has made
any independent effort to identify any such rights. The OpenID Foundation and
the contributors to this specification make no (and hereby expressly disclaim
any) warranties (express, implied, or otherwise), including implied warranties
of merchantability, non-infringement, fitness for a particular purpose, or
title, related to this specification, and the entire risk as to implementing
this specification is assumed by the implementer. The OpenID Intellectual
Property Rights policy (found at openid.net) requires contributors to offer a
patent promise not to assert certain patent claims against other contributors
and against implementers. OpenID invites any interested party to bring to its
attention any copyrights, patents, patent applications, or other proprietary
rights that may cover technology that may be required to practice this
specification.
