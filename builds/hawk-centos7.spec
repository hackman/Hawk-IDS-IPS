Name:		hawk
Version:	6.2
Release:	1
Summary:	Hawk IDS/IPS
License:	GPLv2
URL:		https://github.com/hackman/Hawk-IDS-IPS
Source0:	%{name}-%{version}.tgz
BuildArch:	noarch
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Requires:	perl perl-DBD-SQLite perl-DBD-Pg iptables iptables-services postgresql postgresql-server
Provides:	hawk
AutoReqProv: no

%description
This package provides the Hawk IDS/IPS system.
It provides log analisys and automatic blocking and unblocking
of IPs that bruteforce different services.
Currently it supports:
 * SSH
 * Postfix
 * Dovecot
 * Pure-FTPd
 * ProFTPd
 * cPanel
 * cPanel WebMail
 * DirectAdmin

%prep
%setup -q

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/etc/cron.d
mkdir -p %{buildroot}/etc/systemd/system
mkdir -p %{buildroot}/usr/sbin
mkdir -p %{buildroot}/usr/share/hawk
mkdir -p %{buildroot}/var/lib/hawk/{bin,lib}
mkdir -p %{buildroot}/var/log/hawk
touch %{buildroot}/var/lib/hawk/block-list
cp -a hawk.conf %{buildroot}/etc
cp -a hawk.pl %{buildroot}/usr/sbin
cp -a lib/parse_config.pm %{buildroot}/var/lib/hawk/lib
cp -a hawk.sql README LICENSE %{buildroot}/usr/share/hawk
cp -a hawk.service %{buildroot}/etc/systemd/system
cp -a hawk-unblock.sh setup_iptables.sh %{buildroot}/var/lib/hawk/bin
cp -a crontab-entry %{buildroot}/etc/cron.d/hawk
cp -a crontab-entry %{buildroot}/usr/share/hawk

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%config(noreplace) /etc/hawk.conf
%config(noreplace) /etc/systemd/system/hawk.service
%attr(700, root, root) /var/cache/hawk
%attr(700, root, root) /var/lib/hawk/bin
%attr(700, root, root) /var/lib/hawk/lib
%attr(600, root, root) /var/lib/hawk/block-list
%attr(755, root, root) /var/lib/hawk/lib/parse_config.pm
%attr(755, root, root) /var/log/hawk
%attr(700, root, root) /usr/sbin/hawk.pl
%attr(755, root, root) /usr/share/hawk
%attr(600, root, root) /etc/cron.d/hawk


%pre
%post
systemctl enable hawk

# Create the in_hawk chain and pass traffic trough it
/var/lib/hawk/bin/setup_iptables.sh

# Initialize the Hawk PostgreSQL DB and user (if pgsql is present on the machine)

# Initialize the Hawk SQLite DB if PgSQL is not present

%posttrans
#%changelog
#%include ChangeLog.md
