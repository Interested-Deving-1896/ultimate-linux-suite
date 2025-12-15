#
# spec file for package ultimate-linux-suite
#
# Copyright (c) 2024 Nerds489
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). For more information, see the
# COPYING file in the top level directory.
#

Name:           ultimate-linux-suite
Version:        2.2.0
Release:        0
Summary:        Comprehensive Linux system management toolkit
License:        MIT
Group:          System/Management
URL:            https://github.com/Nerds489/ultimate-linux-suite
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

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
# Create directories
install -d %{buildroot}%{_datadir}/%{name}
install -d %{buildroot}%{_bindir}
install -d %{buildroot}%{_docdir}/%{name}

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
%dir %{_docdir}/%{name}
%{_docdir}/%{name}/*

%changelog
