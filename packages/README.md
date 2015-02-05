Debian Packages
===============

This directory contains Debian packages necessary for a freifunk server setup.
These packages are not available in Debian stable. Some are backports from
unstable/experimental, some are not available in Debian at all.

Required Packages
-----------------

Install at least `build-essential dpkg-dev debian-keyring:unstable xzip dh-make`.

Backport a Package
-------------------

You can follow the procedure explained in the Debian
[wiki](https://wiki.debian.org/SimpleBackportCreation). For example, to
backport batctl, find a link to the appropriate `.dsc` file
[here](http://packages.debian.org/experimental/batctl), and do:

    mkdir batctl
    cd batctl
    dget -x http://ftp.debian.org/debian/pool/main/b/batctl/batctl_2014.4.0-1.dsc
    cd batctl-2014.4.0
    dpkg-checkbuilddeps # apt-get install what it complains about
    dch --local ~bpo70+ --distribution wheezy-backports "Rebuild for wheezy-backports."
    fakeroot debian/rules binary
    dpkg-buildpackage -us -uc -Zxz
    
If this worked, add the files necessary to build the `.deb` to git:

    cd ..
    echo 'batctl-2014.4.0' >> .gitignore
    echo 'batctl' >> .gitignore
    git add .gitignore *.dsc *.debian.tar.* *.orig*

Update a Package
----------------

To update an existing package to a newer upstream version, follow this
[guide](https://www.debian.org/doc/manuals/maint-guide/update.en.html). This
is, e.g., how alfred and batman-adv were created.

Create a New Package
--------------------

A good guide on creating a new package is
[here](https://www.debian.org/doc/manuals/packaging-tutorial/packaging-tutorial.pdf).
