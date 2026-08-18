# Conductor CLI reference

Run all commands from `task3/` unless noted otherwise. Conductor requires root privileges.

```text
./conductor.sh <command> [parameters] [options]
```

## Commands

| Command | Description |
| --- | --- |
| `build <image> [conductorfile]` | Builds an image. Defaults to `Conductorfile`. |
| `images` | Lists image directories. |
| `rmi <image>` | Removes an image metadata directory. |
| `rmcache` | Removes unused build layers and cached base filesystems when no containers exist. |
| `run <image> <container> -- [command args]` | Starts a new container. Defaults to `/bin/bash`. |
| `ps` | Lists container directories. |
| `stop <container>` | Kills the matching container process, unmounts its filesystems, and removes its directory. |
| `exec <container> -- [command args]` | Runs a command in the container namespaces and root filesystem. |
| `addnetwork <container> [--internet] [--expose inner-outer]` | Adds a veth-based network connection. |
| `peer <container-a> <container-b>` | Allows forwarding between two containers. |

## Conductorfile syntax

Only the following instructions are implemented:

```Dockerfile
FROM debian:bookworm
COPY file.txt /app/file.txt
RUN mkdir -p /app/new_dir
```

Supported bases are:

- `debian:bookworm`
- `ubuntu:focal`
- `ubuntu:jammy`

`COPY` accepts a source and destination separated by spaces. `RUN` executes its remaining text with `/bin/sh -c` inside the temporary build root. Features such as `CMD`, `ENTRYPOINT`, `ENV`, `WORKDIR`, multi-stage builds, and registry pulls are not implemented.

## Examples

### Build and run an image

```bash
sudo ./conductor.sh build demo Conductorfile
sudo ./conductor.sh images
sudo ./conductor.sh run demo demo-container -- /bin/bash
```

### Execute in a running container

```bash
sudo ./conductor.sh exec demo-container -- hostname
sudo ./conductor.sh exec demo-container -- ps
```

### Give a container Internet access

```bash
sudo ./conductor.sh addnetwork demo-container --internet
```

### Forward a port

```bash
sudo ./conductor.sh addnetwork web-container --internet --expose 8080-3000
```

This asks Conductor to forward TCP port `3000` on the host's configured external interface to port `8080` in `web-container`.

### Allow traffic between containers

```bash
sudo ./conductor.sh peer service-a service-b
```

### Stop and clean up

```bash
sudo ./conductor.sh stop demo-container
sudo ./conductor.sh rmi demo
sudo ./conductor.sh rmcache
```

Use the included `cleanup.sh` scripts only on a dedicated lab host: they remove Conductor state and can remove network namespace links.
