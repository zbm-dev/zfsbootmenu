#!/bin/bash
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
# shellcheck  disable=SC2001
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
  error "ERROR: releases must be tagged on x86_64 hosts to build EFI binaries"
fi

# Use github-cli or hub to push the release
if ! command -v gh >/dev/null 2>&1; then
  error "ERROR: github-cli is required to tag releases"
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

# Create binary assets
if ! releng/make-binary.sh "${release}"; then
  error "ERROR: unable to make release assets, exiting!"
fi

# Sign the binary assets
if ! releng/sign-assets.sh "${release}"; then
  error "ERROR: unable to sign release assets, exiting!"
fi

assets="$( realpath -e "releng/assets/${release}" )"
asset_files=()

for ext in EFI tar.gz; do
  f="${assets}/zfsbootmenu-${arch}-v${release}.${ext}"
  [ -f "${f}" ] || error "ERROR: missing boot image ${f}"
  asset_files+=( "${f}" )
done

for f in sha256.{txt,sig}; do
  [ -f "${assets}/${f}" ] || error "ERROR: missng sum file ${assets}/${f}"
  asset_files+=( "${assets}/${f}" )
done

# github-cli does not automatically strip header that hub uses for a title
sed -i '1,/^$/d' "${relnotes}"
gh release create "${tag}" ${prerelease} \
  -F "${relnotes}" -t "ZFSBootMenu ${tag}" "${asset_files[@]}"
