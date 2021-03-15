#!/bin/sh
# vim: softtabstop=2 shiftwidth=2 expandtab

error () {
  echo "$@"
  exit 1
}

# Accept optional leading "v" from the release version
release="${1#v}"
if [ -z "${release}" ] || [ $# -ne 1 ]; then
  error "USAGE: $0 <release>"
fi

# Validate release
if [ -n "$(echo "${release}" | sed 's/[0-9][A-Za-z0-9_.-]*$//')" ]; then
  error "ERROR: release must start with a number and contain [A-Za-z0-9_.-]"
fi

# Make sure paths make sense
if [ ! -e bin/generate-zbm ] || [ ! -e CHANGELOG.md ]; then
  error "ERROR: run this script from the root of the zfsbootmenu tree"
fi

# Only tag releases from master
if [ "$(git rev-parse --abbrev-ref HEAD)" != "master" ]; then
  error "ERROR: will not tag releases on any branch but master"
fi

# Only allow changes to CHANGELOG.md when tagging releases
# shellcheck disable=SC2143
if [ -n "$(git status --porcelain=v1 | grep -v '.. CHANGELOG.md$')" ]; then
  error "ERROR: will not tag release with non-changelog changes in tree"
fi

# x86_64 users are the primary consumers of ZFSBootMenu
# Releases should always be done on an x86_64 host, so that .EFI builds take place
arch="$( uname -m )"
if [ "${arch}" != "x86_64" ]; then
  error "Releases must always be tagged on x86_64 hosts so that EFI binaries can be built"
fi

# Make sure the tag has a leading "v"
tag="v${release}"

if git tag | grep -q "${tag}$"; then
  error "ERROR: desired tag already exists"
fi

echo "Will tag release version ${release} as ${tag}"

# Synchronize man pages with POD documentation
if [ ! -x releng/pod2man.sh ]; then
  error "ERROR: unable to convert documentation"
fi

releng/pod2man.sh "${release}"

# Generate a short history for CHANGELOG.md
# git log --format="* %h - %s (%an)" v1.4.1..HEAD

# Extract release notes for this version
relnotes=$(mktemp)
# shellcheck disable=SC2064
trap "rm -f ${relnotes}" 0

awk < CHANGELOG.md > "${relnotes}" '
  BEGIN{ hdr=0; }

  /^# /{
    if (hdr) exit 0;
    hdr=1;
    sub(/^# /, "", $0);
    sub(/ \(.*\)$/, "", $0);
  }

  {
    if (hdr < 1) exit 1;
    print;
  }'

# Make sure release notes refer to this version
if ! (head -n 1 "${relnotes}" | grep -q "ZFSBootMenu ${tag}\b"); then
  error "ERROR: Add '# ZFSBootMenu ${tag}' header to CHANGELOG.md"
fi

# Update version in generate-zbm
sed -i bin/generate-zbm -e "s/our \$VERSION.*/our \$VERSION = '${release}';/"

# Push updates for the release
git add bin/generate-zbm CHANGELOG.md man/
git commit -m "Bump to version ${release}"
git push

# Publish release, as prerelease if version contains alphabetics
if echo "${release}" | grep -q "[A-Za-z]"; then
  prerelease="--prerelease"
fi

# Create binary EFI file
if ! releng/make-binary.sh "${release}" ; then
  echo "Unable to make release assets, exiting!"
  exit 1
fi

assets="$( realpath -e "releng/assets/${release}" )"
efi_asset="${assets}/zfsbootmenu-${arch}-${release}.EFI"
components_asset="${assets}/zfsbootmenu-${arch}-${release}.tar.gz"
shasum_asset="${assets}/sha256sum.txt"

if [ ! -f "${efi_asset}" ]; then
  echo "EFI asset not found: ${efi_asset}"
  exit 1
fi

if [ ! -f "${components_asset}" ]; then
  echo "Components asset not found: ${components_asset}"
  exit 1
fi

if [ ! -f "${shasum_asset}" ]; then
  echo "sha256sum asset not found: ${shasum_asset}"
  exit 1
fi

# Use github-cli or hub to push the release
if command -v gh >/dev/null 2>&1; then
  # github-cli does not automatically strip header that hub uses for a title
  sed -i '1,/^$/d' "${relnotes}"
  gh release create "${tag}" ${prerelease} -F "${relnotes}" -t "ZFSBootMenu ${tag}" "${efi_asset}" "${components_asset}" "${shasum_asset}"
else
  error "ERROR: Please install github-cli"
fi
