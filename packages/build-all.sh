#!/bin/bash
set -ex

PACKAGES="\
    python3-jsonschema/python-jsonschema_2.3.0-1~bpo70+1.dsc \
    batctl/batctl_2014.4.0-1~bpo70+1.dsc \
    libuecc/libuecc_5-2~bpo70+1.dsc \
    fastd/fastd_17-2~bpo70+1.dsc \
    ffmap-d3/ffmap-d3_0.1.f07e857852-1.dsc \
    batman-adv/batman-adv-kernelland_2014.4.0-1.dsc \
    alfred/alfred_2014.4.0-1.dsc"

# check that all build dependencies are present
for dsc in $PACKAGES;do(
    PACKAGE=`dirname $dsc`
    BUILD="$PACKAGE/$PACKAGE"
    rm -rf "$BUILD"
    dpkg-source -x "$dsc" "$BUILD"
    cd "$BUILD"
    dpkg-checkbuilddeps
) done

# build the packages
for dsc in $PACKAGES;do(
    PACKAGE=`dirname $dsc`
    BUILD="$PACKAGE/$PACKAGE"
    cd "$BUILD"
    dpkg-buildpackage -us -uc -Zxz
) done
