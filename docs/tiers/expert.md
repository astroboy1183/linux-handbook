# 🚀 Expert Tier

**Levels 5–6 · Goal: building and mastery** · ~10–16 weeks at 45–60 minutes a day

You understand Linux and can run it. Now you'll build software that works *with* the kernel, and master the technologies that power modern infrastructure: containers, virtualization, performance tooling, security, and automation.

## What you'll be able to do

- Watch any program talk to the kernel with `strace`, and reason in system calls and file descriptors.
- Write network servers that handle many clients, shut down cleanly, and run as hardened systemd services.
- Compile, link, package, and debug native code with gcc, make, gdb, and core dumps.
- Build a container from raw namespaces and cgroups, and explain exactly what Docker adds on top.
- Find performance bottlenecks with `perf`, flame graphs, and eBPF.
- Harden a system with capabilities, AppArmor, and auditing, and automate it all with Ansible.

## The levels

<div class="grid cards" markdown>

-   :material-numeric-5-circle:{ .lg .middle } **Level 5: Building for Linux**

    ---

    System calls, file descriptors, processes and signals in code, pipes and sockets, services, building software, and debugging.

    [:octicons-arrow-right-24: Start Level 5](../chapters/05-programming/index.md)

-   :material-numeric-6-circle:{ .lg .middle } **Level 6: Expert topics**

    ---

    Containers from scratch, performance, security, the kernel, advanced networking, virtualization, Docker and Podman, and Ansible.

    [:octicons-arrow-right-24: Start Level 6](../chapters/06-expert/index.md)

</div>

## Tier checkpoint

You've mastered this handbook when you can do all of these without notes:

- [ ] Explain, using `strace` output, every syscall `cat file.txt` makes.
- [ ] Explain why a container is "just a process", and name each kernel feature that isolates it.
- [ ] Find the hottest function in a CPU-bound program with `perf` and a flame graph.
- [ ] Debug a segfault from a core dump with `gdb`.
- [ ] Rebuild your Level 4 server with a single `ansible-playbook` run.

See the [full roadmap](../roadmap.md) for every concept in this tier. For what to study next, see the "Where to go next" section in the [Level 6 overview](../chapters/06-expert/index.md).
