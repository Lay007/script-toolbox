# Security Policy

`script-toolbox` contains scripts that can change Windows configuration, SSH access, user accounts, installer state and developer tools. Treat every script as infrastructure code.

## Supported scope

Security-sensitive areas include:

- SSH server and client configuration;
- user creation and local group membership;
- key files, `authorized_keys`, `administrators_authorized_keys` and ACLs;
- installer download URLs and bootstrapper validation;
- PATH and environment modification;
- scripts that run with elevated PowerShell.

## Reporting a security issue

Do not open a public issue for secrets, credentials or exploitable configuration mistakes.

Preferred report content:

- affected script or documentation path;
- expected safe behavior;
- observed unsafe behavior;
- reproduction steps on a non-production machine;
- suggested mitigation if known.

If no private reporting channel is available, create a minimal public issue that describes the area without exposing secrets or exploit details.

## Safety expectations

Contributions should follow these rules:

- never commit private keys, passwords, tokens or machine-specific secrets;
- do not disable authentication protections without explicit documentation;
- keep password login and key-only login changes clearly documented;
- validate downloaded files before execution where practical;
- avoid hidden remote code execution patterns;
- preserve a recovery path for SSH and remote-access changes;
- use clear warnings for scripts that require elevation.

## SSH hardening notes

When changing SSH-related scripts:

- keep an active console or RDP session while testing;
- verify key-based login before disabling password authentication;
- apply strict ACLs to private keys and authorized key files;
- document affected config files;
- avoid overwriting unmanaged configuration without a backup or managed block.

## Installer safety notes

When changing installer scripts:

- prefer official package managers or official vendor URLs;
- document source URLs;
- detect short-link or HTML error responses;
- check digital signatures where practical;
- support download-only or dry-run behavior when possible.

## Non-goals

This repository does not provide a general-purpose endpoint security baseline. It is a toolbox for repeatable setup tasks, and every script should be reviewed before production use.
