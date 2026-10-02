#!/usr/bin/env bash
# minicontainer.sh - a minimal container built from unshare, pivot_root and cgroups v2.
#
# Part of the Linux Handbook, Level 6 capstone (option A).
#
# Usage:
#   minicontainer.sh [-m MEM] [-p PIDS] [-c CPU] [-H NAME] [-n] ROOTFS [COMMAND [ARG...]]
#
#   -m MEM    memory limit, cgroup syntax (default: 64M)
#   -p PIDS   maximum number of tasks (default: 32)
#   -c CPU    CPU quota in percent of one CPU (default: 50)
#   -H NAME   hostname inside the container (default: minibox)
#   -n        private network with a veth pair to the host (root only, VM only)
#   ROOTFS    directory holding a root filesystem (for example an Alpine minirootfs)
#   COMMAND   program to run as PID 1 inside the container (default: /bin/sh)
#
# Two modes:
#   * As a normal user (rootless): a user namespace maps you to root inside,
#     and a transient systemd user scope applies the cgroup limits.
#   * As root (VM only): the script writes the cgroup v2 files itself under
#     /sys/fs/cgroup and can wire up a veth pair with -n.

set -euo pipefail

SELF=$(readlink -f "$0")

die() { echo "minicontainer: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Stage 2: runs INSIDE the new namespaces, as (namespaced) root.
# Arguments: __init NAME ROOTFS COMMAND [ARG...]
# ---------------------------------------------------------------------------
container_init() {
    local name=$1 root=$2
    shift 2

    # 1. Our own hostname (UTS namespace).
    hostname "$name"

    # 2. Stop mount events leaking back to the host (mount namespace).
    mount --make-rprivate /

    # 3. pivot_root needs the new root to be a mount point: bind it onto itself.
    mount --bind "$root" "$root"

    # 4. Kernel filesystems. proc shows only our PID namespace.
    mount -t proc -o nosuid,nodev,noexec proc "$root/proc"
    mount -t sysfs -o ro,nosuid,nodev,noexec sysfs "$root/sys"
    mount -t cgroup2 -o nosuid,nodev,noexec cgroup2 "$root/sys/fs/cgroup"
    mount -t tmpfs -o nosuid,nodev,mode=1777,size=16m tmpfs "$root/tmp"

    # 5. A tiny /dev: a tmpfs with a few host device files bind-mounted in.
    #    (Creating device nodes with mknod is not allowed in a user namespace.)
    mount -t tmpfs -o nosuid,noexec,mode=755,size=64k tmpfs "$root/dev"
    local dev
    for dev in null zero full random urandom tty; do
        touch "$root/dev/$dev"
        mount --bind "/dev/$dev" "$root/dev/$dev"
    done
    ln -s /proc/self/fd   "$root/dev/fd"
    ln -s /proc/self/fd/0 "$root/dev/stdin"
    ln -s /proc/self/fd/1 "$root/dev/stdout"
    ln -s /proc/self/fd/2 "$root/dev/stderr"

    # 6. Swap the root filesystem, then detach the old one.
    cd "$root"
    mkdir -p .oldroot
    pivot_root . .oldroot
    cd /
    # From here on, commands come from the container's rootfs.
    umount -l /.oldroot
    rmdir /.oldroot

    # 7. Replace this shell with the container's command. It becomes PID 1.
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    exec env -i PATH="$PATH" HOME=/root TERM="${TERM:-xterm}" HOSTNAME="$name" "$@"
}

if [[ ${1:-} == __init ]]; then
    shift
    container_init "$@"
fi

# ---------------------------------------------------------------------------
# Stage 1: runs on the host.
# ---------------------------------------------------------------------------
MEM=64M
PIDS=32
CPU=50
NAME=minibox
NET=no

usage() { sed -n '6,16p' "$SELF" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ':m:p:c:H:nh' opt; do
    case $opt in
        m) MEM=$OPTARG ;;
        p) PIDS=$OPTARG ;;
        c) CPU=$OPTARG ;;
        H) NAME=$OPTARG ;;
        n) NET=yes ;;
        h) usage 0 ;;
        :) die "option -$OPTARG needs a value" ;;
        *) die "unknown option -$OPTARG (try -h)" ;;
    esac
done
shift $((OPTIND - 1))

[[ $# -ge 1 ]] || usage 1
ROOTFS=$(readlink -f "$1")
shift
[[ $# -ge 1 ]] || set -- /bin/sh

[[ -x $ROOTFS/bin/sh ]] || die "$ROOTFS does not look like a root filesystem (no /bin/sh)"
for d in proc sys tmp dev; do
    [[ -d $ROOTFS/$d ]] || die "$ROOTFS/$d is missing (mkdir it first)"
done
[[ $PIDS =~ ^[0-9]+$ ]] || die "-p needs a number"
[[ $CPU =~ ^[0-9]+$ ]]  || die "-c needs a number (percent of one CPU)"

# Namespaces every container gets. --fork makes the command a child of
# unshare, so it lands in the new PID namespace as PID 1. --kill-child
# makes sure the container dies if unshare is killed.
NS_FLAGS=(--mount --uts --ipc --pid --cgroup --fork --kill-child)

if [[ $EUID -ne 0 ]]; then
    # ---------------- Rootless mode ----------------
    [[ $NET == no ]] || die "-n needs root (use your VM: sudo $0 -n ...)"
    if [[ $(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null || echo 0) == 1 ]]; then
        echo "minicontainer: warning: kernel.apparmor_restrict_unprivileged_userns=1;" \
             "user namespaces may be blocked (see the Containers chapter)" >&2
    fi
    echo "minicontainer: rootless, limits mem=$MEM pids=$PIDS cpu=${CPU}%" >&2
    exec systemd-run --user --scope --quiet --collect \
        -p MemoryMax="$MEM" -p MemorySwapMax=0 \
        -p TasksMax="$PIDS" -p CPUQuota="${CPU}%" \
        unshare --user --map-root-user --net "${NS_FLAGS[@]}" \
        "$SELF" __init "$NAME" "$ROOTFS" "$@"
fi

# ---------------- Root mode (VM only) ----------------
CG=/sys/fs/cgroup/minicontainer-$$
NETNS=mc$$
VETH=vh$$

# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
    if [[ $NET == yes ]]; then
        ip netns delete "$NETNS" 2>/dev/null || true
        ip link delete "$VETH" 2>/dev/null || true
    fi
    # A cgroup can only be removed once it has no processes left.
    if [[ -d $CG ]]; then
        rmdir "$CG" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Make sure the root cgroup hands the controllers we need to its children.
for c in memory pids cpu; do
    grep -qw "$c" /sys/fs/cgroup/cgroup.subtree_control ||
        echo "+$c" > /sys/fs/cgroup/cgroup.subtree_control
done

mkdir "$CG"
echo "$MEM"                    > "$CG/memory.max"
echo 0                         > "$CG/memory.swap.max"
echo "$PIDS"                   > "$CG/pids.max"
echo "$((CPU * 1000)) 100000"  > "$CG/cpu.max"
echo "minicontainer: cgroup $CG mem=$MEM pids=$PIDS cpu=${CPU}%" >&2

WRAP=()
if [[ $NET == yes ]]; then
    ip netns add "$NETNS"
    ip link add "$VETH" type veth peer name eth0 netns "$NETNS"
    ip addr add 10.200.0.1/24 dev "$VETH"
    ip link set "$VETH" up
    ip -n "$NETNS" link set lo up
    ip -n "$NETNS" addr add 10.200.0.2/24 dev eth0
    ip -n "$NETNS" link set eth0 up
    ip -n "$NETNS" route add default via 10.200.0.1
    WRAP=(nsenter --net="/run/netns/$NETNS")
    echo "minicontainer: network host 10.200.0.1 <-> container 10.200.0.2" >&2
else
    NS_FLAGS+=(--net)
fi

rc=0
(
    # Move only this subshell into the cgroup, so the parent script can
    # still remove the cgroup afterwards.
    echo "$BASHPID" > "$CG/cgroup.procs"
    exec "${WRAP[@]}" unshare "${NS_FLAGS[@]}" "$SELF" __init "$NAME" "$ROOTFS" "$@"
) || rc=$?
exit "$rc"
