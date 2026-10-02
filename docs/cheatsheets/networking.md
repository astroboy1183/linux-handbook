# Networking Cheat Sheet

Quick reference for interfaces, routes, sockets, connectivity tests, DNS,
HTTP, raw TCP, the firewall, and NetworkManager. Chapters:
[Networking basics](../chapters/04-sysadmin/03-networking-basics.md),
[Firewalls with ufw](../chapters/04-sysadmin/04-firewall-ufw.md),
[Web servers and TLS](../chapters/04-sysadmin/11-web-servers-and-tls.md),
[Advanced networking](../chapters/06-expert/05-advanced-networking.md).

## ip: interfaces, addresses, routes

`ip` replaces the old `ifconfig`, `route`, and `arp` commands (package
`net-tools`, no longer installed by default).

| Command | What it shows or does |
|---|---|
| `ip -br addr` | One line per interface: name, state, addresses |
| `ip addr show dev wlo1` | Full details for one interface |
| `ip -br link` | Interfaces with MAC addresses and flags |
| `ip -s link show dev wlo1` | Packet and error counters |
| `ip route` | Routing table: where packets go |
| `ip route get 1.1.1.1` | Which interface and gateway would be used to reach an address |
| `ip neigh` | ARP/neighbor cache: IP → MAC on the local network |
| `ip -6 addr` | IPv6 addresses only |
| `sudo ip link set dev eth0 down` / `up` | Disable / enable an interface |
| `sudo ip addr add 10.0.0.5/24 dev eth0` | Add an address (temporary, lost at reboot) |

```bash
ip -br addr
ip route
```

```text
lo               UNKNOWN        127.0.0.1/8 ::1/128
wlo1             UP             192.168.1.50/24 fe80::a00:27ff:fe4e:66a1/64
default via 192.168.1.1 dev wlo1 proto dhcp src 192.168.1.50 metric 600
192.168.1.0/24 dev wlo1 proto kernel scope link src 192.168.1.50 metric 600
```

The `default via 192.168.1.1` line is the **default gateway**: the router
that receives every packet not meant for the local network.

!!! danger "⚠️ VM only"
    Changing addresses, routes, or bringing interfaces down can cut your
    network connection, including the SSH session you're using. Practice in
    your VM, from its console.

## ss: sockets and ports

`ss` replaces `netstat`.

| Command | What it shows |
|---|---|
| `ss -tlnp` | **T**CP **l**istening sockets, **n**umeric, with **p**rocesses (use `sudo` to see all processes) |
| `ss -ulnp` | UDP listening sockets |
| `ss -tulnp` | Both |
| `ss -tn` | Established TCP connections |
| `ss -tan` | All TCP sockets, any state |
| `ss -tn state established '( dport = :443 )'` | Connections to remote port 443 |
| `ss -tn dst 10.0.0.5` | Connections to one host |
| `ss -tnp sport = :22` | Connections on local port 22 (SSH sessions) |
| `ss -s` | Summary counts by state |
| `ss -x` | Unix domain sockets |

```bash
sudo ss -tlnp
```

```text
State   Recv-Q  Send-Q  Local Address:Port  Peer Address:Port Process
LISTEN  0       4096    127.0.0.53%lo:53         0.0.0.0:*     users:(("systemd-resolve",pid=612,fd=15))
LISTEN  0       511           0.0.0.0:80         0.0.0.0:*     users:(("nginx",pid=1201,fd=6))
LISTEN  0       4096                *:22               *:*     users:(("sshd",pid=1032,fd=3),("systemd",pid=1,fd=184))
```

`0.0.0.0` or `*` means "all interfaces": reachable from the network.
`127.0.0.1` or `127.0.0.53%lo` means local only.

## Connectivity

| Command | What it does |
|---|---|
| `ping -c 4 1.1.1.1` | Send 4 ICMP echo requests (by IP: tests routing, not DNS) |
| `ping -c 4 example.com` | Same, by name: also tests DNS |
| `ping -c 3 -W 1 192.168.1.1` | Wait at most 1 second per reply |
| `tracepath example.com` | The route (hops) to a host |
| `mtr example.com` | Live traceroute with loss per hop (`q` to quit) |
| `ip route get 8.8.8.8` | Which route would be used |

Debug in layers: link up (`ip -br link`) → address (`ip -br addr`) →
gateway (`ping` the gateway) → internet by IP (`ping 1.1.1.1`) → DNS
(`ping example.com`, `dig`) → the service's port (`nc -zv`, `curl`).

## DNS

| Command | What it does |
|---|---|
| `dig example.com` | Full DNS answer for the A record |
| `dig +short example.com` | Just the addresses |
| `dig +noall +answer example.com` | Only the answer section |
| `dig example.com MX` | Mail servers (also `AAAA`, `TXT`, `NS`, `CNAME`, `SOA`) |
| `dig @1.1.1.1 example.com` | Ask a specific DNS server |
| `dig -x 8.8.8.8 +short` | Reverse lookup: IP → name |
| `dig +trace example.com` | Follow the delegation from the root servers down |
| `host example.com` | Short, human-friendly lookup |
| `getent hosts example.com` | Resolve the way programs do (honors `/etc/hosts`) |
| `resolvectl status` | DNS servers in use, per interface |
| `resolvectl query example.com` | Resolve through systemd-resolved |
| `sudo resolvectl flush-caches` | Clear the local DNS cache |

```bash
dig +noall +answer example.com
```

```text
example.com.		269	IN	A	104.20.23.154
example.com.		269	IN	A	172.66.147.243
```

Columns: name, **TTL** (seconds it may be cached), class, record type,
value. On Ubuntu, `/etc/resolv.conf` points to `127.0.0.53`, the local
**systemd-resolved** stub resolver, which forwards to your real DNS servers.

## curl: HTTP from the command line

| Command | What it does |
|---|---|
| `curl https://example.com` | Print the response body |
| `curl -I https://example.com` | Headers only (a HEAD request) |
| `curl -i https://example.com` | Headers and body |
| `curl -L http://example.com` | Follow redirects |
| `curl -o page.html URL` / `-O URL` | Save to a named file / to the remote file name |
| `curl -fsS URL` | Fail on HTTP errors, silent, but still show errors (good in scripts) |
| `curl -v URL` | Verbose: DNS, TLS handshake, request and response headers |
| `curl -H 'Authorization: Bearer TOKEN' URL` | Add a header |
| `curl -X POST -d 'a=1&b=2' URL` | POST form data |
| `curl --json '{"name":"alex"}' URL` | POST JSON (sets the content headers) |
| `curl -u alex:secret URL` | HTTP basic auth |
| `curl -s -o /dev/null -w '%{http_code} %{time_total}\n' URL` | Just status code and total time |
| `curl -m 5 URL` | Give up after 5 seconds |
| `curl --retry 3 URL` | Retry transient failures |
| `curl -C - -O URL` | Resume an interrupted download |
| `curl -k https://self-signed.local` | Skip TLS verification (testing only!) |
| `curl --resolve example.com:443:10.0.0.5 https://example.com` | Test a server before changing DNS |

## nc: raw TCP and UDP

Ubuntu ships the OpenBSD `netcat`.

| Command | What it does |
|---|---|
| `nc -zv example.com 443` | Is the port open? (`-z` scan only, `-v` verbose) |
| `nc -zv 192.168.1.20 20-25` | Scan a small port range |
| `nc -zvu 192.168.1.1 53` | UDP check (unreliable: no reply looks like open) |
| `nc -l 9000` | Listen on port 9000 and print what arrives |
| `nc localhost 9000` | Connect and send what you type |
| `nc -l 9000 > file` / `nc host 9000 < file` | Copy a file over the network (unencrypted) |
| `printf 'GET / HTTP/1.0\r\nHost: example.com\r\n\r\n' | nc example.com 80` | Speak HTTP by hand |
| `nc -w 3 host 22` | Time out after 3 seconds (shows the SSH banner) |

## ufw: the firewall

`ufw` (Uncomplicated Firewall) is a front end for the kernel's
**netfilter** packet filter. All commands need `sudo`.

| Command | What it does |
|---|---|
| `sudo ufw status verbose` | State, default policies, rules |
| `sudo ufw status numbered` | Rules with numbers (for deleting) |
| `sudo ufw default deny incoming` | Block all incoming by default |
| `sudo ufw default allow outgoing` | Allow all outgoing by default |
| `sudo ufw allow OpenSSH` | Allow an application profile (`sudo ufw app list`) |
| `sudo ufw allow 22/tcp` | Allow a port |
| `sudo ufw allow 80,443/tcp` | Several ports |
| `sudo ufw allow 6000:6007/tcp` | A port range |
| `sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp` | Only from your LAN |
| `sudo ufw deny from 203.0.113.7` | Block one address |
| `sudo ufw limit 22/tcp` | Rate-limit (blocks IPs with 6+ connections in 30 s) |
| `sudo ufw delete allow 80/tcp` | Delete a rule by repeating it |
| `sudo ufw delete 3` | Delete rule number 3 |
| `sudo ufw enable` / `disable` | Turn the firewall on / off |
| `sudo ufw reload` | Reload rules |
| `sudo ufw reset` | Delete all rules and disable |

!!! danger "⚠️ VM only: don't lock yourself out"
    On a remote machine, always run `sudo ufw allow OpenSSH` (or your SSH
    port) **before** `sudo ufw enable`. Practice firewall rules in your VM,
    from its console, with a snapshot ready.

A safe baseline for a server:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status verbose
```

## nmcli: NetworkManager

Desktop systems like Mint manage networks with **NetworkManager**. Ubuntu
Server uses **netplan** with systemd-networkd instead.

| Command | What it does |
|---|---|
| `nmcli device status` | Devices and their state |
| `nmcli connection show` | Saved connection profiles |
| `nmcli connection show --active` | Active connections |
| `nmcli device wifi list` | Visible Wi-Fi networks |
| `nmcli --ask device wifi connect 'HomeNet'` | Connect to Wi-Fi, prompting for the password |
| `nmcli connection up 'HomeNet'` / `down` | Activate / deactivate a profile |
| `nmcli connection modify 'Wired connection 1' ipv4.method manual ipv4.addresses 192.168.1.50/24 ipv4.gateway 192.168.1.1 ipv4.dns 1.1.1.1` | Set a static IP (then `up` the connection) |
| `nmcli connection modify 'Wired connection 1' ipv4.method auto` | Back to DHCP |
| `nmcli general status` | Overall state and connectivity |

## Common ports

| Port | Protocol | Service | Port | Protocol | Service |
|---|---|---|---|---|---|
| 20, 21 | TCP | FTP | 443 | TCP (UDP for HTTP/3) | HTTPS |
| 22 | TCP | SSH, SCP, SFTP | 445 | TCP | SMB (Windows file sharing) |
| 23 | TCP | Telnet (insecure) | 465 / 587 | TCP | SMTP submission (TLS / STARTTLS) |
| 25 | TCP | SMTP (mail between servers) | 631 | TCP | IPP printing (CUPS) |
| 53 | UDP and TCP | DNS | 993 / 995 | TCP | IMAPS / POP3S |
| 67, 68 | UDP | DHCP server, client | 2049 | TCP | NFS |
| 80 | TCP | HTTP | 3306 | TCP | MySQL / MariaDB |
| 110 | TCP | POP3 | 3389 | TCP | RDP (Windows Remote Desktop) |
| 123 | UDP | NTP (time sync) | 5353 | UDP | mDNS (`.local` names) |
| 143 | TCP | IMAP | 5432 | TCP | PostgreSQL |
| 6379 | TCP | Redis | 8080 | TCP | HTTP alternate, dev servers |
| 9092 | TCP | Kafka | 27017 | TCP | MongoDB |

Ports below 1024 are **privileged**: only root (or a process with
`CAP_NET_BIND_SERVICE`) can listen on them. The full list is in
`/etc/services`: `grep -w 5432 /etc/services`.

## CIDR quick table

An IPv4 address is 32 bits. In **CIDR notation**, `/N` means the first N bits
are the network part; the rest identify hosts.

| CIDR | Netmask | Addresses | Usable hosts | Typical use |
|---|---|---|---|---|
| `/32` | 255.255.255.255 | 1 | 1 | A single host (firewall rules) |
| `/31` | 255.255.255.254 | 2 | 2 | Point-to-point links |
| `/30` | 255.255.255.252 | 4 | 2 | Tiny link networks |
| `/29` | 255.255.255.248 | 8 | 6 | Small server blocks |
| `/28` | 255.255.255.240 | 16 | 14 | |
| `/27` | 255.255.255.224 | 32 | 30 | |
| `/26` | 255.255.255.192 | 64 | 62 | |
| `/25` | 255.255.255.128 | 128 | 126 | |
| `/24` | 255.255.255.0 | 256 | 254 | A typical home or office LAN |
| `/20` | 255.255.240.0 | 4,096 | 4,094 | Cloud subnets |
| `/16` | 255.255.0.0 | 65,536 | 65,534 | A cloud VPC, `192.168.0.0/16` |
| `/12` | 255.240.0.0 | 1,048,576 | | `172.16.0.0/12` (private) |
| `/8` | 255.0.0.0 | 16,777,216 | | `10.0.0.0/8` (private) |

Usable hosts = addresses − 2 (the network address and the broadcast
address), except for `/31` and `/32`.

| Range | Meaning |
|---|---|
| `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` | **Private** addresses (RFC 1918), not routed on the internet |
| `127.0.0.0/8` | Loopback: this machine |
| `169.254.0.0/16` | Link-local: no DHCP server answered |
| `100.64.0.0/10` | Carrier-grade NAT (shared ISP space) |
| `0.0.0.0/0` | "Everything": the default route |
| `::1/128`, `fe80::/10` | IPv6 loopback, IPv6 link-local |
