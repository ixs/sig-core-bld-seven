#!/bin/bash
set -e

##
## Automatically extract a SRPM and apply a buildpatch.
## Add a note to the changelog and produce a new SRPM
## with the included changes.
##


PROG=$(basename $0)

# Rootdir for patches
PATCHROOT=/home/rebuild/sig-core-bld-seven/patches
RESULTDIR=/home/rebuild/patched
WORKDIR=$(mktemp -p "${TMPDIR:-/tmp/}" -d rpmdir-XXXX) || exit 255
AUTHOR="CentOS Buildsystem <devnull@centos.org>"


# Sanitychecks
if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
  echo "This script is expecting to be called by the buildsystem."
  echo "Manual use: $PROG <pkgname> <srpm> <arch>"
  exit 254
else
  PKGNAME=$1
  SRPM=$2
  ARCH=$3
fi

if [ ! -f $SRPM ]; then
  echo "Could not find $SRPM file"
  exit 253
else
  RPMNAME=$(rpm -qp --queryformat='%{n}' $SRPM 2> /dev/null)
  VER=$(rpm -qp --queryformat='%{v}' $SRPM 2> /dev/null)
  REL=$(rpm -qp --queryformat='%{r}' $SRPM 2> /dev/null)
fi

if [ $PKGNAME != $RPMNAME ]; then
  echo "PKGNAME $PKGNAME does not match NAME $RPMNAME of the SRPM."
  exit 252
fi

PATCH=""
for file in \
  ${RPMNAME}-${VER}-${REL}.${ARCH}.patch \
  ${RPMNAME}-${VER}-${REL}.patch \
  ${RPMNAME}-${VER}.${ARCH}.patch \
  ${RPMNAME}-${VER}.patch \
  ${RPMNAME}.${ARCH}.patch \
  ${RPMNAME}.patch
do
  if [ -f ${PATCHROOT}/${file} ]; then
    echo "Patch $file found".
    PATCH=$file
    break
  fi
done

if [ -z $PATCH ]; then
  echo "No patchfile for $PKGNAME found. Skipping."
  exit 0
fi

# Unpack SRPM
rpm -i -D "_topdir ${WORKDIR}" $SRPM 2> /dev/null
pushd ${WORKDIR}
patch -p 1 < ${PATCHROOT}/$PATCH

# Add changelog entry
sed -i -e "/^%changelog/a* $(date +'%a %b %d %Y') ${AUTHOR} - ${VER}-${REL}\n- Automatically applied buildpatch $PATCH\n" ${WORKDIR}/SPECS/${PKGNAME}.spec

popd

RPM=$(rpmbuild -bs -D "_topdir ${WORKDIR}" ${WORKDIR}/SPECS/${PKGNAME}.spec 2> /dev/null | sed -e 's/Wrote: //')
if [ ! -f $RPM ];
  echo "Problem building RPM. Please check ${WORKDIR}."
  exit 251
fi
mv ${RPM} ${RESULTDIR}
echo ${RESULTDIR}/$(basename ${RPM})

# Cleanup
rm -rf ${WORKDIR}
exit 0
