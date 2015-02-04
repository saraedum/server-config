This directory contains Debian packages necessary for a freifunk server setup.
These packages are not available in Debian stable. Some are backports from
experimental, some are not available at all.

Add Existing Packages
=====================

To import e.g. batctl from debian/experimental, add the following to your sources.list:

    deb http://ftp.debian.org/debian experimental main
    deb-src http://ftp.debian.org/debian experimental main

You can then import the package:

    mkdir batctl
    cd batctl
    apt-get -t experimental download batctl:amd64
    apt-get -t experimental source batctl

If you need to modify the package, [the debian manuals](https://www.debian.org/doc/manuals/maint-guide/update.en.html) explain how to do this.

For example, if the package builds against a newer version of libc which is not present in debian/stable, you would do:

    cd batctl-2014.4.0
    dch -i
    # batctl (2014.4.0-1.1) experimental; urgency=low
    #
    # * Backport to debian/stable
    #
    # -- Julian Rueth <julian.rueth@fsfe.org>  Mon, 02 Feb 2015 14:33:39 +0000
    dpkg-buildpackage -sa
    ./debian/rules clean

Finally, add the relevant files to the git repository:

    git add batctl-2014.4.0 batctl_2014.4.0-1.1_amd64.deb batctl_2014.4.0-1.1.debian.tar.gz batctl_2014.4.0-1.1.dsc batctl_2014.4.0.orig.tar.gz batctl-dbg_2014.4.0-1.1_amd64.deb

(The author is by no means an expert in Debian packaging. Feel free to improve on this.)

Configuration Packages (which do not overwrite existing files)
==============================================================

To create a package which provides architecture-independent files, e.g. configuration, you can do the following:

    mkdir -p freifunk-fastd/freifunk-fastd
    cd freifunk-fastd/freifunk-fastd
    DEBFULLNAME="Julian Rueth" dh_make --indep --copyright mit --email julian.rueth@fsfe.org --native --packagename freifunk-fastd_1
    rm debian/README.* debian/*.{ex,EX}
    mkdir files

You need to adapt some of the files in `debian/`.

`debian/changelog`:

    --- a/debian/freifunk-fastd/freifunk-fastd/debian/changelog
    +++ b/debian/freifunk-fastd/freifunk-fastd/debian/changelog
    @@ -1,4 +1,4 @@
    -freifunk-fastd (1) unstable; urgency=low
    +freifunk-fastd (1) experimental; urgency=low
     
       * Initial Release.

`debian/control`:

    --- a/debian/freifunk-fastd/freifunk-fastd/debian/control
    +++ b/debian/freifunk-fastd/freifunk-fastd/debian/control
    @@ -1,15 +1,11 @@
     Source: freifunk-fastd
    -Section: unknown
    +Section: freifunk
     Priority: extra
     Maintainer: Julian Rueth <julian.rueth@fsfe.org>
     Build-Depends: debhelper (>= 8.0.0)
     Standards-Version: 3.9.3
    -Homepage: <insert the upstream URL, if relevant>
    -#Vcs-Git: git://git.debian.org/collab-maint/freifunk-fastd.git
    -#Vcs-Browser: http://git.debian.org/?p=collab-maint/freifunk-fastd.git;a=summary
     
     Package: freifunk-fastd
     Architecture: all
    -Depends: ${misc:Depends}
    -Description: <insert up to 60 chars description>
    - <insert long description, indented with spaces>
    +Depends: ${misc:Depends}, fastd (>= 17)
    +Description: fastd configuration for a VPN server
    
`debian/freifunk-fastd.install`:

    @@ -0,0 +1 @@
    +files/* /

Copy the files you want to distribute to `files/`:

    mkdir -p files/etc/fastd/freifunk
    cp ... files/etc/fastd/freifunk/fastd.conf

Build your configuration package with `dpkg-buildpackage -sa`.

Configuration Packages (which overwrite existing files)
=======================================================

Would best be created with [config-package-dev](http://debathena.mit.edu/config-package-dev/).

Debian Repository
=================

We can create an apt repository in /var/www/apt with aptly:

    apt-get install aptly
    mkdir -p /var/aptly
    ln -s /var/aptly/public /var/www/apt
    aptly -config=aptly.conf repo create -distribution=experimental -component=main freifunk
    aptly -config=aptly.conf repo add freifunk batctl/
    aptly -config=aptly.conf publish repo freifunk freifunk

The packages will be signed with your default GnuPG key. To use the repository
in apt.sources you need to import the corresponding public key with apt-key:

    gpg --armor --export my@mail.com > gpg.keys
    apt-key add gpg.keys

To use the repository, add the following to /etc/apt/sources.list:

    deb http://your-server/apt/freifunk experimental main

To add more packages to the repository:

    aptly -config=aptly.conf repo add freifunk DIR
    aptly -config=aptly.conf publish update experimental freifunk

