#! /bin/sh
set -e

if [ -z "$DIR" ]; then
	DIR=batctl
fi
if [ -z "$OWNER" ]; then
	OWNER=
fi

# try to download source package
if [ "$1" != "snapshot" ]; then
	uscan --verbose --force-download
else
	MODULE=$(echo "${OWNER}/${DIR}" | sed 's/^\/*//')
	TMP="`mktemp -t -d`"
	git clone --bare "git://git.open-mesh.org/${MODULE}.git" "${TMP}"
	REV="$(git --git-dir "${TMP}" describe --long master | sed -e 's/^v*//' -e 's/-/+/g')"
	LONGREV="$(git --git-dir "${TMP}" rev-parse master)"
	TARNAME="${DIR}_${REV}.orig.tar"
	echo "${LONGREV}"
	git --git-dir "${TMP}" archive --format=tar --prefix="${DIR}-${REV}/" master -o "${TARNAME}"
	gzip -n -f "${TARNAME}"
	rm -rf "${TMP}"
fi
