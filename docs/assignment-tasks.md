# Assignment tasks

## Task 1 — namespace fundamentals

`namespace_prog.c` demonstrates two kinds of Linux namespace isolation:

- A child created by `clone()` receives fresh UTS and PID namespaces.
- The child sets a private hostname.
- The parent joins the child PID namespace before forking another child.
- The second child joins the child UTS namespace and observes the isolated hostname.

The code illustrates that joining a PID namespace affects subsequently created children, not the caller's own PID namespace identity.

## Task 2 — minimal container root

`simple_container.sh` uses `chroot` to run a program with a different root filesystem. It extends that basic isolation with:

1. a new PID and UTS namespace;
2. a new IPC namespace;
3. a cgroup v2 CPU limit of `50000 100000`, equivalent to a 50% quota of one CPU period.

## Task 3 — Conductor

Task 3 packages the individual primitives into the Conductor CLI:

- Bootstrap Debian/Ubuntu roots with `debootstrap`.
- Apply `COPY` and `RUN` build instructions as cached OverlayFS layers.
- Run a command in isolated UTS, PID, network, mount, and IPC namespaces.
- Enter a running container with `nsenter`.
- Provision veth networking, NAT, port forwarding, and container-to-container forwarding.

## Task 4 — service orchestration

Task 4 uses Conductor to build and deploy two dependent services:

- `counter-service` is copied to `/app/counter-service`, built with `make`, and started on port 8080.
- `external-service` is copied to `/app/external-service`, provisioned with Python, Flask, and Requests, and started with the counter service URL as an argument.

The orchestration script assigns network access to each container, permits peer traffic, and invokes the external service. The service source code is not committed, so implementation-level behavior is not documented as fact.
