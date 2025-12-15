# Troubleshooting Guide

Common issues and solutions for Ultimate Linux Suite.

## General Issues

### Permission Denied

**Problem:** Script fails with permission errors.

**Solution:**
```bash
# Run with sudo for system modifications
sudo ./ultimate.sh

# Make script executable if needed
chmod +x ultimate.sh
```

### Bash Version Error

**Problem:** Script complains about Bash version.

**Solution:**
```bash
# Check your Bash version
bash --version

# Requires Bash 4.0+
# Update Bash via your package manager if needed
```

### Script Not Found After Install

**Problem:** `ultimate-linux-suite` command not found after `make install`.

**Solution:**
```bash
# Verify installation
ls -la /usr/local/bin/ultimate-linux-suite

# Refresh PATH
source ~/.bashrc
# or
hash -r
```

## Package Installation Issues

### Package Not Found

**Problem:** Package installation fails, package not found.

**Causes:**
- Package name differs on your distribution
- Repository not enabled
- Package manager cache outdated

**Solution:**
```bash
# Update package cache
sudo apt update        # Debian/Ubuntu
sudo dnf check-update  # Fedora
sudo pacman -Sy        # Arch

# Check if package exists
apt search packagename   # Debian/Ubuntu
dnf search packagename   # Fedora
pacman -Ss packagename   # Arch
```

### GPG Key Errors

**Problem:** Repository signature verification fails.

**Solution:**
```bash
# Debian/Ubuntu - refresh keys
sudo apt-key adv --refresh-keys --keyserver keyserver.ubuntu.com

# Fedora
sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$(rpm -E %fedora)-primary
```

### Broken Dependencies

**Problem:** Package installation fails due to broken dependencies.

**Solution:**
Use the Recovery module's "Fix Broken Packages" option, or manually:

```bash
# Debian/Ubuntu
sudo apt --fix-broken install
sudo dpkg --configure -a

# Fedora
sudo dnf distro-sync
sudo dnf autoremove

# Arch
sudo pacman -Syu
```

## Driver Issues

### NVIDIA Driver Problems

**Problem:** NVIDIA driver installation fails or system won't boot after install.

**Solutions:**

1. Verify GPU detection:
```bash
lspci | grep -i nvidia
```

2. Check secure boot (disable for NVIDIA):
```bash
mokutil --sb-state
```

3. Recovery boot:
   - Boot to recovery mode
   - Remove NVIDIA drivers
   ```bash
   sudo apt purge '*nvidia*'  # Debian/Ubuntu
   sudo dnf remove '*nvidia*' # Fedora
   ```

4. Use nouveau temporarily:
```bash
sudo modprobe nouveau
```

### WiFi Not Working

**Problem:** WiFi adapter not detected or not working.

**Solutions:**

1. Check adapter detection:
```bash
lspci | grep -i wireless
lsusb | grep -i wireless
```

2. Check for blocked device:
```bash
rfkill list all
rfkill unblock wifi
```

3. Install firmware (use Recovery > Install Firmware):
```bash
# Debian/Ubuntu
sudo apt install firmware-linux-nonfree

# Check dmesg for firmware errors
dmesg | grep -i firmware
```

## Optimization Issues

### Sysctl Changes Not Persisting

**Problem:** Kernel parameters reset after reboot.

**Solution:**

Verify config file exists:
```bash
cat /etc/sysctl.d/99-ultimate-linux-suite.conf
```

Apply immediately:
```bash
sudo sysctl --system
```

### ZRAM Not Working

**Problem:** ZRAM fails to enable.

**Solutions:**

1. Check if module is available:
```bash
modinfo zram
```

2. Load module manually:
```bash
sudo modprobe zram
```

3. Check for existing swap:
```bash
swapon --show
# May need to disable existing swap first
sudo swapoff -a
```

### CPU Governor Not Changing

**Problem:** CPU governor won't change.

**Solutions:**

1. Check available governors:
```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
```

2. Verify cpufreq driver loaded:
```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver
```

3. Disable TLP/power-profiles-daemon temporarily:
```bash
sudo systemctl stop tlp
sudo systemctl stop power-profiles-daemon
```

## Queue System Issues

### Queue Not Saving

**Problem:** Queued items disappear.

**Solution:**
Check queue file permissions:
```bash
ls -la ~/.cache/ultimate-linux-suite/
# or (if running as root)
ls -la /var/cache/ultimate-linux-suite/
```

Create directory if missing:
```bash
mkdir -p ~/.cache/ultimate-linux-suite
```

### Queue Execution Fails

**Problem:** Some queue items fail during execution.

**Solution:**
- Check log file for errors
- Verify you have sudo/root access
- Items may require specific repositories

## Distribution-Specific Issues

### Debian/Ubuntu

**dpkg lock error:**
```bash
# Kill stuck processes
sudo killall apt apt-get dpkg
# Remove lock files
sudo rm /var/lib/dpkg/lock*
sudo rm /var/cache/apt/archives/lock
sudo dpkg --configure -a
```

### Fedora

**DNF cache issues:**
```bash
sudo dnf clean all
sudo dnf makecache
```

### Arch

**Pacman key issues:**
```bash
sudo pacman-key --init
sudo pacman-key --populate archlinux
```

**Partial upgrade warning:**
```bash
# Always full upgrade on Arch
sudo pacman -Syu
```

## Debug Mode

Run with debug output for more information:

```bash
sudo ./ultimate.sh --debug
```

Check logs:
```bash
# As root
cat /var/log/ultimate-linux-suite/suite-$(date +%Y%m%d).log

# As regular user
cat ~/.ultimate-linux-suite/logs/suite-$(date +%Y%m%d).log
```

## Getting Help

If issues persist:

1. Run with `--debug` flag
2. Check the log file
3. Open an issue at https://github.com/Nerds489/ultimate-linux-suite/issues with:
   - Distribution and version
   - Error message
   - Relevant log output
   - Steps to reproduce
