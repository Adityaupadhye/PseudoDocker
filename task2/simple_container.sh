#!/bin/bash

SIMPLE_CONTAINER_ROOT=container_root

mkdir -p $SIMPLE_CONTAINER_ROOT

gcc -o container_prog container_prog.c

## Subtask 1: Execute in a new root filesystem

cp container_prog $SIMPLE_CONTAINER_ROOT/

# 1.1: Copy any required libraries to execute container_prog to the new root container filesystem 
mkdir -p ./container_root/lib/aarch64-linux-gnu/
sudo cp /lib/aarch64-linux-gnu/libpcre2-8.so.0 ./container_root/lib/aarch64-linux-gnu/
sudo cp /lib/aarch64-linux-gnu/libselinux.so.1 ./container_root/lib/aarch64-linux-gnu/
sudo cp /lib/aarch64-linux-gnu/libtinfo.so.6 ./container_root/lib/aarch64-linux-gnu/
sudo cp /lib/aarch64-linux-gnu/libc.so.6 ./container_root/lib/aarch64-linux-gnu/
sudo cp /lib/ld-linux-aarch64.so.1 ./container_root/lib/



echo -e "\n\e[1;32mOutput Subtask 2a\e[0m"
# 1.2: Execute container_prog in the new root filesystem using chroot. You should pass "subtask1" as an argument to container_prog
sudo chroot ./container_root ./container_prog subtask1


echo "__________________________________________"
echo -e "\n\e[1;32mOutput Subtask 2b\e[0m"
## Subtask 2: Execute in a new root filesystem with new PID and UTS namespace
# The pid of container_prog process should be 1
# You should pass "subtask2" as an argument to container_prog
sudo unshare --fork --pid --uts --mount-proc chroot ./container_root ./container_prog subtask2



echo -e "\nHostname in the host: $(hostname)"


## Subtask 3: Execute in a new root filesystem with new PID, UTS and IPC namespace + Resource Control
# Create a new cgroup and set the max CPU utilization to 50% of the host CPU. (Consider only 1 CPU core)
CGROUP_NAME="subtask3_cgroup"
CGROUP_DIR="/sys/fs/cgroup/${CGROUP_NAME}"

if ! mountpoint -q /sys/fs/cgroup; then
    sudo mount -t cgroup2 none /sys/fs/cgroup
fi

sudo mkdir -p ${CGROUP_DIR}

echo "+cpu" | sudo tee /sys/fs/cgroup/cgroup.subtree_control > /dev/null

echo "50000 100000" | sudo tee "${CGROUP_DIR}/cpu.max" > /dev/null


echo "__________________________________________"
echo -e "\n\e[1;32mOutput Subtask 2c\e[0m"
# Assign pid to the cgroup such that the container_prog runs in the cgroup
# Run the container_prog in the new root filesystem with new PID, UTS and IPC namespace
# You should pass "subtask1" as an argument to container_prog
sudo sh -c "
    echo \$$ > ${CGROUP_DIR}/cgroup.procs 

    unshare --fork --pid --uts --ipc --mount-proc chroot ./container_root ./container_prog subtask3
"
# sudo unshare --fork --pid --uts --ipc --mount-proc chroot ./container_root ./container_prog subtask3


# Remove the cgroup
sudo rmdir ${CGROUP_DIR}


# If mounted dependent libraries, unmount them, else ignore
