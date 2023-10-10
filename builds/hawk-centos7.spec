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
mkdir -p %{buildroot}/etc/sudoers.d
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
cp -a hawk-unblock.sh %{buildroot}/usr/sbin
cp -a lib/parse_config.pm %{buildroot}/usr/lib/hawk
cp -a setup_iptables.sh %{buildroot}/usr/share/hawk
cp -a hawk_db.pgsql hawk_db.sqlite README LICENSE %{buildroot}/usr/share/hawk

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%config(noreplace)     /etc/hawk/hawk.conf
%config(noreplace)     /etc/systemd/system/hawk.service
%config(noreplace)     /etc/hawk/block-list
%attr(600, root, root) /etc/sudoers.d/hawk
%attr(600, root, root) /etc/cron.d/hawk
%attr(750, hawk, root) /usr/lib/hawk
%attr(755, root, root) /usr/lib/hawk/parse_config.pm
%attr(750, hawk, root) /usr/sbin/hawk.pl
%attr(700, root, root) /usr/sbin/hawk-unblock.sh
%attr(755, root, root) /usr/share/hawk
%attr(700, root, root) /usr/share/hawk/setup_iptables.sh
%attr(755, hawk, hawk) /var/log/hawk
%attr(755, hawk, hawk) /var/run/hawk
%attr(700, hawk, hawk) /var/cache/hawk

%pre
if ! getent passwd hawk > /dev/null; then
	useradd -d /var/cache/hawk -c "Hawk IDS/IPS" hawk
fi

%post
%systemd_post hawk.service


# Initialize the Hawk SQLite DB
if [ ! -f /var/cache/hawk/hawk.sqlite ]; then
	sqlite3 /var/cache/hawk/hawk.sqlite < /usr/share/hawk/hawk_db.sqlite
	chown hawk: /usr/share/hawk/hawk_db.sqlite
fi

# Create the in_hawk chain and pass traffic trough it
/usr/share/hawk/setup_iptables.sh

%postun
%systemd_postun_with_restart hawk.service

if getent passwd hawk > /dev/null; then
	userdel -r hawk
fi

%posttrans
#%changelog
#%include ChangeLog.md
