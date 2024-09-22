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

update_zfs() {
  local packages zpkg

  packages=()
  for zpkg in zfs libzfs zfs-lts libzfs-lts; do
    xbps-query -p pkgname "${zpkg}" >/dev/null 2>&1 || continue
    packages+=( "${zpkg}" )
  done

  [ "${#packages[@]}" -ge 1 ] || return 0
  xbps-install -uy "${packages[@]}"
}

update_xbps() {
  [ -n "${XBPS_UPDATE_COMPLETE}" ] && return 0
  readonly XBPS_UPDATE_COMPLETE="yes"
  xbps-install -Suy xbps || error "failed to update xbps"
}

usage() {
  cat <<EOF
Usage: $0 [options]
  OPTIONS:
  -h Display help text

  -b <buildroot>
     Specify path for build root
     (Default: /build)

  -o <output-directory>
     Specify path to output directory
     (Default: \${BUILDROOT}/build)

  -p <package>
     Install the named Void Linux package in the container
     before building. May be specified more than once to
     install more than one package.

  -t <tag>
     Specify specific tag or commit hash to fetch
     (Ignored if /zbm already contains a ZFSBootMenu tree)

  -u
    Update Void packages in the container
    (Kernel and ZFS packages will be ignored)

  -k <series>
    Install the specified Void kernel series, headers and all
    components necessary to build ZFS modules for the series

    The <series> argument takes the form "X.Y" for a major
    version X and minor version Y.

  -z
    Update the ZFS package when installing kernels with -k

  -V
     Do not attempt to update the version recorded in the source tree

  -e <statement>
     Specify a yq-go statement that will be evaluated as

       yq-go -e "<statement>" -i <config>

     to modify the configuration used for image building.
     May be specified more than once to chain modifications.

  -- <arguments>
      Additional arguments to the generate-zbm binary
EOF
}

hold_kern_zfs() {
  local kernels zpkg

  # Hold all kernel packages
  kernels="$(xbps-query -p pkgname --regex -s 'linux[0-9]+\.[0-9]')" || kernels=
  if [ -n "${kernels}" ]; then
    cut -d' ' -f2 <<< "${kernels}" | xargs xbps-pkgdb -m hold
  fi

  # Hold ZFS packages
  for zpkg in zfs libzfs zfs-lts libzfs-lts; do
    xbps-query -p pkgname "${zpkg}" >/dev/null 2>&1 || continue
    xbps-pkgdb -m hold "${zpkg}"
  done
}

PACKAGES=()
CONFIGEVALS=()
GENARGS=()

UPDATE=
UPDATE_ZFS=
KERN_SERIES=
SKIP_VERSIONING=

while getopts "hb:o:t:e:p:k:uzV" opt; do
  case "${opt}" in
    b)
      BUILDROOT="${OPTARG}"
      ;;
    o)
      ZBMOUTPUT="${OPTARG}"
      ;;
    t)
      ZBMTAG="${OPTARG}"
      ;;
    p)
      PACKAGES+=( "${OPTARG}" )
      ;;
    e)
      CONFIGEVALS+=( "${OPTARG}" )
      ;;
    u)
      UPDATE="yes"
      ;;
    k)
      KERN_SERIES="${OPTARG}"
      ;;
    z)
      UPDATE_ZFS="yes"
      ;;
    V)
      SKIP_VERSIONING="yes"
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

# Update packages, if desired
if [ -n "${UPDATE}" ]; then
  update_xbps
  hold_kern_zfs
  xbps-install -uy || error "failed to update packages"
  xbps-query -H | xargs -r xbps-pkgdb -m unhold
fi

if [ "${#PACKAGES[@]}" -gt 0 ]; then
  # Install all requested packages
  update_xbps
  xbps-install -y "${PACKAGES[@]}" || error "failed to install requested packages"
fi

if [ -n "${KERN_SERIES}" ]; then
  update_xbps

  if [ -n "${UPDATE_ZFS}" ]; then
    update_zfs || error "failed to update ZFS packages"
  fi

  # Install dkms and the requested kernel series
  xbps-install -uy dkms "linux${KERN_SERIES}" "linux${KERN_SERIES}-headers" \
    || error "failed to install requested kernel series"

  # Force a reconfigure to ensure the driver is build
  xbps-reconfigure -f zfs

  # Override kernel version to match the requested series by default
  CONFIGEVALS=(
    ".Kernel.Version = \"${KERN_SERIES}.*\""
    "${CONFIGEVALS[@]}"
  )
fi

# If a custom rc.pre.d exists, run every executable file therein
for rfile in "${BUILDROOT}"/rc.pre.d/*; do
  [ -x "${rfile}" ] || continue
  "${rfile}" || error "failed to run RC script ${rfile##*/}"
done

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

# Make sure the build root exists
: "${BUILDROOT:=/build}"
mkdir -p "${BUILDROOT}" || error "unable to create directory '${BUILDROOT}'"

# Make sure that the output directory exists
: "${ZBMOUTPUT:=${BUILDROOT}/build}"
mkdir -p "${ZBMOUTPUT}" || error "unable to create directory '${ZBMOUTPUT}'"

# Add forced overrides to the end of CONFIGEVALS
CONFIGEVALS+=(
  ".Global.ManageImages = true"
  ".Components.ImageDir = \"${ZBMOUTPUT}\""
  ".EFI.ImageDir = \"${ZBMOUTPUT}\""
  "del(.Global.BootMountPoint)"
)

# Use provided hostid
if [ -r "${BUILDROOT}/hostid" ]; then
  ln -Tsf "${BUILDROOT}/hostid" /etc/hostid \
    || error "failed to link hostid"
else
  rm -f /etc/hostid
fi

# Link all configuration files in standard location;
# go from most generic to most specificj
mkdir -p /etc/zfsbootmenu
confroots=(
  "/zbm/etc/zfsbootmenu"
  "/zbm/etc/zbm-builder"
  "${BUILDROOT}"
)
for confroot in "${confroots[@]}"; do
  for cfile in "config.yaml" "mkinitcpio.conf"; do
    [ -e "${confroot}/${cfile}" ] || continue
    ln -Tsf "${confroot}/${cfile}" "/etc/zfsbootmenu/${cfile}" \
      || error "unable to link mkinitcpio.conf"
  done

  for confd in "dracut.conf.d" "mkinitcpio.conf.d"; do
    mkdir -p "/etc/zfsbootmenu/${confd}"
    for cfile in "${confroot}/${confd}"/*; do
      [ -e "${cfile}" ] || continue
      ln -Tsf "${cfile}" "/etc/zfsbootmenu/${confd}/${cfile##*/}" \
        || error "unable to link ${cfile}"
    done
  done
done

# If a custom rc.d exists, run every executable file therein
for rfile in "${BUILDROOT}"/rc.d/*; do
  [ -x "${rfile}" ] || continue
  "${rfile}" || error "failed to run RC script ${rfile##*/}"
done

# Copy default configuration to temporary directory for modifications
ZBMCONF="${ZBMWORKDIR}/config.yaml"
cp "/etc/zfsbootmenu/config.yaml" "${ZBMCONF}" \
  || error "failed to copy configuration to working directory"

GENARGS+=( "--config" "${ZBMCONF}" )

# Apply CONFIGEVALS to override configuration in working directory
for ceval in "${CONFIGEVALS[@]}"; do
  yq-go eval "${ceval}" -i "${ZBMCONF}" \
    || error "failed to apply '${ceval}' to config"
done

# If possible, update the version recorded in the ZFSBootMenu repository
if [ "${SKIP_VERSIONING,,}" != "yes" ] && [ -x /zbm/releng/version.sh ]; then
  ( cd /zbm && ./releng/version.sh -u ) || true
fi

exec /zbm/bin/generate-zbm "${GENARGS[@]}"
