+++
title="Use SSH keys for private repository access"
weight=4
summary="Access private Git repositories during build using SSH keys."
+++

When your application has dependencies in private Git repositories, you can use SSH keys to authenticate during the build process.

<!--more-->

## Overview

Many applications require access to private Git repositories during the build process, such as:
- Private npm packages
- Private Go modules
- Private Git submodules
- Private Maven or Gradle dependencies

This guide shows how to securely pass SSH keys to buildpacks during the build.

## Using volume mounts for SSH keys

The most secure approach is to mount your SSH key as a read-only volume during the build.

### Prerequisites

- An SSH key pair configured for your private repository (e.g., GitHub, GitLab, Bitbucket)
- The private key file accessible on your build machine

### Example: Mounting SSH keys

Create a directory with your SSH configuration:

```bash
mkdir -p /tmp/ssh-keys
cp ~/.ssh/id_rsa /tmp/ssh-keys/
cp ~/.ssh/known_hosts /tmp/ssh-keys/
chmod 600 /tmp/ssh-keys/id_rsa
```

Then mount this directory during the build:

```bash
pack build my-app \
    --builder paketobuildpacks/builder-jammy-base \
    --volume /tmp/ssh-keys:/home/cnb/.ssh:ro \
    --path ./my-app
```

> **Note:** The SSH key is mounted read-only (`:ro`) to prevent any modifications during the build.

## Using environment variables for Git tokens

An alternative to SSH keys is using personal access tokens via environment variables:

```bash
pack build my-app \
    --builder paketobuildpacks/builder-jammy-base \
    --env "GIT_TOKEN=<your-personal-access-token>" \
    --path ./my-app
```

Your buildpack or application can then configure Git to use this token:

```bash
git config --global url."https://${GIT_TOKEN}@github.com/".insteadOf "git@github.com:"
```

## Using SSH agent forwarding (Docker only)

If you're running Docker on Linux, you can forward your SSH agent:

```bash
pack build my-app \
    --builder paketobuildpacks/builder-jammy-base \
    --volume $SSH_AUTH_SOCK:/ssh-agent:ro \
    --env "SSH_AUTH_SOCK=/ssh-agent" \
    --path ./my-app
```

> **Warning:** SSH agent forwarding may not work on all platforms (e.g., Docker Desktop on macOS or Windows).

## Security considerations

When working with SSH keys and tokens during builds:

1. **Never commit secrets to your repository** - Use environment variables or volume mounts instead
2. **Use read-only mounts** - Mount SSH keys as read-only to prevent modifications
3. **Use deploy keys when possible** - Deploy keys have limited scope compared to personal SSH keys
4. **Rotate credentials regularly** - Periodically update your SSH keys and access tokens
5. **Use short-lived tokens** - When possible, use tokens with short expiration times

## Troubleshooting

### SSH key permissions

If you encounter permission errors, ensure your SSH key has the correct permissions:

```bash
chmod 600 /path/to/your/private-key
```

### Known hosts verification

To avoid host key verification prompts, include a `known_hosts` file:

```bash
ssh-keyscan github.com >> /tmp/ssh-keys/known_hosts
```

### Debugging SSH connections

To debug SSH connection issues, you can set the `GIT_SSH_COMMAND` environment variable:

```bash
pack build my-app \
    --builder paketobuildpacks/builder-jammy-base \
    --volume /tmp/ssh-keys:/home/cnb/.ssh:ro \
    --env "GIT_SSH_COMMAND=ssh -vvv" \
    --path ./my-app
```

This will provide verbose SSH debugging output during the build.
