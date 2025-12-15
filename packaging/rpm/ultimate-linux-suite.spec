Name:           ultimate-linux-suite
Version:        2.2.0
Release:        1%{?dist}
Summary:        Comprehensive Linux system management toolkit

License:        MIT
URL:            https://github.com/Nerds489/ultimate-linux-suite
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  bash

Requires:       bash >= 4.0
Requires:       coreutils
Requires:       grep
Requires:       sed
Requires:       gawk
Requires:       util-linux

Recommends:     pciutils
Recommends:     usbutils
Recommends:     dmidecode
Recommends:     smartmontools

Suggests:       flatpak

%description
Ultimate Linux Suite is a script-only, clone-and-run Linux toolkit
providing unified system management across multiple distributions.

Features include:
- Multi-distro package management abstraction
- Queue-based operation system
- 60+ application installer with cross-distro mapping
- System optimization (ZRAM, THP, BBR, swappiness)
- Driver management (NVIDIA, AMD, Intel, Broadcom WiFi)
- Recovery tools (DNS reset, orphan cleanup, package repair)
- Hardware and OS detection

%prep
%setup -q

%build
# Nothing to build - pure shell scripts

%check
# Basic syntax check
bash -n ultimate.sh

%install
rm -rf %{buildroot}

# Create directories
install -d %{buildroot}%{_datadir}/%{name}
install -d %{buildroot}%{_bindir}
install -d %{buildroot}%{_docdir}/%{name}
install -d %{buildroot}%{_mandir}/man1

# Install main script
install -m 755 ultimate.sh %{buildroot}%{_datadir}/%{name}/

# Install directories
cp -r lib %{buildroot}%{_datadir}/%{name}/
cp -r modules %{buildroot}%{_datadir}/%{name}/
cp -r menus %{buildroot}%{_datadir}/%{name}/
cp -r backends %{buildroot}%{_datadir}/%{name}/
cp -r apps %{buildroot}%{_datadir}/%{name}/
cp -r configs %{buildroot}%{_datadir}/%{name}/
cp -r drivers %{buildroot}%{_datadir}/%{name}/

# Create wrapper script
cat > %{buildroot}%{_bindir}/%{name} << 'EOF'
#!/bin/bash
exec /usr/share/ultimate-linux-suite/ultimate.sh "$@"
EOF
chmod 755 %{buildroot}%{_bindir}/%{name}

# Install documentation
install -m 644 README.md %{buildroot}%{_docdir}/%{name}/
install -m 644 CHANGELOG.md %{buildroot}%{_docdir}/%{name}/
install -m 644 LICENSE %{buildroot}%{_docdir}/%{name}/

%files
%license LICENSE
%doc README.md CHANGELOG.md
%{_bindir}/%{name}
%{_datadir}/%{name}/
%{_docdir}/%{name}/

%changelog
* Sat Dec 14 2024 Nerds489 <nerds489@github.com> - 1.0.0-1
- Initial release
- Multi-distro support (Debian, Ubuntu, Fedora, Arch, openSUSE, Kali, Mint, Parrot)
- Queue-based operation system
- 60+ apps with cross-distro package mapping
- System optimization (ZRAM, THP, BBR, swappiness)
- Driver management (NVIDIA, AMD, Intel, Broadcom WiFi, VM guests)
- Recovery tools (DNS reset, orphan cleanup, package repair)
