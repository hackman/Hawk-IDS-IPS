Name:		hawk
Version:	6.7
Release:	1
Summary:	Hawk IDS/IPS
License:	GPLv2
URL:		https://github.com/hackman/Hawk-IDS-IPS
Source0:	%{name}-%{version}.tgz
BuildArch:	noarch
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Requires:	perl perl-DBD-SQLite iptables iptables-services
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
 * Exim with Dovecot auth

%prep
%setup -q

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/etc/hawk
mkdir -p %{buildroot}/etc/cron.d
mkdir -p %{buildroot}/etc/systemd/system
mkdir -p %{buildroot}/usr/sbin
mkdir -p %{buildroot}/usr/share/hawk
mkdir -p %{buildroot}/usr/lib/hawk
mkdir -p %{buildroot}/var/log/hawk
mkdir -p %{buildroot}/var/run/hawk
mkdir -p %{buildroot}/var/cache/hawk
touch %{buildroot}/etc/hawk/block-list
cp -a etc/hawk/hawk.conf %{buildroot}/etc/hawk/
cp -a etc/sudoers.d/hawk %{buildroot}/etc/sudoers.d/
cp -a etc/systemd/system/hawk.service %{buildroot}/etc/systemd/system
cp -a etc/cron.d/hawk %{buildroot}/etc/cron.d/hawk
cp -a etc/cron.d/hawk %{buildroot}/usr/share/hawk/crontab-entry
cp -a hawk.pl %{buildroot}/usr/sbin
cp -a lib/parse_config.pm %{buildroot}/usr/lib/hawk/
cp -a db/hawk_db.pgsql db/hawk_db.sqlite README LICENSE %{buildroot}/usr/share/hawk
cp -a hawk-unblock.sh setup_iptables.sh %{buildroot}/usr/lib/hawk/bin

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%config(noreplace)     /etc/hawk/hawk.conf
%config(noreplace)     /etc/systemd/system/hawk.service
%attr(600, root, root) /etc/cron.d/hawk
%attr(700, root, root) /usr/lib/hawk
%attr(600, root, root) /usr/lib/hawk/block-list
%attr(755, root, root) /usr/lib/hawk/parse_config.pm
%attr(700, root, root) /usr/sbin/hawk.pl
%attr(755, root, root) /usr/share/hawk
%attr(755, root, root) /var/log/hawk
%attr(755, root, root) /var/run/hawk
%attr(700, root, root) /var/cache/hawk

%pre
%post
systemctl enable hawk

# Initialize the Hawk SQLite DB
if [ ! -f /var/cache/hawk/hawk.sqlite ]; then
	sqlite3 /var/cache/hawk/hawk.sqlite < /usr/share/hawk/hawk_db.sqlite
fi

# Create the in_hawk chain and pass traffic trough it
/var/lib/hawk/bin/setup_iptables.sh

%posttrans
#%changelog
#%include ChangeLog.md
