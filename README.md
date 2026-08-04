<!-- regenerate: off (set to off if you edit this file) -->

# OAUTH Drafts

This is the working area for individual Internet-Drafts.

## AuthZEN Profile for OAuth 2.0 Token Issuance

* [Editor's Copy](https://ogazitt.github.io/oauth-authzen/#go.draft-gazitt-oauth-authzen-issuance.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-gazitt-oauth-authzen-issuance)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-gazitt-oauth-authzen-issuance)
* [Compare Editor's Copy to Individual Draft](https://ogazitt.github.io/oauth-authzen/#go.draft-gazitt-oauth-authzen-issuance.diff)

## AuthZEN Binding for OAuth 2.0 Token Exchange

* [Editor's Copy](https://ogazitt.github.io/oauth-authzen/#go.draft-gazitt-oauth-authzen-token-exchange.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-gazitt-oauth-authzen-token-exchange)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-gazitt-oauth-authzen-token-exchange)
* [Compare Editor's Copy to Individual Draft](https://ogazitt.github.io/oauth-authzen/#go.draft-gazitt-oauth-authzen-token-exchange.diff)

## Background

Both drafts are motivated at length in the series *Policy at the token
endpoint* at <https://notes.ogazitt.com>, which covers why an authorization
server's issuance decision has been left undefined by every specification
that depends on it, how a token request maps onto an authorization
decision, and what a policy decision point is and is not allowed to change
about the resulting token. The drafts are normative and stand on their own;
the posts carry the reasoning and the alternatives that were rejected.

## Contributing

See the
[guidelines for contributions](https://github.com/ogazitt/oauth-authzen/blob/main/CONTRIBUTING.md).

The contributing file also has tips on how to make contributions, if you
don't already know how to do that.

## Command Line Usage

Formatted text and HTML versions of the draft can be built using `make`.

```sh
$ make
```

Command line usage requires that you have the necessary software installed.  See
[the instructions](https://github.com/martinthomson/i-d-template/blob/main/doc/SETUP.md).

