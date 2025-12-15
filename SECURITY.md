# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| 1.0.x   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in Ultimate Linux Suite, please report it responsibly:

1. **Do not** open a public issue
2. Email the maintainers directly or use GitHub's private vulnerability reporting
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We aim to respond within 48 hours and will work with you to understand and address the issue.

## Security Design

### Queue System

The queue system is designed with security in mind:

- **No arbitrary command execution**: The dangerous `queue_command` function is disabled
- **Type whitelist**: Only allowed queue types are processed:
  - `pkg_install` / `pkg_remove`
  - `sysctl` (with key whitelist)
  - `service` (with action whitelist)
  - `file_write` (with path restrictions)

### Input Validation

All user inputs are validated:

- **Package names**: Alphanumeric with dots, dashes, underscores, plus signs (max 128 chars)
- **Sysctl keys**: Must match hardcoded whitelist
- **Service names**: Alphanumeric with dashes, underscores, dots, @ symbols
- **Service actions**: Only `start`, `stop`, `restart`, `reload`, `enable`, `disable`
- **File paths**: Restricted to specific directories (e.g., `/etc/sysctl.d/`)

### Sysctl Key Whitelist

Only these kernel parameters can be modified:

```
vm.swappiness
vm.vfs_cache_pressure
vm.dirty_ratio
vm.dirty_background_ratio
vm.dirty_expire_centisecs
vm.dirty_writeback_centisecs
vm.laptop_mode
fs.file-max
net.ipv4.tcp_congestion_control
net.core.default_qdisc
net.ipv6.conf.all.disable_ipv6
net.ipv6.conf.default.disable_ipv6
net.core.rmem_max
net.core.wmem_max
net.core.somaxconn
net.core.netdev_max_backlog
net.ipv4.tcp_rmem
net.ipv4.tcp_wmem
net.ipv4.tcp_max_syn_backlog
kernel.nmi_watchdog
```

### File Permissions

- Queue file: Created with mode 600 (owner read/write only)
- Queue directory: Created with mode 700
- Log files: Created with appropriate user permissions

### Safe Execution Helpers

System operations use validated helper functions:

- `_safe_enable_zram()`: Validates size range (1MB-64GB)
- `_safe_set_thp()`: Validates mode (always/madvise/never)
- `_safe_set_cpu_governor()`: Validates against available governors
- `_safe_gsettings()`: Validates schema and key format

## Best Practices for Users

1. **Review the queue** before executing operations
2. **Run with least privilege** when possible (some features require root)
3. **Keep the suite updated** to get security fixes
4. **Don't modify** the validation whitelists unless you understand the implications
5. **Check logs** after operations for any anomalies

## Hardening Recommendations

For production/server use:

```bash
# Run syntax check before use
make test

# Review all queued operations
./ultimate.sh
# -> Queue Management -> Preview queue

# Check log files
cat ~/.ultimate-linux-suite/logs/suite-*.log
```

## Known Limitations

- The suite requires root/sudo for most system modifications
- Some operations cannot be fully sandboxed (e.g., package installation)
- External package repositories are trusted as-is

## Changelog

### v1.1.1 (Security Hardening)
- Removed dangerous `eval` command execution
- Added comprehensive input validation
- Implemented sysctl key whitelist
- Added service action whitelist
- Restricted file write paths
- Fixed word splitting vulnerabilities
- Added safe execution helpers
