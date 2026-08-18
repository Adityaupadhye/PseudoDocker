# PseudoDocker
### A Container Runtime Built from Linux Primitives

**Project Report**

---

| | |
|---|---|
| **Submitted by** | Aditya Sachin Upadhye (24M0830) |
| **Programme** | M.Tech, Computer Science & Engineering |
| **Institute** | Indian Institute of Technology Bombay |
| **Course** | CS695: Virtualisation and Cloud Computing |
| **Guide** | Prof. Purushottam Kulkarni |
| **Duration** | Jan 2025 – May 2025 |

---

## Abstract

Modern container platforms such as Docker, containerd, and Podman present a simple user-facing interface — build an image, run a container — while relying underneath on a specific combination of Linux kernel mechanisms: namespaces, control groups, filesystem isolation, and virtual networking. This project, undertaken as coursework for CS695 (Virtualisation and Cloud Computing), builds these mechanisms from first principles rather than through an existing container library, in order to demonstrate a working understanding of how container isolation is actually implemented at the operating-system level.

The work progressed through four stages of increasing complexity: (1) namespace creation and attachment using raw system calls, (2) a minimal single-container shell script combining filesystem, process, and resource isolation, (3) a complete command-line container runtime — internally named **Conductor** — supporting image builds, container lifecycle management, and inter-container networking, and (4) a realistic two-service deployment exercising the runtime end-to-end. The final deliverable is capable of building Debian/Ubuntu-based container images, running multiple isolated containers concurrently, and networking them together with host and internet connectivity, replicating — at a primitive, educational level — the core workflow of Docker.

---

## 1. Introduction

### 1.1 Motivation

Container technologies are foundational to modern software deployment, yet the mechanisms that make containers work are frequently treated as opaque by developers who only interact with high-level tools like `docker run`. This project's motivation was to open that black box: to implement, using nothing but the Linux kernel's own primitives, the same categories of isolation that Docker relies on, and in doing so build a working, from-source understanding of process isolation, resource control, filesystem layering, and container networking.

### 1.2 Objectives

The assignment specified the following broad objectives:

1. Demonstrate namespace creation and namespace attachment using Linux system calls directly.
2. Build a minimal, single-container isolation environment combining filesystem, process, and resource isolation.
3. Construct a more complete container management tool, replicating core Docker-like functionality: image builds, container lifecycle commands, and container networking.
4. Apply the resulting tool to a realistic multi-container deployment scenario, validating that independently isolated and networked containers can communicate correctly.

### 1.3 Scope

This project is an educational implementation, not a production-grade container runtime. It does not implement an OCI-compliant image format, a container registry, user-namespace-based rootless operation, or the security hardening expected of a runtime intended for untrusted workloads. Its scope is explicitly to demonstrate — accurately and completely — the underlying kernel mechanisms, not to compete with mature runtimes on completeness or robustness. Section 7 discusses these boundaries explicitly.

---

## 2. Background: Kernel Mechanisms Used

Before describing the implementation, it is useful to summarize the kernel-level building blocks the project relies on:

| Mechanism | Purpose |
|---|---|
| **Namespaces** (`CLONE_NEWPID`, `CLONE_NEWUTS`, `CLONE_NEWNET`, `CLONE_NEWNS`, `CLONE_NEWIPC`) | Give a process an isolated view of process IDs, hostname, network stack, mount table, and inter-process communication resources respectively. |
| **`clone()`** | System call used to create a new process while optionally placing it into new namespaces at creation time. |
| **`setns()`** | System call used to attach an *existing* process to the namespace of another process, via a file descriptor opened on `/proc/<pid>/ns/<type>`. |
| **`unshare`** | Command-line/syscall wrapper that dissociates parts of the calling process's execution context (namespaces) from its parent, without requiring a fresh `clone()`. |
| **`chroot`** | Changes the apparent root directory for a process and its children, restricting visible filesystem paths. |
| **cgroups v2** | Kernel mechanism for limiting, accounting, and isolating resource usage (CPU, memory, I/O) of a group of processes. |
| **OverlayFS** | A union filesystem allowing multiple directories (layers) to be composited into a single merged view, with writes captured in a separate upper layer — the mechanism behind Docker's image layering. |
| **`debootstrap`** | Tool for bootstrapping a Debian/Ubuntu base filesystem from package repositories, used here to construct container base images. |
| **`nsenter`** | Utility to enter the namespaces of an existing process, used to implement "exec into a running container." |
| **`iproute2` / `veth`** | Tools and virtual Ethernet device pairs used to construct virtual network links between a container's network namespace and the host. |
| **`iptables`** | Used to configure NAT (via `MASQUERADE`) for outbound container internet access, and DNAT for inbound port forwarding to containers. |

---

## 3. Implementation

### 3.1 Task 1 — Namespace Fundamentals (C, raw system calls)

**Objective.** Demonstrate, at the system-call level, both the creation of new namespaces and the attachment of an independently created process to an existing namespace.

**Implementation.**
- A child process is created using `clone()` with the flags `CLONE_NEWUTS | CLONE_NEWPID`, placing it into new UTS (hostname) and PID namespaces at the moment of creation. Inside this namespace, the child sets its own hostname and observes itself as PID 1.
- A second, independently created child process is then attached to the *same* PID and UTS namespaces as the first, using `setns()` on file descriptors opened against `/proc/<pid>/ns/pid` and `/proc/<pid>/ns/uts`. This demonstrates that namespace membership can be shared across processes that were not created together, which is not possible via `clone()` alone.
- A pipe is used to synchronize the parent and first child, ensuring the first child's namespace is fully initialized before the second child attaches to it.

**Result.** The second child correctly inherits the first child's isolated hostname and process-ID namespace view — confirmed by comparing printed PID and hostname values across parent, child 1, and child 2 against the expected reference output.

### 3.2 Task 2 — Minimal Single-Container Isolation (Bash + kernel primitives)

**Objective.** Build a single, self-contained container combining filesystem, process, and resource isolation, incrementally, in three sub-stages.

**Implementation.**
- **Filesystem isolation (2a):** `chroot` is used to confine a target program to a designated root directory. Special care is taken to ensure the program's dynamic library dependencies are available at the correct paths inside the chrooted environment, since a chrooted process cannot resolve libraries outside its new root.
- **Process isolation (2b):** `unshare` is used to place the chrooted program into new PID and UTS namespaces, so that the process observes itself as PID 1 within the container and has an independent hostname, while remaining in the same chrooted filesystem as 2a.
- **Resource isolation (2c):** A dedicated cgroup v2 hierarchy is created, and the container's processes are attached to it. A CPU quota of `50000 100000` is applied via the `cpu.max` control file, limiting the container to 50% utilization of a single CPU core regardless of how many cores are available on the host.

**Result.** A CPU-bound benchmark program run inside the cgroup-limited container took measurably longer to complete than the same benchmark run without the CPU limit applied, confirming the quota was correctly enforced.

### 3.3 Task 3 — Conductor: A Complete Container Runtime (Bash, ~820 lines)

This is the primary deliverable of the project: a command-line tool, internally named **Conductor**, implementing a Docker-equivalent workflow end-to-end.

**3.3.1 Image builds.** Conductor reads a Dockerfile-equivalent build specification (a "Conductorfile") supporting `FROM`, `COPY`, and `RUN` instructions. The `FROM` instruction maps a distribution/version string (e.g. `debian:bookworm`) to a configured mirror and uses `debootstrap` to populate a cached base root filesystem. `COPY` and `RUN` instructions are each translated into a content-addressed (SHA-256) OverlayFS layer; for `RUN`, Conductor temporarily mounts the accumulated OverlayFS stack, executes the instruction inside a `chroot`, and records the resulting filesystem changes as a new layer. Existing layers are cached and reused across builds rather than rebuilt from scratch.

**3.3.2 Image and container storage.** All build and runtime state is organized under a structured cache/layer directory scheme:

| Location | Contents |
|---|---|
| `.cache/base/<distro-version>` | `debootstrap`-generated base root filesystem |
| `.cache/layers/<hash>/diff` | Files changed by a specific `COPY` or `RUN` instruction |
| `.cache/layers/<hash>/work` | OverlayFS work directory for that layer |
| `.images/<image>/layers` | Ordered stack of OverlayFS lower directories composing an image |
| `.containers/<container>/upper` | Writable layer for a running container's changes |
| `.containers/<container>/merged` | The mounted, merged root filesystem used by the running container |

**3.3.3 Container lifecycle.** Conductor implements `run`, `exec`, `stop`, and `ps`:
- `run` mounts the image's layered filesystem with a fresh writable layer on top, bind-mounts the host's `/dev` into the container (for tools that depend on device visibility), then launches the container process using `unshare` across **five namespace types** — UTS, PID, network, mount, and IPC — followed by mounting `proc` and `sysfs` inside the container and `chroot`-ing into the merged root filesystem before executing the requested command.
- `exec` locates the process group of an already-running container and uses `nsenter` to join its existing namespaces, then `chroot`s into the same merged root filesystem to execute an additional command inside the running container — the same underlying approach `docker exec` uses.
- `stop` terminates the container's processes, unmounts any remaining mount points inside the container's root, and removes the container's runtime state.
- `ps` lists currently running containers by inspecting tracked runtime state.

**3.3.4 Networking.** Conductor implements container networking directly from `iproute2` and `iptables` primitives:
1. A `veth` (virtual Ethernet) pair is created for each container, with one end moved into the container's network namespace and the other left on the host.
2. Both ends are assigned addresses on a generated `/24` subnet and brought up, along with routing between host and container.
3. Optional NAT (`iptables -t nat ... MASQUERADE`) is configured to give the container outbound internet access via the host's network interface.
4. Optional DNAT rules forward a specified host port to a port inside the container, exposing containerized services externally.
5. A `peer` command allows direct traffic forwarding between the host-side `veth` interfaces of two named containers, enabling container-to-container communication without going through the host's default routing.

**3.3.5 Known limitation.** Process discovery for lifecycle commands (`stop`, `ps`) relies on pattern-matching over `ps` output rather than authoritative tracked PID metadata. This is an acknowledged limitation of the implementation — documented in the project's own repository notes — that could, in edge cases involving multiple similarly named processes, misidentify a target process. It does not affect the correctness of the core isolation or networking mechanisms.

### 3.4 Task 4 — Multi-Container Service Deployment

**Objective.** Apply Conductor to a realistic scenario: deploy two independently containerized services and verify they can communicate correctly under the isolation and networking model built in Task 3.

**Setup.** Two container images were built from Conductorfiles — one running an external-facing Python/Flask service, and one running an internal-only compiled service (built via a `RUN` instruction inside the image). The external-facing container was configured with internet access and a host-forwarded port (making it reachable from outside the host); the internal-only container was given no direct external exposure. Direct peer networking was configured between the two containers.

**Result.** The external-facing service successfully issued a live HTTP request to the internal-only service across the container-to-container network path, and received a correct, stateful response, confirming that:
- both containers were correctly isolated into independent namespaces,
- the peer networking link between them functioned correctly,
- and the host-forwarded port on the external service was reachable from outside the container network.

This constitutes an end-to-end functional validation of the entire runtime — not merely that individual components compiled or ran in isolation, but that the composed system behaved correctly under a realistic two-service workload.

---

## 4. Results Summary

| Component | Status | Verification |
|---|---|---|
| Namespace creation & attachment (Task 1) | Complete | Matches reference PID/hostname output across parent and both children |
| Filesystem, process, and cgroup isolation (Task 2) | Complete | CPU-bound benchmark confirms cgroup quota enforcement |
| Image build system (Task 3) | Complete | Debian/Ubuntu images built successfully via `debootstrap` + OverlayFS layering |
| Container lifecycle (`run`/`exec`/`stop`/`ps`) (Task 3) | Complete | Verified interactively; `ps`/`ip a` inside containers reflect correct isolation |
| Container networking (Task 3) | Complete, with a documented process-discovery limitation | veth/NAT/port-forwarding verified functional |
| Multi-container deployment (Task 4) | Complete | Captured successful end-to-end HTTP response between containers |

---

## 5. Technologies Used

**Languages:** C, Bash

**Kernel mechanisms:** `clone()`, `setns()`, `unshare`, `chroot`, cgroups v2 (`cpu.max`), Linux namespaces (PID, UTS, NET, Mount, IPC)

**Filesystem:** OverlayFS (copy-on-write layering), `debootstrap` (base filesystem bootstrapping)

**Networking:** `iproute2` (veth pairs, routing), `iptables` (NAT/MASQUERADE, DNAT port forwarding)

**Tooling:** `nsenter` (namespace entry for `exec`), Git (version control)

---

## 6. Repository Structure

```
walled-gardens-linux-containers/
├── task1/
│   └── namespace_prog.c        # clone()/setns() namespace demo
├── task2/
│   ├── simple_container.sh     # chroot + namespaces + cgroups
│   └── container_prog          # target binary for isolation demo
├── task3/
│   ├── conductor.sh             # main container runtime (~820 lines)
│   ├── setup.sh                 # environment/interface configuration
│   ├── Conductorfile             # example build specification
│   └── Conductorfiles/           # additional build specification variants
├── task4/
│   ├── service-orchestrator.sh  # two-container deployment driver
│   ├── csfile / esfile          # Conductorfiles for the two services
│   └── output.txt               # captured successful cross-container response
└── docs/
    ├── architecture.md          # internal design documentation
    ├── known-limitations.md     # documented gaps and edge cases
    ├── conductor-cli.md         # command reference
    └── running-locally.md       # setup/run instructions
```

---

## 7. Limitations and Honest Scope

This project should be evaluated as a demonstration of the operating-system mechanisms underlying container platforms, not as a production-ready alternative to Docker, containerd, or Podman. Specifically:

- **No OCI compliance.** Images are not portable OCI-format image archives; they are metadata referencing locally cached layers.
- **No image registry.** There is no mechanism for pushing, pulling, or distributing images beyond the local build cache.
- **No rootless operation.** Conductor requires root privileges, using host mounts, namespaces, `/proc`, `/dev`, and `iptables` directly. It is not a security boundary suitable for genuinely untrusted workloads.
- **No health checks, restart policies, or orchestration primitives** beyond the basic lifecycle and peer-networking commands described above.
- **Process discovery relies on `ps`-based pattern matching** rather than authoritative process tracking, as noted in Section 3.3.5.

These limitations were understood scope boundaries of the assignment, not oversights discovered after the fact — the objective was correctness and completeness of the core kernel-level mechanisms, not feature parity with mature container runtimes.

---

## 8. Conclusion

This project implements the core mechanisms of a container runtime — namespace-based process isolation, cgroup-based resource control, chroot-based filesystem confinement, OverlayFS-based image layering, and veth/iptables-based container networking — entirely from Linux kernel primitives, without relying on any existing container engine. Across four incremental stages, the work progressed from single-syscall demonstrations to a complete, ~820-line container runtime capable of building images, managing container lifecycles, and networking multiple containers together, validated end-to-end through a realistic two-service deployment. The result is a working, source-verified demonstration of how modern container platforms function beneath their user-facing interfaces.

---