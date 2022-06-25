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
     (Default: /build)

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

  -s Enable SSH support in the image

  -- <arguments>
      Additional arguments to the generate-zbm binary
EOF
}

CONFIGEVALS=()
GENARGS=()
ENABLE_SSH=
while getopts "hc:b:o:H:C:t:e:s" opt; do
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
    s)
      ENABLE_SSH="yes"
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

# Start processing everything after --
shift $((OPTIND-1))
GENARGS+=( "${@}" )

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

## Make sure major ZBM components exist at /zbm

[ -x /zbm/bin/generate-zbm ] || error "missing executable /zbm/bin/generate-zbm"

if [ -d /zbm/zfsbootmenu ]; then
  # With new structure, core library must be in /usr/share
  mkdir -p /usr/share
  ln -Tsf /zbm/zfsbootmenu /usr/share/zfsbootmenu \
    || error "unable to link core ZFSBootMenu libraries"

  # Link to initcpio hook components
  for cdir in initcpio/hooks initcpio/install; do
    mkdir -p "/usr/lib/${cdir}"
    ln -Tsf /zbm/${cdir}/zfsbootmenu /usr/lib/${cdir}/zfsbootmenu \
      || error "unable to link mkinitcpio script ${cdir}/zfsbootmenu"
  done

  # dracut module is in "dracut"
  dracutmod=/zbm/dracut
elif [ -d /zbm/90zfsbootmenu ]; then
  # dracut module is in "90zfsbootmenu" and contains everything
  dracutmod=/zbm/90zfsbootmenu
else
  error "/zbm does not appear to be a valid ZFSBootMenu tree"
fi

# Link to dracut module
mkdir -p /usr/lib/dracut/modules.d
ln -Tsf "${dracutmod}" /usr/lib/dracut/modules.d/90zfsbootmenu \
  || error "unable to link dracut module"

# generate-zbm configures dracut to look in /etc/zfsbootmenu/dracut.conf.d.
# Rather than override the default, just link to the in-repo defaults
dconfd="/etc/zfsbootmenu/dracut.conf.d"
if [ ! -d "${dconfd}" ]; then
  mkdir -p "${dconfd}" || error "unable to create dracut configuration directory"

  for cfile in /zbm/etc/zfsbootmenu/dracut.conf.d/*; do
    [ -e "${cfile}" ] || continue
    ln -Tsf "${cfile}" "${dconfd}/${cfile##*/}" || error "unable to link ${cfile}"
  done
fi

# Make sure the build root exists
: "${BUILDROOT:=/build}"
mkdir -p "${BUILDROOT}" || error "unable to create directory '${BUILDROOT}'"

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

GENARGS+=( "--config" "${ZBMCONF}" )

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

# Copy dropbear related files
if [ "${ENABLE_SSH}" == "yes" ] ; then
  dropsrc=${BUILDROOT}/etc/dropbear
  dropdst=/etc/dropbear/
  mkdir -p "${dropdst}" || error "unable to create dir ${dropdst}"
  cp "${dropsrc}/ssh_host"* ${dropdst} || error "unable to copy host keys"
  cp "${dropsrc}/authorized_keys" ${dropdst} || error "unable to copy authorized keys"
  ln -Tsf "${dropsrc}/dracut.conf.d/dropbear.conf" "${dconfd}/dropbear.conf" || error "unable to link dropbear dracut config"
fi

# If a custom dracut.conf.d exists, link to its contents in the default location
if [ -d "${BUILDROOT}/dracut.conf.d" ]; then
  for cfile in "${BUILDROOT}"/dracut.conf.d/*; do
    [ -e "${cfile}" ] || continue
    ln -Tsf "${cfile}" "${dconfd}/${cfile##*/}" || error "unable to link ${cfile}"
  done
fi

/zbm/bin/generate-zbm "${GENARGS[@]}" || error "failed to build images"

for f in "${ZBMWORKDIR}"/build/*; do
  [ "${f}" != "${ZBMWORKDIR}/build/*" ] || error "no images to copy to output"
  cp -R "${f}" "${ZBMOUTPUT}"
done
