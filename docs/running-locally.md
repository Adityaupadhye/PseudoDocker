# Running locally

## Before you start

Conductor runs privileged Linux operations. It creates mounts, network namespaces, veth devices, routes, and firewall rules. Use a compatible Linux machine or VM where changing those resources is acceptable.

It will not run natively on macOS, and the Task 2 executable is specifically an ARM64 Linux binary.

## Prerequisites

The implementation checks for these tools:

```text
ip ping iptables top debootstrap sha256sum
```

The host also needs `bash`, `mount`, `umount`, `unshare`, `nsenter`, `chroot`, `getopt`, `realpath`, `pgrep`, `ps`, and an OverlayFS-capable Linux kernel. cgroup v2 is required for Task 2's CPU-limit demonstration.

Run Conductor as root (usually via `sudo`). Image builds need Internet access to the configured Debian or Ubuntu mirrors; `RUN apt ...` instructions additionally need access to package repositories.

## Configure the host interface

Edit `task3/setup.sh` before enabling Internet access or port forwarding:

```bash
DEFAULT_IFC=enp0s1
```

Set `DEFAULT_IFC` to the host's actual outward-facing network interface. The script also defines the private address space:

```bash
IP4_SUBNET=192.168
IP4_PREFIX_SIZE=24
IP4_FULL_PREFIX_SIZE=16
```

Avoid collisions with an existing `192.168.x.0/24` network. The implementation generates a third octet per network setup.

## Task 1

Compile and run on Linux with the privileges needed to create namespaces and set a hostname:

```bash
cd task1
gcc -o namespace_prog namespace_prog.c
sudo ./namespace_prog
```

## Task 2

```bash
cd task2
sudo ./simple_container.sh
```

The script recreates `container_root`, compiles `container_prog.c`, copies ARM64 shared libraries from hard-coded paths, and runs its three exercises.

`container_prog.c` is not present in this checkout, so a fresh rebuild will fail unless that source is restored. A prebuilt ARM64 binary is present, but it is only usable on a compatible Linux system.

## Task 3

```bash
cd task3
sudo ./conductor.sh build demo Conductorfile
sudo ./conductor.sh run demo demo-container -- /bin/bash
sudo ./conductor.sh exec demo-container -- ps
sudo ./conductor.sh stop demo-container
```

Build artifacts are created as `.cache/`, `.images/`, and `.containers/` beside the script and are excluded from Git.

## Task 4

Task 4 is intended to run from its own directory:

```bash
cd task4
sudo ./service-orchestrator.sh
```

It symlinks Task 3's Conductor scripts, builds two images, starts two containers, configures their networking, and starts both services.

The required `counter-service/` and `external-service/` source directories are absent from this repository, so this workflow cannot currently be reproduced without restoring them.

## Cleanup

Stop named containers with Conductor first:

```bash
sudo ./conductor.sh stop <container>
```

The supplied cleanup scripts remove `.cache`, `.containers`, `.images`, and network namespace entries. Review them before use. `stop` may also flush host forwarding and NAT rules after the final container is removed, so do not use this runtime on a host with firewall rules you need to preserve.
