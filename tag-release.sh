#!/bin/sh

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
if [ ! -e bin/generate-zbm ] && [ ! -e CHANGELOG.md ]; then
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

# Make sure the tag has a leading "v"
tag="v${release}"

if git tag | grep -q "${tag}$"; then
  error "ERROR: desired tag already exists"
fi

echo "Will tag release version ${release} as ${tag}"

# Extract release notes for this version
relnotes=$(mktemp)
# shellcheck disable=SC2064
trap "rm -f ${relnotes}" 0

awk ' BEGIN{ hdr=0; }
  /^# /{ if (hdr) exit 0; hdr=1; }
  { if (hdr < 1) exit 1; sub("^# ", "", $0); print; }' < CHANGELOG.md > "${relnotes}";

# Make sure release notes refer to this version
if ! (head -n 1 "${relnotes}" | grep -q "ZFSBootMenu ${tag}\b"); then
  error "ERROR: Add '# ZFSBootMenu ${tag}' header to CHANGELOG.md"
fi

# Update version in generate-zbm
sed -i bin/generate-zbm -e "s/our \$VERSION.*/our \$VERSION = '${release}';/"

# Generate man pages from pod documentation

pod2man pod/generate-zbm.5.pod -c "config.yaml" \
  -r "${release}" -s 5 -n generate-zbm > man/generate-zbm.5

pod2man pod/zfsbootmenu.7.pod -c "ZFSBootMenu" \
  -r "${release}" -s 7 -n zfsbootmenu > man/zfsbootmenu.7

pod2man bin/generate-zbm -c "generate-zbm" \
  -r "${release}" -s 8 -n generate-zbm > man/generate-zbm.8

# Push updates for the release
git add bin/generate-zbm CHANGELOG.md man/
git commit -m "Bump to version ${release}"
git push

# Publish release, as prerelease if version contains alphabetics
if echo "${release}" | grep -q "[A-Za-z]"; then
  prerelease="--prerelease"
fi

# Hub creates the tag for us
hub release create ${prerelease} -F "${relnotes}" "${tag}"
