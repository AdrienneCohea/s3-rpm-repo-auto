#!/bin/bash
set -e

# Create a temporary directory for rpmbuild
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

mkdir -p $WORK_DIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Create a dummy script
cat <<EOF > $WORK_DIR/SOURCES/hello.sh
#!/bin/bash
echo "Hello, World!"
EOF

# Create a spec file
cat <<EOF > $WORK_DIR/SPECS/hello.spec
Name:           hello-world
Version:        1.0
Release:        1
Summary:        A simple hello world script
License:        MIT
BuildArch:      noarch

%description
A simple hello world script for testing RPM repositories.

%install
mkdir -p %{buildroot}/usr/bin
install -m 755 %{_sourcedir}/hello.sh %{buildroot}/usr/bin/hello.sh

%files
/usr/bin/hello.sh

%changelog
* Tue Apr 21 2026 Gemini CLI <gemini@example.com> - 1.0-1
- Initial build
EOF

# Build the RPM
rpmbuild -bb --define "_topdir $WORK_DIR" $WORK_DIR/SPECS/hello.spec

# Copy the resulting RPM to the current directory
mkdir -p test-artifacts
cp $WORK_DIR/RPMS/noarch/hello-world-1.0-1.noarch.rpm test-artifacts/
echo "Dummy RPM created: test-artifacts/hello-world-1.0-1.noarch.rpm"
