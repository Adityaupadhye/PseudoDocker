# Walled Gardens: Linux Containers

An IIT Bombay CS695 (Virtualization and Cloud Computing) assignment that incrementally builds a small, Docker-engine-inspired container tool named **Conductor**. The project is an educational implementation of the Linux mechanisms behind containers—not a production container runtime or OCI-compatible engine.

It demonstrates:

- UTS and PID namespaces
- filesystem isolation with `chroot`
- PID, UTS, IPC, mount, and network namespaces
- cgroup v2 CPU limits
- image construction with `debootstrap`
- copy-on-write image and container layers with OverlayFS
- container networking with veth pairs, routes, `iptables`, NAT, and port forwarding
- running a two-service application in separate containers

## Repository map

| Path | Purpose |
| --- | --- |
| `task1/` | C program demonstrating UTS and PID namespaces. |
| `task2/` | A minimal `chroot`-based container experiment, including namespace and cgroup exercises. |
| `task3/` | The Conductor CLI, its configuration, and example Conductorfiles. |
| `task4/` | A script that builds and orchestrates a counter service and an external HTTP service. |
| `docs/` | Detailed documentation for architecture, usage, setup, and known gaps. |

## Start here

Conductor is the main deliverable. Its implementation is in [`task3/conductor.sh`](task3/conductor.sh).

```bash
cd task3
sudo ./conductor.sh build demo Conductorfile
sudo ./conductor.sh run demo demo-container -- /bin/bash
sudo ./conductor.sh exec demo-container -- ps
sudo ./conductor.sh stop demo-container
```

This must be run on a compatible Linux system as root. Read [Running locally](docs/running-locally.md) before running it: the tool mounts filesystems and changes host networking and firewall state.

## Documentation

- [Architecture](docs/architecture.md) — components, storage layout, image build flow, execution flow, and networking.
- [Conductor CLI reference](docs/conductor-cli.md) — commands, arguments, Conductorfile syntax, and examples.
- [Running locally](docs/running-locally.md) — prerequisites, machine-specific configuration, and safe cleanup.
- [Assignment tasks](docs/assignment-tasks.md) — what each task demonstrates.
- [Known limitations](docs/known-limitations.md) — design boundaries, missing source, and operational caveats.

## Scope and non-goals

Conductor supports only `FROM`, `COPY`, and `RUN` instructions. It stores images as local directories and OverlayFS layer references. It does not implement a container registry, OCI image format, resource orchestration, persistent volumes, application authentication, or a general HTTP API.

The repository has no automated test suite or CI/CD configuration. The project is best treated as a controlled lab exercise on a disposable or dedicated Linux host.

## Important repository gaps

Two sources referenced by the assignment are intentionally absent from the checkout:

- `task2/container_prog.c` is ignored; only an ARM64 Linux binary is present.
- `task4/counter-service/` and `task4/external-service/` are ignored and absent.

Their exact implementations are therefore unknown from this repository. See [Known limitations](docs/known-limitations.md) for the consequences.
