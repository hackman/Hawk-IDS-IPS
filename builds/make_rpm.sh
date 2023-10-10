#!/bin/bash
files='hawk.pl lib etc db/hawk.pgsql db/hawk.sqlite README LICENSE bin/setup_iptables.sh bin/hawk-unblock.sh'
version=0.2

cd ..

# Get the version from hawk.pl directly
ver=$(grep 'my.*VERSION' hawk.pl)
ver=${ver#*\'}
version=${ver%\'*}

package=hawk-$version
archive=${package}.tgz


mkdir $package
cp -a $files $package/
tar cfz $archive $package
mv $archive ~/rpmbuild/SOURCES/
rm -rf $package

# spec is a variable so we can redefine it in the future for other RPM based distros
spec=hawk-centos7.spec
sed -i "/Version:/s/[0-9]\+\.[0-9]\+/$version/" builds/$spec
/usr/bin/cp -f builds/$spec ~/rpmbuild/SPECS/
echo "Archive $archive created"
