# Known limitations and repository gaps

## Educational runtime, not a production engine

Conductor is intentionally small and relies on host-global resources. It does not provide the isolation hardening, lifecycle management, or compatibility expected from Docker, containerd, Podman, or an OCI runtime.

Not implemented:

- OCI image or runtime compatibility
- image registries, pull/push, tags, archives, or portable exports
- `CMD`, `ENTRYPOINT`, `ENV`, `WORKDIR`, multi-stage builds, or build contexts beyond direct filesystem paths
- volume management, user namespaces, capabilities management, seccomp, or cgroup resource controls in Conductor itself
- health checks, restart policies, logs management, service discovery, or orchestration
- application authentication, authorization, database support, background workers, or CI/CD configuration

## Missing source material

The `.gitignore` excludes material necessary to reproduce two parts of the assignment:

- `task2/container_prog.c`
- `task4/counter-service/`
- `task4/external-service/`

The prebuilt `task2/container_prog` is a dynamically linked ARM64 Linux executable. Its observable strings indicate hostname, PID, root-directory listing, and benchmark behavior, but its exact source is unavailable.

The Task 4 image definitions and orchestration script establish expected build and startup commands, but the service APIs, routes, persistence model, and internal logic remain unknown.

## Host-safety caveats

- Root access is mandatory.
- `addnetwork --internet` enables IPv4 forwarding and inserts host `iptables` rules.
- The implementation writes a replacement DNS resolver setting to `/etc/resolv.conf` and saves the prior file as `/etc/resolv.conf.old`.
- Cleanup and final-container shutdown can flush host forwarding and NAT rules.
- The default host interface (`enp0s1`) is machine-specific.
- Networking uses generated `192.168.x.0/24` subnets, which can conflict with existing networks.

Use a disposable VM or dedicated lab environment rather than a shared workstation or server.

## Implementation caveats

- Runtime process discovery uses `ps | grep` patterns rather than robust lifecycle metadata. The script writes a container PID file but does not use it for normal lookup.
- The most recent Git commit adds `head -1` to one process lookup, which reduces but does not eliminate ambiguity when multiple matching processes exist.
- Container stop behavior uses forceful process termination and best-effort unmounts.
- Images rely on their local layer cache. Deleting cached layers can invalidate image metadata.
- Task 4 configures host-port forwarding but verifies the service by curling the container IP and port directly; host-port forwarding is therefore not demonstrated by the committed script output.

## Unknown / needs confirmation

- Whether the missing Task 4 services retain counter state in memory, files, or another system.
- The exact HTTP routes and request/response contract of the external service.
- Whether the Task 4 host-port forwarding path was successfully tested outside the saved output.
- Whether the original coursework environment supplied the ignored sources separately.
