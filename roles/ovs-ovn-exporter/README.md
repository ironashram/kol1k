# OVS/OVN Exporter Ansible Role

This Ansible role installs and configures [ovs-exporter](https://github.com/lucadelmonte/ovs_exporter) and [ovn-exporter](https://github.com/lucadelmonte/ovn_exporter) for OpenStack deployments managed by Kolla-Ansible.

## Overview

Kolla-Ansible deploys OVS/OVN components in Docker containers. This role configures the exporters with the correct paths to access sockets, logs, and PID files from within the Kolla container environment.

### Deployment Strategy

| Exporter | Deploy On | Port | Monitors |
|----------|-----------|------|----------|
| **ovs-exporter** | Compute + Network nodes | 9475 | OVS bridges, flows, ovn-controller |
| **ovn-exporter** | Network/Controller nodes | 9476 | OVN NB/SB databases, northd |

Both exporters complement each other for complete OVN/OVS visibility.

## Prerequisites

Before running this role, ensure Kolla-Ansible is configured to expose the required sockets to the host.

### For OVS Exporter (ovn-controller)

Add to your Kolla configuration (`group_vars/all/ovs-exporter.yml`):

```yaml
ovn_controller_extra_volumes:
  - "/var/run/openvswitch/ovn-controller:/run/ovn:rw"
```

### For OVN Exporter (NB/SB databases, northd)

Add to your Kolla configuration (`group_vars/all/ovn-exporter.yml`):

```yaml
ovn_nb_db_extra_volumes:
  - "/run/ovn:/run/ovn:rw"

ovn_sb_db_extra_volumes:
  - "/run/ovn:/run/ovn:rw"

ovn_northd_extra_volumes:
  - "/run/ovn:/run/ovn:rw"
```

OVS sockets are **not required** for the OVN exporter. `system_id` and `hostname` labels derive from `os.Hostname()`; `system_type`/`system_version` come from `/etc/os-release`; NB/SB schema versions come from `GetSchema()` on the NB/SB databases.

Then reconfigure the OVN containers:

```bash
kolla-ansible -i inventory reconfigure -t ovn
```

## Role Variables

### General Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `exporter_install_dir` | `/usr/sbin` | Binary installation directory |
| `exporter_tmp_dir` | `/tmp` | Temporary directory for downloads |

### OVS Exporter Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `ovs_exporter_enabled` | `true` | Enable OVS exporter installation |
| `ovs_exporter_github_repo` | `lucadelmonte/ovs_exporter` | GitHub repository |
| `ovs_exporter_version` | `latest` | Version to install (`latest` or specific like `1.0.0`) |
| `ovs_exporter_port` | `9475` | Metrics endpoint port (default, not configurable via flags) |
| `ovs_exporter_service_name` | `ovs-exporter` | Systemd service name |
| `ovs_exporter_user` | `ovs_exporter` | System user to run the service |
| `ovs_exporter_group` | `ovs_exporter` | System group for the service |
| `ovs_exporter_description` | `Prometheus OVS Exporter` | Systemd service description |

### OVN Exporter Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `ovn_exporter_enabled` | `true` | Enable OVN exporter installation |
| `ovn_exporter_github_repo` | `lucadelmonte/ovn_exporter` | GitHub repository |
| `ovn_exporter_version` | `latest` | Version to install (`latest` or specific like `1.0.0`) |
| `ovn_exporter_port` | `9476` | Metrics endpoint port (default, not configurable via flags) |
| `ovn_exporter_service_name` | `ovn-exporter` | Systemd service name |
| `ovn_exporter_user` | `ovn_exporter` | System user to run the service |
| `ovn_exporter_group` | `ovn_exporter` | System group for the service |
| `ovn_exporter_description` | `Prometheus OVN Exporter` | Systemd service description |

### Kolla Path Overrides

The role includes sensible defaults for Kolla-Ansible deployments. Override these if your setup differs:

| Variable | Default |
|----------|---------|
| `kolla_ovs_socket` | `unix:/var/run/openvswitch/db.sock` |
| `kolla_ovs_data` | `/var/lib/docker/volumes/openvswitch_db/_data/conf.db` |
| `kolla_ovs_log` | `/var/log/kolla/openvswitch/ovsdb-server.log` |
| `kolla_vswitchd_log` | `/var/log/kolla/openvswitch/ovs-vswitchd.log` |
| `kolla_ovn_controller_log` | `/var/log/kolla/openvswitch/ovn-controller.log` |
| `kolla_ovn_controller_pid` | `/var/run/openvswitch/ovn-controller/ovn-controller.pid` |
| `kolla_ovn_nb_socket` | `unix:/run/ovn/ovnnb_db.sock` |
| `kolla_ovn_nb_ctl` | `unix:/run/ovn/ovnnb_db.ctl` |
| `kolla_ovn_nb_pid` | `/run/ovn/ovnnb_db.pid` |
| `kolla_ovn_nb_data` | `/var/lib/docker/volumes/ovn_nb_db/_data/ovnnb.db` |
| `kolla_ovn_nb_log` | `/var/log/kolla/openvswitch/ovn-nb-db.log` |
| `kolla_ovn_sb_socket` | `unix:/run/ovn/ovnsb_db.sock` |
| `kolla_ovn_sb_ctl` | `unix:/run/ovn/ovnsb_db.ctl` |
| `kolla_ovn_sb_pid` | `/run/ovn/ovnsb_db.pid` |
| `kolla_ovn_sb_data` | `/var/lib/docker/volumes/ovn_sb_db/_data/ovnsb.db` |
| `kolla_ovn_sb_log` | `/var/log/kolla/openvswitch/ovn-sb-db.log` |
| `kolla_ovn_northd_pid` | `/run/ovn/ovn-northd.pid` |
| `kolla_ovn_northd_log` | `/var/log/kolla/openvswitch/ovn-northd.log` |

## Usage Examples

### Dev Environment Playbook

This is the playbook used in our dev environment (`ovn-exporter.yaml`):

```yaml
- hosts: all
  roles:
    - ovs-ovn-exporter
```

To override the poll interval:

```yaml
- hosts: all
  roles:
    - role: ovs-ovn-exporter
      ovs_exporter_poll_interval: 30
      ovn_exporter_poll_interval: 30
```

Run it with the kolla-ansible inventory:

```bash
ansible-playbook -i /etc/kolla/multinode ovn-exporter.yaml
```

### Compute Nodes (OVS exporter only)

```yaml
- hosts: compute
  roles:
    - role: ovs-ovn-exporter
      ovn_exporter_enabled: false
```

### Network/Controller Nodes (both exporters)

```yaml
- hosts: network
  roles:
    - role: ovs-ovn-exporter
```

### Specific Versions

```yaml
- hosts: all
  roles:
    - role: ovs-ovn-exporter
      ovs_exporter_version: "1.2.0"
      ovn_exporter_version: "1.3.0"
```

## Prometheus Configuration

Add the following to `/etc/kolla/config/prometheus/prometheus.yml.d/ovs-ovn-exporter.yml`:

```yaml
scrape_configs:
  - job_name: ovs-exporter
    static_configs:
      - targets:
          - 'kol1k-compute-1:9475'
          - 'kol1k-compute-2:9475'

  - job_name: ovn-exporter
    static_configs:
      - targets:
          - 'kol1k-control-1:9476'

```

Then reconfigure Prometheus:

```bash
kolla-ansible reconfigure -i /etc/kolla/multinode -t prometheus
```

## Running the Playbook

The role automatically determines which exporter to install based on inventory group membership:
- **OVS exporter**: Installed on hosts in the `openvswitch` group
- **OVN exporter**: Installed on hosts in the `ovn-database` group

### Dev Environment

```bash
ansible-playbook -i /etc/kolla/multinode ovn-exporter.yaml
```

Dry run:

```bash
ansible-playbook -i /etc/kolla/multinode ovn-exporter.yaml --check
```

Limit to a single host:

```bash
ansible-playbook -i /etc/kolla/multinode ovn-exporter.yaml --limit kol1k-compute-1
```

## What the Role Does

1. **Creates system group** for the exporter service
2. **Creates system user** with home directory in `/var/lib/{service}`
3. **Creates data directory** with correct ownership
4. **Downloads release** from GitHub (latest or specified version)
5. **Extracts and installs binary** to `/usr/sbin`
6. **Sets capabilities** on binary (`cap_sys_admin,cap_sys_nice,cap_dac_override+ep`)
7. **Installs systemd service** from template (uses `$OPTIONS` env var)
8. **Creates environment file** with Kolla-specific paths:
   - Debian/Ubuntu: `/etc/default/{ovs,ovn}-exporter`
   - RHEL/CentOS: `/etc/sysconfig/{ovs,ovn}-exporter`
9. **Creates systemd drop-in** for Kolla container dependencies
10. **Enables and starts** the services
11. **Cleans up** temporary files

## Systemd Dependencies

The role configures systemd to ensure exporters start after Kolla containers:

**OVS Exporter:**
- Requires: `kolla-openvswitch_db-container.service`

**OVN Exporter** (no OVS dependency):
- Requires: `kolla-ovn_nb_db-container.service`, `kolla-ovn_sb_db-container.service`
- Wants: `kolla-ovn_northd-container.service`
- `ExecStartPre` waits up to 120s for the NB/SB unix sockets to appear before starting (Kolla container units go active before the daemons inside open their sockets).

## Verification

After running the role, verify the exporters are working:

```bash
# Check service status
systemctl status ovs-exporter
systemctl status ovn-exporter

# Check OVS exporter metrics
curl -s http://localhost:9475/metrics | head -20

# Check OVN exporter metrics
curl -s http://localhost:9476/metrics | head -20

# Count available metrics
curl -s http://localhost:9475/metrics | wc -l
curl -s http://localhost:9476/metrics | wc -l
```

## Path Mapping Reference

### OVS Exporter Paths

| Component | Default Path | Kolla Path |
|-----------|--------------|------------|
| OVS socket | `unix:/var/run/openvswitch/db.sock` | `unix:/var/run/openvswitch/db.sock` |
| OVS data | `/etc/openvswitch/conf.db` | `/var/lib/docker/volumes/openvswitch_db/_data/conf.db` |
| OVS log | `/var/log/openvswitch/ovsdb-server.log` | `/var/log/kolla/openvswitch/ovsdb-server.log` |
| vswitchd log | `/var/log/openvswitch/ovs-vswitchd.log` | `/var/log/kolla/openvswitch/ovs-vswitchd.log` |
| ovn-controller log | `/var/log/openvswitch/ovn-controller.log` | `/var/log/kolla/openvswitch/ovn-controller.log` |
| ovn-controller PID | `/var/run/openvswitch/ovn-controller.pid` | `/var/run/openvswitch/ovn-controller/ovn-controller.pid` |

### OVN Exporter Paths

| Component | Default Path | Kolla Path |
|-----------|--------------|------------|
| NB socket | `unix:/run/openvswitch/ovnnb_db.sock` | `unix:/run/ovn/ovnnb_db.sock` |
| NB control | `unix:/run/openvswitch/ovnnb_db.ctl` | `unix:/run/ovn/ovnnb_db.ctl` |
| NB PID | `/run/openvswitch/ovnnb_db.pid` | `/run/ovn/ovnnb_db.pid` |
| NB data | `/var/lib/openvswitch/ovnnb_db.db` | `/var/lib/docker/volumes/ovn_nb_db/_data/ovnnb.db` |
| NB log | `/var/log/openvswitch/ovsdb-server-nb.log` | `/var/log/kolla/openvswitch/ovn-nb-db.log` |
| SB socket | `unix:/run/openvswitch/ovnsb_db.sock` | `unix:/run/ovn/ovnsb_db.sock` |
| SB control | `unix:/run/openvswitch/ovnsb_db.ctl` | `unix:/run/ovn/ovnsb_db.ctl` |
| SB PID | `/run/openvswitch/ovnsb_db.pid` | `/run/ovn/ovnsb_db.pid` |
| SB data | `/var/lib/openvswitch/ovnsb_db.db` | `/var/lib/docker/volumes/ovn_sb_db/_data/ovnsb.db` |
| SB log | `/var/log/openvswitch/ovsdb-server-sb.log` | `/var/log/kolla/openvswitch/ovn-sb-db.log` |
| northd PID | `/run/openvswitch/ovn-northd.pid` | `/run/ovn/ovn-northd.pid` |
| northd log | `/var/log/openvswitch/ovn-northd.log` | `/var/log/kolla/openvswitch/ovn-northd.log` |

## Handlers

The role provides the following handlers:

- `Restart ovs-exporter` - Restarts the OVS exporter service
- `Restart ovn-exporter` - Restarts the OVN exporter service
- `Reload systemd` - Reloads systemd daemon

## Grafana Dashboards

Pre-built dashboards are available in the `files/` directory:

| File | Description |
|------|-------------|
| `ovs-operational.json` | OVS operational metrics — bridge stats, flow counts, port traffic |
| `ovs-executive-sla-slo.json` | OVS executive view — SLA/SLO summary for management |
| `ovn-sla-slo-performance.json` | OVN SLA/SLO performance — NB/SB latency, northd health |
| `ovn-system-overview.json` | OVN system overview — logical topology, chassis status |

Import them via Grafana UI: **Dashboards → Import → Upload JSON file**.

## License

See repository license.
