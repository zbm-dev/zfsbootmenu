#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

cleanup() {
  if [ -n "${ZBMWORKDIR}" ]; then
    rm -rf "${ZBMWORKDIR}"
  fi

  unset ZBMWORKDIR
}

error() {
  echo ERROR: "$@"
  exit 1
}

usage() {
  cat <<EOF
Usage: $0 [options]
  OPTIONS:
  -h Display help text

  -b <buildroot>
     Specify path for build root
     (Default: /zbm/contrib/docker)

  -c <configuration>
     Specify path to generate-zbm(5) configuration
     (Default: \${BUILDROOT}/config.yaml or \${BUILDROOT}/config.yaml.default)

  -o <output-directory>
     Specify path to output directory
     (Default: \${BUILDROOT}/build)

  -H <hostid>
     Specify path to hostid file
     (Default: \${BUILDROOT}/hostid)

  -C <cache>
     Specify path to zpool.cache file
     (Default: \${BUILDROOT}/zpool.cache)

  -t <tag>
     Specify specific tag or commit hash to fetch
     (Ignored if /zbm already contains a ZFSBootMenu tree)

  -e <statement>
     Specify a yq-go statement that will be evaluated as

       yq-go -e "<statement>" -i <config>

     to modify the configuration used for image building.
     May be specified more than once to chain modifications.
EOF
}

CONFIGEVALS=()
while getopts "hc:b:o:H:C:t:e:" opt; do
  case "${opt}" in
    c)
      ZBMCONF="${OPTARG}"
      ;;
    b)
      BUILDROOT="${OPTARG}"
      ;;
    o)
      ZBMOUTPUT="${OPTARG}"
      ;;
    H)
      HOSTID="${OPTARG}"
      ;;
    C)
      POOLCACHE="${OPTARG}"
      ;;
    t)
      ZBMTAG="${OPTARG}"
      ;;
    e)
      CONFIGEVALS+=( "${OPTARG}" )
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
  esac
done

ZBMWORKDIR=""
trap cleanup INT QUIT TERM EXIT
if ! ZBMWORKDIR="$(mktemp -d)"; then
  unset ZBMWORKDIR
  error "unable to allocate working directory"
fi

# Default tag is master unless specified in /etc/zbm-commit-hash
if [ -z "${ZBMTAG}" ]; then
  if [ -r "/etc/zbm-commit-hash" ]; then
    read -r ZBMTAG < /etc/zbm-commit-hash
  else
    ZBMTAG="master"
  fi
fi

# shellcheck disable=SC2010
if [ ! -d /zbm ] || ! ls -Aq /zbm 2>/dev/null | grep -q . >/dev/null 2>&1; then
  # /zbm is empty or does not exist, attempt to fetch the desired tag
  if ! curl -L -o "${ZBMWORKDIR}/zbm.tar.gz" \
        "https://github.com/zbm-dev/zfsbootmenu/archive/${ZBMTAG}.tar.gz"; then
    error "unable to fetch ZFSBootMenu tag '${ZBMTAG}'"
  fi

  mkdir -p /zbm

  # In Void, tar is gnutar, so --strip-components is available
  tar -xv --strip-components=1 -f "${ZBMWORKDIR}/zbm.tar.gz" -C /zbm
fi

# Make sure major ZBM components exist
[ -d /zbm/90zfsbootmenu ] || error "missing path /zbm/90zfsbootmenu"
[ -x /zbm/bin/generate-zbm ] || error "missing executable /zbm/bin/generate-zbm"

# Default BUILDROOT is in ZBM tree
: "${BUILDROOT:=/zbm/contrib/docker}"
[ -d "${BUILDROOT}" ] || error "Build root does not appear to exist"

# Make sure that the output directory exists
: "${ZBMOUTPUT:=${BUILDROOT}/build}"
mkdir -p "${ZBMOUTPUT}" || error "unable to create directory '${ZBMOUTPUT}'"

# Pick a default configuration if one was not provided
if [ -z "${ZBMCONF}" ]; then
  if [ -r "${BUILDROOT}/config.yaml" ]; then
    ZBMCONF="${BUILDROOT}/config.yaml"
  else
    ZBMCONF="${BUILDROOT}/config.yaml.default"
  fi
fi

# Configuration must exist
[ -r "${ZBMCONF}" ] || error "missing configuration '${ZBMCONF}'"
cp "${ZBMCONF}" "${ZBMWORKDIR}/config.yaml"

# ZBMCONF now points to local copy
ZBMCONF="${ZBMWORKDIR}/config.yaml"

# Add forced overrides to the end of CONFIGEVALS
CONFIGEVALS+=(
  ".Global.ManageImages = true"
  ".Components.ImageDir = \"${ZBMWORKDIR}/build/components\""
  ".EFI.ImageDir = \"${ZBMWORKDIR}/build\""
  "del(.Global.BootMountPoint)"
)

mkdir -p "${ZBMWORKDIR}/build" || error "unable to create build directory"

# Apply CONFIGEVALS to override configuration
for ceval in "${CONFIGEVALS[@]}"; do
  yq-go eval "${ceval}" -i "${ZBMCONF}" || error "failed to apply '${ceval}' to config"
done

# Make sure a hostid and cache, if provided, exist
if [ -z "${HOSTID}" ]; then
  [ -r "${BUILDROOT}/hostid" ] && HOSTID="${BUILDROOT}/hostid"
elif [ ! -r "${HOSTID}" ]; then
  error "missing hostid '${HOSTID}'"
fi

if [ -z "${POOLCACHE}" ]; then
  [ -r "${BUILDROOT}/zpool.cache" ] && POOLCACHE="${BUILDROOT}/zpool.cache"
elif [ ! -r "${POOLCACHE}" ]; then
  error "missing pool cache '${POOLCACHE}'"
fi

# Copy the hostid in place if specified, otherwise remove any hostid
if [ -n "${HOSTID}" ]; then
  cp "${HOSTID}" "/etc/hostid" || error "unable to copy hostid"
else
  rm -f /etc/hostid
fi

# Copy the pool cache in place if specified, otherwise remove any cache
if [ -n "${POOLCACHE}" ]; then
  mkdir -p /etc/zfs
  cp "${POOLCACHE}" /etc/zfs/zpool.cache || error "unable to copy pool cache"
else
  rm -f /etc/zfs/zpool.cache
fi

# Make sure that dracut can find the ZFSBootMenu module
[ -d /usr/lib/dracut/modules.d ] || error "dracut does not appear to be installed"
ln -sf /zbm/90zfsbootmenu /usr/lib/dracut/modules.d || error "unable to link dracut module"

/zbm/bin/generate-zbm --config "${ZBMCONF}" || error "failed to build images"

for f in "${ZBMWORKDIR}"/build/*; do
  [ "${f}" != "${ZBMWORKDIR}/build/*" ] || error "no images to copy to output"
  cp -R "${f}" "${ZBMOUTPUT}"
done
