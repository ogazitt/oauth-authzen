---
title: "AuthZEN Profile for OAuth 2.0 Token Issuance"
abbrev: "AuthZEN Token Issuance"
category: std
docname: draft-gazitt-oauth-authzen-issuance-latest
submissiontype: IETF
ipr: trust200902
area: "Security"
workgroup: "Web Authorization Protocol"
consensus: true
v: 3
keyword:
 - oauth
 - authorization
 - authzen
 - policy
 - token exchange
venue:
  group: "Web Authorization Protocol"
  type: "Working Group"
  mail: "oauth@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/oauth/"
  github: "ogazitt/oauth-authzen"

author:
 -
    fullname: "Omri Gazitt"
    organization: "Independent"
    email: "ogazitt@gmail.com"

normative:
  RFC6749:
  RFC7519:
  RFC8693:
  RFC9396:
  AUTHZEN:
    title: "Authorization API 1.0"
    target: "https://openid.net/specs/authorization-api-1_0-final.html"
    date: 2026-01-11
    author:
      - ins: "OpenID Foundation AuthZEN Working Group"
        org: "OpenID Foundation"

informative:
  RFC7515:
  RFC7643:
  RFC8176:
  RFC8707:
  RFC9068:
  RFC9470:
  RFC8126:
  RFC3553:
  RFC6755:
  RFC6924:
  I-D.brossard-oauth-rar-authzen:
  I-D.ietf-oauth-identity-chaining:
  I-D.ietf-oauth-identity-assertion-authz-grant:
  I-D.ietf-oauth-transaction-tokens:
  ARAP:
    title: "AuthZEN Access Request and Approval Profile 1.0"
    target: "https://openid.github.io/authzen/authzen-access-request-approval-profile-1_0"
    date: 2026-07-27
    author:
      - ins: K. McGuinness
        name: "Karl McGuinness"
        org: "Independent"
  ZANZIBAR:
    title: "Zanzibar: Google's Consistent, Global Authorization System"
    target: "https://www.usenix.org/conference/atc19/presentation/pang"
    date: 2019
    author:
      - ins: R. Pang
      - ins: R. Caceres
      - ins: M. Burrows

--- abstract

Numerous OAuth 2.0 specifications define a moment at which an authorization
server decides whether to issue a security token, and each of them declares
the decision itself to be a matter of local policy that is out of scope.
The result is that a decision common to every OAuth deployment has no
interoperable expression.

This document defines a profile for using the OpenID AuthZEN Authorization
API to externalize that decision to a Policy Decision Point. It specifies
how the inputs to a token issuance request map onto AuthZEN's mandatory
five-tuple, how a Policy Decision Point response may shape the issued token,
and how the two parties discover each other's capabilities.

The mapping is complete for grants whose request names a single party and a
single target, including the authorization code and client credentials
grants. Companion documents bind the grant families that add structure this
document does not model, the token exchange family first among them.

--- middle

# Introduction

Consider the moment an OAuth 2.0 authorization server (AS) has authenticated
a client, validated a grant, and must decide whether to mint a token - and
if so, with what scopes, what audience, what lifetime, and what claims.
Every specification that defines such a moment models its inputs in careful
detail and then stops short of the decision.

{{RFC8693}}, which defines OAuth 2.0 Token Exchange, is explicit that the
decision to issue is governed by policy it does not define. The
specifications built on top of it inherit that seam: identity chaining
({{I-D.ietf-oauth-identity-chaining}}), identity assertion authorization
grants ({{I-D.ietf-oauth-identity-assertion-authz-grant}}), and transaction
tokens ({{I-D.ietf-oauth-transaction-tokens}}) each describe an
"administrator-defined policy" or equivalent without describing how such a
policy is expressed, evaluated, or externalized.

Leaving the decision to local policy is the correct choice for those
documents. But it means that the single most security-relevant step in token
issuance is, today, an implementation detail - expressed in vendor-specific
rules engines, inline hooks, and scripting extensions that do not port
between authorization servers and cannot be reasoned about by anything
outside the AS.

{{AUTHZEN}} defines an interoperable API between a Policy Enforcement Point
(PEP) and a Policy Decision Point (PDP). This document profiles that API for
the token issuance moment, casting the **authorization server as a PEP**.

## Design Goals {#design-goals}

**One mechanism, many issuance moments.** The decision point is
structurally identical across grant types: a party is asking for a token,
naming a target and some set of privileges. This document defines that
mapping once. Bindings ({{companions}}) supply what is specific to a given
grant or token type, and are expected to be short.

**Interoperability at the level of policy, not just wire format.**
{{AUTHZEN}} makes exactly five fields mandatory in an evaluation request:
`subject.type`, `subject.id`, `action.name`, `resource.type`, and
`resource.id`. Everything else - the `properties` bag on each entity, and the
`context` object - is optional. That asymmetry is deliberate. It is what
allows one request shape to be understood by policy engines with very
different internal models: attribute- and policy-based engines that evaluate
expressions over arbitrary input, and relationship-based engines in the style
of {{ZANZIBAR}} that reason over a typed graph of subjects, relations, and
objects.

This is not a claim that a relationship-based engine can consume nothing
beyond the five-tuple. Such engines commonly accept contextual tuples
supplied at query time, and a PDP may project `properties` or `context` into
them. It is a claim about where a profile should put the load. The five-tuple
has a shape every conforming PDP can be expected to read the same way; a
free-form bag does not, and a profile that carried its decision-critical
inputs there would nominally use AuthZEN while leaving each PDP to infer the
semantics on its own.

This document therefore adopts a design rule:

> The five-tuple is the primary information model target. Every input on
> which the decision depends MUST be expressed in it. `properties` and
> `context` carry advisory input only, and a conforming mapping MUST be
> implementable by a PDP that reads only the five-tuple.

The rule is applied throughout and is not re-argued at each mapping.

**Least surprise for the AS.** The profile does not ask the AS to surrender
decisions it is authoritative for. A PDP may narrow what is issued; it may
not broaden it, re-subject it, or re-target it ({{no-broadening}}).

## Scope

This document covers **token issuance**: the decision made by an
authorization server at its token endpoint, before a token is minted. It
does not address enforcement at a resource server, which is the ordinary
case AuthZEN already serves and requires no profile.

The framework decides an **issuance gate**. Where a deployment's policy
depends on quantitative or transactional constraints - a payment amount, a
rate limit - those flow in as advisory context and out as token shaping
({{shaping}}), to be enforced by downstream policy enforcement points. Any
conforming PDP can adjudicate the gate, because the gate is expressed
entirely in the five-tuple. Whether a given PDP also adjudicates the context
is a property of that deployment and is not something this profile
guarantees. Stating that boundary is what keeps the design rule above from
overpromising.

## Requirements Language

{::boilerplate bcp14-tagged}

# Terminology

This document uses the terms Authorization Server, Client, Resource Server,
access token, and scope from {{RFC6749}}; Policy Decision Point (PDP),
Policy Enforcement Point (PEP), Subject, Action, Resource, and Context from
{{AUTHZEN}}.

Issuance target:
: The audience of the access being granted - the party the issued token
  authorizes its bearer to act against. Usually the value the AS intends for
  the token's `aud` claim.

Gate tuple:
: An evaluation request whose action expresses *issuance authority* - whether
  the subject may obtain a token of a given type for the issuance target.
  See {{gate-and-scope}}.

Scope tuple:
: An evaluation request whose action is a requested scope, expressing
  *access authority*. See {{gate-and-scope}}.

# Architecture

~~~ ascii-art
+--------+           +----------------------+        +-------+
| Client |           | Authorization Server |        |  PDP  |
+---+----+           |        (PEP)         |        +---+---+
    |                +----------+-----------+            |
    | 1. token req              |                        |
    +-------------------------->|                        |
    |                           | 2. authn client,       |
    |                           |    validate grant      |
    |                           |                        |
    |                           | 3. evaluation request  |
    |                           +----------------------->|
    |                           |                        |
    |                           | 4. decision + shaping  |
    |                           |<-----------------------+
    |                           |                        |
    |                           | 5. mint per decision   |
    |                           |    and shaping         |
    | 6. token response         |                        |
    |<--------------------------+                        |
~~~

Step 2 is unchanged from the underlying grant: the AS remains solely
responsible for authenticating the client, validating the grant or subject
token, and verifying any proof of possession. The PDP is consulted only
after those checks succeed. A PDP permit does not substitute for any of
them.

# Forming the Evaluation Request

## Subject

`subject` identifies the party the issued token will represent.

`subject.type` MUST be one of the registered values in {{iana-types}}:

* `user` - a natural person.
* `client` - an OAuth client acting on its own behalf.
* `workload` - a non-human software identity, such as a workload with a
  cryptographic identity document.

`subject.id` MUST be the identifier the AS intends to place in the issued
token's subject claim. Where the AS applies a transformation to subject
identifiers - pairwise or pseudonymous identifiers, or a mapping from an
external identity to a local account - that transformation MUST be applied
*before* the evaluation request is constructed, so that the identifier the
PDP authorizes is the identifier the token carries.

## Resource

`resource.type` MUST be `audience`. `resource.id` MUST be the issuance
target.

A single registered type is used rather than a type per kind of target
(service, trust domain, peer authorization server) because the type names
the *protocol role* the target plays, not a guess at its nature. Policies
written against `audience` port across deployments; policies written against
locally invented type names do not.

Where the request carries an explicit target - an `audience` parameter, or a
`resource` parameter in the sense of {{RFC8707}} - that value determines
`resource.id`. Where it does not, the AS's default audience for the grant
determines it.

## Actions: Gate Tuples and Scope Tuples {#gate-and-scope}

Token issuance asks two questions that are frequently conflated:

1. May this subject obtain *a token of this kind* for this target? This is
   **issuance authority**, and in delegation scenarios, delegation
   authority.
2. May this subject exercise *this scope* at this target? This is **access
   authority**.

These are distinct privileges. {{RFC8693}} defines a `may_act` claim
precisely because the authority to act on another party's behalf is not the
same as the authority to access a resource. A subject may legitimately be
permitted to hold an access token for an API while being forbidden from
minting a delegated grant aimed at that same API.

Because AuthZEN's information model provides exactly one action per
evaluation, these two questions MUST be expressed as separate evaluations
rather than as two interpretations of one `action.name`.

### Gate Tuple {#gate-tuple}

A gate tuple is an evaluation whose `action.name` has three colon-separated
segments:

~~~
issue:<token-type>:<grant-type>
~~~

where `<token-type>` and `<grant-type>` are short names registered in
{{iana-actions}} - for example `issue:access_token:authorization_code`,
`issue:id_token:authorization_code`, `issue:refresh_token:token_exchange`.

The `issue:` prefix is reserved. A deployment MUST NOT use a scope value
beginning with `issue:` as a scope tuple action.

The grant is part of the action because it is not recoverable from the rest
of the tuple and it is not implied by the token type. The same subject,
audience, and token type arise from an authorization code request and from
its later refresh, and from a client requesting a token for itself and that
same client exchanging for one. A policy that
distinguishes those cases - requiring fresh authorization at a high-value
audience, or permitting a client to hold a token but not to exchange for one
- has nothing to attach to unless the grant is in the five-tuple.

Neither segment subsumes the other. A single authorization code request may
mint an access token, a refresh token, and an ID token, which are separately
gateable; and a token exchange selects its output through
`requested_token_type`, so its token type is a variable of the request.
Together the two segments name one privilege: what may be minted, and by
what means.

### Action Name Portability {#action-portability}

Short names registered under {{iana-actions}} MUST match
`[a-z][a-z0-9_]{0,30}`, and a composed gate action name MUST NOT exceed 50
characters.

The bounds exist for portability. Relationship-based engines commonly
validate relation identifiers against a restricted grammar, admitting a small
character set within a modest length limit. A PDP built on such an engine can
canonicalize an action name defined by this document by replacing each `:`
with a character the grammar admits, conventionally `_`. The bounds above are
what make that transformation total: any registered name survives it, so a
policy written against these names ports without being rewritten.

Carrying a grant type URI verbatim would not survive it. The composed action
name would exceed the length limits such grammars impose before any question
of characters arose.

The guarantee covers only the vocabulary this document defines. Scope values
are carried verbatim ({{scope-tuple}}) and routinely contain characters no
such grammar admits; mapping them remains internal to the PDP.

### Scope Tuple {#scope-tuple}

A scope tuple is an evaluation whose `action.name` is a single requested
scope value, carried verbatim.

Scope values are not transformed into policy-engine relation names by the
AS. Any such mapping is internal to the PDP. This keeps `action.name` a
stable interface: the AS reports what the client asked for, and the PDP
decides what that means in its own policy vocabulary.

### Gate Tuples Are Always Present {#gate-required}

An AS MUST include a gate tuple in every evaluation request it forms under
this profile. A binding MAY require more than one ({{composition}}).

The floor is therefore two evaluations for a request naming scopes, and one
for a request naming none. Deployments are expected to write issuance policy
for every token type and grant combination their AS can produce; a PDP that
advertises support for this profile renders a decision on any registered gate
action it is sent ({{pdp-capabilities}}), so an AS never has to predict which
combinations a given PDP has policy for.

## Context

The `context` object carries advisory input. A conforming PDP MUST be able
to render a decision without it.

The following keys are defined by this document; bindings may define more:

| Key | Type | Value |
|---|---|---|
| `client_id` | string | The authenticated client identifier |
| `acr` | string | Authentication context class of the subject |
| `amr` | array of strings | Authentication methods, per {{RFC8176}} |
| `auth_time` | integer | Time of authentication, as in {{RFC7519}} |
| `cnf` | object | Confirmation method of the presented credential |

The single-type rule of {{envelope}} applies here as well: each key above has
one JSON type, and bindings defining further context keys MUST state a type
for each.

Per {{design-goals}}, any input on which the decision genuinely depends
belongs in the five-tuple, not here. The grant type is the worked example:
it is decision-critical, so it is a segment of the gate action name
({{gate-tuple}}) and does not appear in `context` at all.

## Batching and Result Composition {#composition}

Where a request yields more than one tuple, the AS MUST use the Access
Evaluations API of {{AUTHZEN}} with `options.evaluations_semantic` set to
`execute_all`, and MUST place gate tuples at the leading indices of the
`evaluations` array, beginning at index 0.

A request reduces to a single evaluation only when it names no scopes, in
which case the gate tuple stands alone.

This document produces exactly one gate tuple. Bindings may produce more:
the token exchange family evaluates the authority of the requesting party
separately from that of the subject, and so produces two.

`execute_all` is required because scope denials must be able to narrow the
grant rather than fail it: an AS that requested three scopes and received
two permits issues a token bearing two scopes, and reports the reduced set
in the `scope` response parameter as {{RFC6749}} already requires.

A gate denial, by contrast, is fatal. If any leading gate tuple has a
decision of `false`, the AS MUST fail the request and MUST NOT issue a
token, irrespective of the other results.

{{AUTHZEN}} evaluation semantics are selected per request and cannot mark an
individual batch item as a precondition, so this composition rule is
enforced by the AS. This is well within the PEP's role - the AS is already
interpreting per-item results in order to downscope.

Where the request named scopes and every scope tuple is denied, the AS MUST
fail the request rather than issue a token with an empty scope set, even
though the gate permitted it. A permitted gate authorizes a token of that
kind to exist; it does not authorize an empty one.

# Processing the Evaluation Response {#shaping}

A PDP MAY return, in the response `context`, information that shapes the
token the AS issues.

## The `issuance` Envelope {#envelope}

All keys defined by this profile appear within a single `issuance` member of
the response `context`:

~~~ json
{
  "decision": true,
  "context": {
    "reason_admin": { "200": "matched policy P-4471" },
    "issuance": {
      "token_lifetime": 300,
      "claims": { "groups": ["engineering"] }
    }
  }
}
~~~

An AS implementing this profile MUST process `context.issuance` and MUST
ignore unrecognized members outside it, preserving the advisory character
that {{AUTHZEN}} gives response context generally.

Every key defined below has exactly one JSON type, and bindings that define
further keys MUST do the same. Where the corresponding OAuth or JWT
construct admits more than one - `aud` is the notable case, per Section
4.1.3 of {{RFC7519}} - this profile picks one rather than carrying the
polymorphism forward. An AS validates the response context before acting on
it, and a union type costs more to validate, to schematize, and to project
into a typed representation than the shorthand saves.

## Mandatory-to-Understand {#mtu}

{{AUTHZEN}}, in the definitions of the `decision` values in its Decision
section, states that where a PEP does not understand information in the
response context, the PEP MAY reject the decision. That permission is
appropriate for a general-purpose API in which response context is advisory.
It is not sufficient here, because the consequences are asymmetric:

* Ignoring a key that **narrows** the grant yields a token **broader than
  the PDP authorized** - a silent privilege escalation.
* Ignoring a key that **adds** information yields a token narrower than
  intended - a functional shortfall, not a security failure.

This profile therefore adopts the following rule, from which the treatment
of every key below is derived:

> A response-context key is mandatory-to-understand if and only if ignoring
> it would produce a token broader than the PDP authorized. For such keys,
> an AS that does not understand and apply the key MUST treat the permit as
> a denial.

## No Broadening {#no-broadening}

A PDP MUST NOT return a shaping value that grants access the AS would not
otherwise have granted, and an AS MUST reject a decision that attempts it.

The PDP decides whether and how much; it does not decide what else. Without
this rule, an evaluation of `files.read` could return a token bearing
`admin`, and the token would assert a privilege no evaluation ever
considered.

## Constraining Keys

The keys in this section are mandatory-to-understand under {{mtu}}.

### `granted_scope`

A space-delimited string in the syntax of the `scope` parameter of
{{RFC6749}}, giving the scope set the AS is authorized to grant.

`granted_scope` MUST be a subset of the scopes the AS would otherwise have
granted - the requested scopes, or for a request naming none, the AS's
default set for that client and target. The AS MUST reject the decision
otherwise.

Its principal use is the gate-only evaluation, where there are no scope
tuples and this key is how a PDP answers "permit, and grant this set."
Enumerating a grantable set is a search operation rather than a check; a PDP
unable to perform it returns a bare permit and the AS falls back to its own
defaults, which is a safe degradation.

Where scope tuples are present, the per-item decisions already express
downscoping, and a PDP SHOULD NOT also return `granted_scope`.

### `token_lifetime`

A non-negative integer number of seconds, interpreted as a **ceiling**. The
AS MUST issue a token whose lifetime is the lesser of this value and the
lifetime it would otherwise have used. It is never a floor: a PDP cannot
extend a token's life beyond the AS's own policy.

A value of `0` MUST be treated as a denial rather than as an instruction to
mint an already-expired token.

### `audience`

An array of strings, narrowing the set of targets for which the token may be
issued. Each value MUST appear among the `resource.id` values of the
permitted evaluations.

The value is an array even when it names a single target. This is the key
where the single-type rule above is most visible, and where it also makes
the aggregation rule of {{aggregation}} state plainly: intersection is an
operation over sets. An AS remains free to render a single-element set as a
bare string in the token's own `aud` claim, where {{RFC7519}} permits it.

Where the resulting set is empty, the AS MUST fail the request; for token
exchange requests the appropriate error is `invalid_target` ({{RFC8693}}).

### `authorization_details`

An array in the syntax of {{RFC9396}}, replacing - not merged with - the
authorization details of the request.

Replacement admits arbitrary structured narrowing, which is what a PDP
filtering rich authorization requests needs, but "narrower" is not decidable
for arbitrary authorization detail types. This profile therefore requires:

* **Structural check, always.** Every returned entry MUST have a `type`
  present in the request, and its `locations`, `actions`, and `datatypes`
  members MUST be subsets of the corresponding members of the request entry
  of that type. The AS MUST reject the decision otherwise.
* **Type-specific members.** For members beyond those defined in
  {{RFC9396}}, the AS MUST either apply a validator specific to that
  authorization details type or reject the decision. An AS MUST NOT pass
  unvalidated structure into an issued token.

### `crit`

An array of strings naming members of `claims` ({{claims}}) that are
themselves mandatory-to-understand. The name and semantics are taken from
the `crit` header parameter of {{RFC7515}}: an AS that does not understand
and apply a named member MUST treat the permit as a denial.

`crit` exists because the static classification in this section is
incomplete. An additive claim is normally safe to ignore, except where the
claim *is* a constraint that a downstream enforcement point is expected to
apply - a ceiling asserted by policy, for instance. Dropping such a claim
broadens what the token effectively authorizes.

A PDP MUST NOT include `crit` unless the AS has declared support for the
corresponding capability ({{discovery}}).

## Decorating Keys

### `claims` {#claims}

An object whose members are claim names, in the sense of {{RFC7519}}, and
the values to be included in the issued token. This is the mechanism by
which policy-derived attributes reach the token - group memberships, roles,
and entitlements of the kind {{RFC9068}} describes for JWT access tokens,
drawn from the schema of {{RFC7643}}.

Members of `claims` are advisory under {{mtu}}: an AS that drops them issues
a less capable token. A PDP that requires a member to be honored MUST name
it in `crit`.

A PDP MUST NOT set, and an AS MUST reject a response that sets, any of the
following claims:

| Reserved | Rationale |
|---|---|
| `iss`, `iat`, `jti` | Provenance, for which the AS is authoritative |
| `sub` | It is `subject.id`, an input to the decision |
| `aud` | It is `resource.id`, an input to the decision |
| `exp`, `nbf` | Expressed by `token_lifetime` |
| `scope` | Expressed by `granted_scope` |
| `client_id` | Established by client authentication |
| `cnf` | Derived from a proof of possession the AS verified |
| `act` | Delegation chain, constructed by the AS |
| `authorization_details` | Has its own key and narrowing rules |
| `may_act` | Confers future delegation authority; broadening by construction |

The reservation of `sub` and `aud` is the load-bearing one. Both are inputs
to the five-tuple; a PDP that could rewrite either would cause the AS to
issue a token corresponding to a decision that was never evaluated.
Re-subjecting a token is a fresh issuance, not an attenuation of an existing
one, and MUST be evaluated as such.

## Aggregation Across a Batch {#aggregation}

An Access Evaluations response in {{AUTHZEN}} carries no top-level context;
each element of the `evaluations` array is a decision with its own optional
context. Token shaping, however, is a property of the token: there is one
lifetime, one claim set, one authorization details array for the token being
minted, while this profile fans scopes and targets out across many
evaluations.

An AS MUST therefore compose per-item shaping as follows:

| Key | Aggregation |
|---|---|
| `token_lifetime` | Minimum over permitted items |
| `granted_scope` | Union over permitted items, intersected with what the AS would otherwise grant |
| `audience` | Intersection over permitted items |
| `authorization_details` | Union of entries, then the per-entry structural check |
| `claims` | Merge; see below |
| `crit` | Union |

Shaping keys appearing in the context of a **denied** item MUST be ignored.

Where two permitted items return different values for the same member of
`claims`, the AS MUST reject the decision. There is no general narrowing
merge for arbitrary JSON values, and choosing one arbitrarily could
broaden the result. Identical values are not a conflict. A PDP SHOULD return
token-level shaping on a single item to avoid the situation.

# Discovery {#discovery}

## Policy Decision Point Capabilities {#pdp-capabilities}

A PDP supporting this profile MUST advertise the capability URN registered
in {{iana-capability}} in the `capabilities` member of its metadata document,
retrievable at `/.well-known/authzen-configuration`:

~~~ json
{
  "policy_decision_point": "https://pdp.example.com",
  "access_evaluation_endpoint":
      "https://pdp.example.com/access/v1/evaluation",
  "capabilities": [
    "urn:ietf:params:authzen:token-issuance"
  ]
}
~~~

The URN asserts support for the request mapping and response vocabulary of
this document. It is not a statement about the content of the PDP's policy,
and a PDP MUST NOT be read as claiming to hold rules for any particular
issuance. What a deployment's policy permits is disclosed only through
decisions. This is the same line
{{I-D.ietf-oauth-identity-assertion-authz-grant}} draws for
`authorization_grant_profiles_supported`, which indicates that a server
implements a profile's processing rules and not that any particular issuer,
client, subject, or audience will be accepted.

Advertising the capability is accordingly a commitment to the request shapes
this profile can produce. A PDP that advertises it MUST render a decision for
a gate tuple naming any action name composable from the short names
registered in {{iana-actions}}, and MUST NOT reject the evaluation on the
grounds that it holds no policy for that action. Denying is a decision; a
protocol error is not. The same applies to a batch that mixes a gate tuple
with scope tuples, which is the ordinary shape of a request naming scopes
({{composition}}).

The obligation matters because the gate vocabulary is a product of two
registries and grows as bindings register short names. An AS pairs the token
type it is about to mint with the grant it received; it cannot know which
pairings a given deployment's policy anticipated, and must not have to.

For the same reason, this profile defines one capability URN rather than one
per token type and grant combination. Finer granularity would oblige the AS
to predict what the PDP has policy for, which the rule above exists to avoid,
and would publish the shape of a deployment's issuance policy in an
unauthenticated metadata document. Capability granularity in this profile
tracks vocabulary, not policy. An extension that adds response vocabulary
registers its own URN, since an AS must understand what it is asked to
enforce; one that adds only advisory context keys or new registered action
names does not, since a PDP ignores a context key it does not recognize and
the rule above already obliges it to decide any registered gate action.

An operator enabling a new grant or token type nonetheless has a real
question to answer: whether the deployment's policy anticipates the gate
actions the AS is about to start sending, or whether every such request will
be denied. That question is about policy content, so its answer belongs on
the authenticated evaluation surface rather than in metadata; {{AUTHZEN}}
notes that an unauthenticated PDP can be probed for the shape of its policy.
The Action Search API of {{AUTHZEN}} answers it directly: a search for a
representative subject and an `audience` resource returns the action names
policy would permit, and gate actions among them indicate the issuances the
deployment is prepared for. This is a deployment-time check, not a
per-request one, and nothing in this profile requires it.

## Policy Enforcement Point Capabilities

An AS MAY declare the capabilities it understands in the request context,
using the same URNs:

~~~ json
{
  "subject":  { "type": "user", "id": "U0405936" },
  "action":   { "name": "issue:access_token:authorization_code" },
  "resource": {
    "type": "audience",
    "id": "https://api.example/files"
  },
  "context": {
    "issuance": {
      "capabilities": [
        "urn:ietf:params:authzen:token-issuance"
      ]
    }
  }
}
~~~

Capability URNs are reused on both legs rather than introducing a list of
key names, so that extensions obtain granularity from the registry rather
than from a second, parallel mechanism.

The declaration is an optimization, not a safety mechanism, and this is why
it is OPTIONAL. Safety is already unilateral: a PDP that marks a key `crit`
obliges any AS implementing this profile to fail closed if it does not
understand it ({{mtu}}), and an AS that does not implement this profile
ignores the `issuance` envelope entirely, `crit` included. Withholding `crit`
from an undeclared AS therefore protects nothing. What the declaration buys a
PDP is the ability to choose a decision the AS can actually enforce -
denying, say, rather than permitting subject to a constraint it knows will be
discarded. That is worth having as extensions add vocabulary, and worth
nothing in a deployment using only the keys defined here.

An AS is not otherwise required to announce itself. The behaviors this
profile depends on - treating a gate denial as fatal, narrowing to the
permitted scope subset - are constitutive of implementing it rather than
features an AS might separately lack, and {{AUTHZEN}} already assumes a PDP
trusts its PEP to enforce what it decides.

The declaration describes the AS's implementation and MUST NOT be treated as
an authorization input. A PDP that varied its decision based on it would be
allowing a property of the enforcement point to influence policy.

# Error Mapping

| Condition | Authorization server behavior |
|---|---|
| Gate tuple denied | Fail the request; do not issue |
| All scope tuples denied | Fail the request; `invalid_scope` |
| Some scope tuples denied | Issue with the permitted subset; report via `scope` |
| Target denied or empty audience set | `invalid_target` ({{RFC8693}}) |
| Shaping key violates {{no-broadening}} | Treat as denial; fail the request |
| Unknown `crit` member | Treat as denial; fail the request |
| PDP unreachable or malformed response | Fail closed; do not issue |

Reason information returned by a PDP is diagnostic and intended for the
operator of the AS. An AS MUST NOT relay PDP reason strings to the client,
as they may disclose policy structure to a party that is not authorized to
learn it.

Where a PDP returns a denial accompanied by authentication requirements -
the step-up pattern of {{AUTHZEN}}, in which required `acr` and `amr` values
are named - an AS SHOULD surface this to the client. This document does not
define that mapping: `insufficient_user_authentication` in {{RFC9470}} is
defined for resource servers rather than for the token endpoint, and no
equivalent signal exists there. This is an open item.

# Examples

The first example below is shown in full, framed against the HTTPS JSON
binding of {{AUTHZEN}}. The remaining examples show only the JSON payload.

The transport is a property of the deployment, not of this profile: an
evaluation carrying the mapping defined here is the same evaluation whatever
binding conveys it. Where the HTTPS JSON binding is in use, the request URL
is the PDP's `access_evaluations_endpoint`, or `access_evaluation_endpoint`
for a request that reduces to a single evaluation, as published in the PDP's
metadata; the paths shown below are the defaults that apply when metadata
provides no value.

## Client Credentials, One Scope

One scope is requested, so the request is the gate tuple and one scope
tuple. This is the floor: two evaluations, so the Access Evaluations API.

~~~ http-message
POST /access/v1/evaluations HTTP/1.1
Host: pdp.example.com
Content-Type: application/json
Authorization: Bearer <token>

{
  "subject":  { "type": "client", "id": "svc-reporting" },
  "resource": {
    "type": "audience",
    "id": "https://telemetry.example"
  },
  "context": {
    "client_id": "svc-reporting",
    "issuance": {
      "capabilities": [
        "urn:ietf:params:authzen:token-issuance"
      ]
    }
  },
  "evaluations": [
    {
      "action": {
        "name": "issue:access_token:client_credentials"
      }
    },
    { "action": { "name": "telemetry.write" } }
  ],
  "options": { "evaluations_semantic": "execute_all" }
}
~~~

~~~ http-message
HTTP/1.1 200 OK
Content-Type: application/json

{
  "evaluations": [
    {
      "decision": true,
      "context": { "issuance": { "token_lifetime": 900 } }
    },
    { "decision": true }
  ]
}
~~~

## Authorization Code, Downscoping

Three scopes are requested. The gate leads at index 0 and `execute_all`
allows the AS to issue the permitted subset of the rest.

~~~ json
{
  "subject":  { "type": "user", "id": "U0405936" },
  "resource": {
    "type": "audience",
    "id": "https://api.example/files"
  },
  "context": {
    "client_id": "chatterbox",
    "acr": "urn:example:loa:2",
    "issuance": {
      "capabilities": [
        "urn:ietf:params:authzen:token-issuance"
      ]
    }
  },
  "evaluations": [
    {
      "action": {
        "name": "issue:access_token:authorization_code"
      }
    },
    { "action": { "name": "files.read"   } },
    { "action": { "name": "files.write"  } },
    { "action": { "name": "files.delete" } }
  ],
  "options": { "evaluations_semantic": "execute_all" }
}
~~~

~~~ json
{
  "evaluations": [
    { "decision": true },
    {
      "decision": true,
      "context": {
        "issuance": { "claims": { "groups": ["engineering"] } }
      }
    },
    { "decision": true },
    {
      "decision": false,
      "context": { "reason_admin": { "403": "policy P-118" } }
    }
  ]
}
~~~

The AS issues a token bearing `files.read files.write`, a `groups` claim,
and reports the reduced scope set in the token response.

Had the same subject arrived at the same audience with the same scopes on a
refresh, index 0 would have read
`issue:access_token:refresh_token`, and a policy that requires fresh
authorization here could deny it while leaving the scope tuples untouched.

## No Scopes Requested

No scopes and no default set, so the gate tuple stands alone. This is the
only shape this document produces that is a single evaluation, and it is
therefore the only one sent to the Access Evaluation API rather than the
Access Evaluations API: the payload is a bare evaluation with no
`evaluations` array, and under the HTTPS JSON binding it is a `POST` to
`/access/v1/evaluation`.

~~~ json
{
  "subject":  { "type": "client", "id": "svc-reporting" },
  "action":   {
    "name": "issue:access_token:client_credentials"
  },
  "resource": {
    "type": "audience",
    "id": "https://telemetry.example"
  },
  "context": {
    "issuance": {
      "capabilities": [
        "urn:ietf:params:authzen:token-issuance"
      ]
    }
  }
}
~~~

~~~ json
{
  "decision": true,
  "context": {
    "issuance": {
      "granted_scope": "telemetry.write",
      "token_lifetime": 900
    }
  }
}
~~~

# Relationship to Companion Documents {#companions}

This document defines the mapping and the shaping vocabulary, and registers
short names for the grant types listed in {{iana-actions}}. For a grant whose
request names a single party and a single target, that is everything an AS
needs; the client credentials and authorization code examples above are
complete, and no companion document is required to implement them.

A binding is required where a grant family adds structure this document does
not model. The token exchange family adds two such things: a request names a
second party, the requesting party, whose authority is separately at stake;
and several of its members issue an artifact whose own audience differs from
the audience of the access it describes. Bindings are therefore expected for
that family - including identity chaining, identity assertion authorization
grants, and transaction tokens - and a profile describing the use of AuthZEN
search operations to populate the authorization claims of {{RFC9068}}.

Bindings specify the subject derivation for their grant, any additional
context keys, the token type short names they register, and any invariants
of their own that a PDP cannot override.

## Related Work {#related}

Two other efforts place an AuthZEN Policy Decision Point behind an
authorization server.

{{I-D.brossard-oauth-rar-authzen}} carries an AuthZEN request and response
inside `authorization_details`, placing the evaluation on the OAuth wire. It
has expired. This document does not adopt that approach: the evaluation
stays between the authorization server and its Policy Decision Point, and
the client sees only an OAuth response.

{{ARAP}} defines what happens when a Policy Decision Point denies a request
but marks the denial as requestable: the enforcement point submits an access
request, an approval is obtained out of band, and a fresh evaluation is
performed so that the Policy Decision Point remains authoritative at
enforcement time. That profile deliberately does not bind the loop to OAuth,
requiring instead that a separate profile define a completion mode
appropriate to the flow. The AuthZEN Working Group's Access Request OAuth
Profile supplies that completion mode, and it governs the same moment as
this document.

The two divide along the value of `decision`. The approval work specifies
the deny path: a requestable denial becomes an asynchronous approval, and
issuance follows the re-evaluation. This document specifies the allow path:
how the evaluation request is formed, and how a permit may narrow what is
issued. The approval work therefore already establishes that response
`context` shapes issuance; it does so for approval state, where this
document does so for the granted authorization.

Because both must construct an evaluation request from an OAuth token
request, that construction is shared surface, and its treatment in the
approval profiles is deliberately brief, being incidental to their subject.
Where the two overlap, this document is intended to supply the detail rather
than to compete, and aligning the two is expected work.

# Security Considerations

## Fail Closed

Every failure of the profile - an unreachable PDP, a malformed response, a
shaping value that violates {{no-broadening}}, an unrecognized `crit`
member - MUST result in no token being issued. A PDP that cannot be
consulted is not an authorization to proceed.

Because the PDP is on the token issuance path, its availability becomes the
AS's availability. Deployments should consider caching of decisions, local
policy fallback that is explicitly configured rather than implicit, and the
latency budget of the token endpoint.

## The Policy Decision Point as a Trust Dependency

A PDP that can shape tokens can narrow every grant an AS issues, and a
compromised PDP can deny service. The constraints in this document bound the
damage in the other direction: because no shaping key may broaden a grant,
because `sub`, `aud`, and `cnf` are reserved, and because the AS validates
every constraining key before applying it, a compromised PDP cannot cause an
AS to issue a token for a different subject, aimed at a different audience,
bound to a different key, or bearing a privilege that no evaluation
considered.

This is why the reservations in {{claims}} are normative rather than
advisory. An implementation that passed PDP-supplied claims into a token
without checking them against that list would give the PDP the ability to
mint arbitrary identities.

## Integrity of the Decision Response

The `crit` mechanism relies on the response arriving intact. An attacker
able to strip `crit` from a response is also able to change `decision` to
`true`, so `crit` does not extend the attack surface beyond what transport
protection between the AS and the PDP must already cover. It is not a
substitute for that protection, and deployments requiring non-repudiation of
decisions should use the response signing mechanisms of {{AUTHZEN}}.

## Privacy

Evaluation requests carry subject identifiers, client identifiers, targets,
and authentication context to the PDP, and do so on every token issuance.
Where the PDP is operated by a party other than the operator of the AS, this
is a disclosure of authentication and access patterns for every user of the
system.

Requiring that identifier transformations be applied before the request is
constructed ({{iana-types}} and the subject rules above) means that a PDP
receiving pairwise or pseudonymous identifiers sees only the identifier the
token itself will carry, rather than a durable global identifier. Deployments
sensitive to this should prefer such identifiers.

Where `context` conveys authentication context or device posture, deployments
should include only what their policies actually consume. The design rule of
{{design-goals}} already bounds how much that ought to be.

# IANA Considerations

The registrations requested by this document fall into two groups with
different dependency properties, described in {{iana-deps}}.

## Registration Dependencies {#iana-deps}

The capability registration in {{iana-capability}} is an entry in a registry
established by another body's specification, and inherits that registry's
state. The two registries created in {{iana-types}} and {{iana-actions}} are
new registries created by this document, and have no such dependency.

{{AUTHZEN}} Section 12 asks IANA for two things: an `authzen` sub-namespace of
`urn:ietf:params` under {{RFC3553}}, and an "AuthZEN Policy Decision Point
Capabilities" registry whose entries are named as URNs within that
sub-namespace. At the time of writing, neither appears in the IANA registries.
The `urn:ietf:params` sub-namespace registry has a registration policy of IETF
Review {{RFC6924}}, which a specification published outside the IETF stream
cannot satisfy on its own.

This document is on the IETF stream, and therefore can. Two resolutions are
available, and the choice is for the working group:

1. This document, or a companion document, performs the {{RFC3553}}
   registration of the `authzen` sub-namespace, satisfying IETF Review. The
   capability name then takes the form given in {{iana-capability}}.

2. This document declines the dependency and registers its capability under
   `urn:ietf:params:oauth`, the sub-namespace established by {{RFC6755}},
   whose registration policy is Specification Required and is therefore not
   blocked. The capability name would be
   `urn:ietf:params:oauth:authzen-capability:token-issuance`.

Option 1 is preferable. A capability identifier is only useful if both parties
compute the same string, and one naming scheme for all AuthZEN capabilities is
worth more than this document's independence from it. Option 2 is the fallback
if the sub-namespace registration does not proceed.

## AuthZEN Policy Decision Point Capability {#iana-capability}

IANA is requested to register the following in the "AuthZEN Policy Decision
Point Capabilities" registry established by {{AUTHZEN}}, subject to
{{iana-deps}}:

Capability Name:
: `:token-issuance`

Capability URN:
: `urn:ietf:params:authzen:token-issuance`

Capability Description:
: Support for the OAuth 2.0 token issuance profile, comprising the request
  mapping and the `issuance` response context vocabulary.

Change Controller:
: IETF

Specification Document(s):
: This document

> **Editor's note.** {{AUTHZEN}} requires capability names to begin with a
> colon but gives no worked example of the resulting URN, so the rendering
> above is inferred. It should be confirmed against the registry as
> established and against the first registrations made in it.

## Issuance Authorization Entity Types Registry {#iana-types}

IANA is requested to establish the "OAuth Token Issuance Authorization
Entity Types" registry, with a registration policy of Specification Required
{{RFC8126}}, containing the following initial entries:

| Type | Applies to | Description |
|---|---|---|
| `user` | subject | A natural person |
| `client` | subject | An OAuth client acting on its own behalf |
| `workload` | subject | A non-human software identity |
| `audience` | resource | The audience of the access being granted |

## Issuance Authorization Action Names Registry {#iana-actions}

IANA is requested to establish the "OAuth Token Issuance Authorization
Action Names" registry, with a registration policy of Specification Required
{{RFC8126}}, for the two short-name vocabularies from which action names in
the reserved `issue:` space are composed.

A gate action name is `issue:<token-type>:<grant-type>`, so the registry
grows with the number of token types plus the number of grant types, not
with their product. The combinations that are meaningful in a deployment are
a matter of policy, not of registration.

Every short name MUST match `[a-z][a-z0-9_]{0,30}`, and a composed action
name MUST NOT exceed 50 characters. {{action-portability}} gives the reason:
these bounds are what let the name be transformed mechanically into a
relation identifier that relationship-based engines accept. Registrants
should note that the hyphen is excluded deliberately, and that a short name
therefore differs from the corresponding URI wherever that URI contains one.

Token type short names, initially:

| Short name | Token type |
|---|---|
| `access_token` | `urn:ietf:params:oauth:token-type:access_token` |
| `refresh_token` | `urn:ietf:params:oauth:token-type:refresh_token` |
| `id_token` | `urn:ietf:params:oauth:token-type:id_token` |

Grant type short names, initially:

| Short name | Grant type |
|---|---|
| `authorization_code` | `authorization_code` |
| `client_credentials` | `client_credentials` |
| `refresh_token` | `refresh_token` |
| `token_exchange` | `urn:ietf:params:oauth:grant-type:token-exchange` |
| `device_code` | `urn:ietf:params:oauth:grant-type:device_code` |
| `jwt_bearer` | `urn:ietf:params:oauth:grant-type:jwt-bearer` |
| `saml2_bearer` | `urn:ietf:params:oauth:grant-type:saml2-bearer` |

Registrations MUST give the URI or parameter value the short name
corresponds to, and MUST state which of the two vocabularies they join.
Names outside the `issue:` prefix are not registered here, since scope
values are carried verbatim and are not a registered vocabulary.

--- back

# Acknowledgments
{:numbered="false"}

This work was motivated in part by Karl McGuinness, whose initiative to
bridge OAuth and AuthZEN - in {{ARAP}} and its OAuth completion mode -
established that a Policy Decision Point belongs behind the token endpoint,
and that the response of such a Policy Decision Point may legitimately shape
what is issued. This document takes up the other half of that decision.

Thanks also to the participants in the OpenID AuthZEN interoperability
events, whose December 2025 identity provider scenario demonstrated AuthZEN
search operations populating token claims, and to the members of the AuthZEN
Working Group and the OAuth Working Group.
