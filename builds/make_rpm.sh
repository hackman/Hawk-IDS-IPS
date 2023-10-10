#!/bin/bash
files='hawk.pl lib etc db/hawk_db.pgsql db/hawk_db.sqlite README LICENSE bin/setup_iptables.sh bin/hawk-unblock.sh'
version=0.3

cd ..

# Get the version from hawk.pl directly
ver=$(grep 'my.*VERSION' hawk.pl)
ver=${ver#*\'}
version=${ver%\'*}

package=hawk-$version
archive=${package}.tgz


mkdir $package
cp -a $files $package/
if [[ -f $archive ]]; then
	rm -f $archive
fi
tar cfz $archive $package
rpm_build_dir=~/rpmbuild
sources_dir=$rpm_build_dir/SOURCES/
if [[ ! -d $sources_dir ]]; then
	mkdir -p $sources_dir
fi
mv $archive $sources_dir/
rm -rf $package

# spec is a variable so we can redefine it in the future for other RPM based distros
spec=hawk-centos7.spec
sed -i "/Version:/s/[0-9]\+\.[0-9]\+/$version/" builds/$spec
/usr/bin/cp -f builds/$spec $rpm_build_dir/SPECS/
echo "Archive $archive created"

cd $rpm_build_dir
rpmbuild -v -ba SPECS/hawk-centos7.spec
