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
if [ ! -e bin/generate-zbm ] || [ ! -e docs/CHANGELOG.md ]; then
  error "ERROR: run this script from the root of the zfsbootmenu tree"
fi

# Only tag releases from master or a compatible release-tracking branch
release_branch="$(git rev-parse --abbrev-ref HEAD)" || release_branch=""
case "${release_branch}" in
  master)
    echo "Tagging release from master branch"
    ;;
  "v${release%.*}.x"|"v${release%%.*}.x")
    echo "Tagging release from version-tracking branch"
    ;;
  *)
    error "ERROR: attempt to tag release on incompatible branch"
    ;;
esac

# Only allow changes to CHANGELOG.md when tagging releases
# shellcheck disable=SC2143
if [ -n "$(git status --porcelain=v1 | grep -v '.. docs/CHANGELOG.md$')" ]; then
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

# update version in documentation
sed -i "s/^release = '.*'\$/release = '${release}'/" docs/conf.py

# Synchronize man pages with POD documentation
if [ ! -x releng/rst2help.sh ]; then
  error "ERROR: unable to convert documentation"
fi

if ! out="$( releng/rst2help.sh )" ; then
  error "ERROR: ${out}"
fi

if ! out="$( releng/update-includes.sh )" ; then
  error "ERROR: ${out}"
fi

if ! out="$( cd docs && make gen-man SPHINXOPTS='-t manpages' )" ; then
  error "ERROR: ${out}"
fi

if [ -d docs/man/dist/_static ] && ! out="$( rm -r docs/man/dist/_static )"; then
  error "ERROR: failed to remove docs/man/dist/_static"
fi

# Generate a short history for CHANGELOG.md
# git log --format="* %h - %s (%an)" v1.4.1..HEAD

# Extract release notes for this version
relnotes=$(mktemp)
# shellcheck disable=SC2064
trap "rm -f ${relnotes}" 0

awk < docs/CHANGELOG.md > "${relnotes}" '
  BEGIN{ hdr=0; }

  /^## /{
    if (hdr) exit 0;
    hdr=1;
    sub(/^## /, "", $0);
    sub(/ \(.*\)$/, "", $0);
  }

  {
    if (hdr < 1) next;
    print;
  }'

# Make sure release notes refer to this version
if ! (head -n 1 "${relnotes}" | grep -q "ZFSBootMenu ${tag}\b"); then
  error "ERROR: Add '## ZFSBootMenu ${tag}' header to docs/CHANGELOG.md"
fi

# Update version in generate-zbm
if [ ! -x releng/version.sh ]; then
  error "ERROR: unable to update release version"
fi

if ! out="$( releng/version.sh -v "${release}" -u )"; then
  error "ERROR: ${out}"
fi

# Push updates for the release
git add bin/generate-zbm docs/ zfsbootmenu/zbm-release zfsbootmenu/help-files/
git commit -m "Bump to version ${release}"

# Publish release, as prerelease if version contains alphabetics
if echo "${release}" | grep -q "[A-Za-z]"; then
  prerelease=( "--prerelease" )
else
  prerelease=( )
fi

mkdir -p "releng/assets/${release}"

asset_dir="$( realpath -e "releng/assets/${release}" )"
asset_files=()
assets=()

# Create binary assets
if ! releng/make-binary.sh "${release}"; then
  error "ERROR: unable to make release assets, exiting!"
fi

# Sign the binary assets
if ! releng/sign-assets.sh "${release}"; then
  error "ERROR: unable to sign release assets, exiting!"
fi

for style in release recovery; do
  assets+=( "zfsbootmenu-${style}-${arch}-v${release}-vmlinuz.EFI" )
  assets+=( "zfsbootmenu-${style}-${arch}-v${release}.tar.gz" )
done

for asset in "${assets[@]}" ; do
  f="${asset_dir}/${asset}"
  [ -f "${f}" ] || error "ERROR: missing release asset ${f}"
  asset_files+=( "${f}" )
done

for f in sha256.{txt,sig}; do
  [ -f "${asset_dir}/${f}" ] || error "ERROR: missng sum file ${asset_dir}/${f}"
  asset_files+=( "${asset_dir}/${f}" )
done

# github-cli does not automatically strip header that hub uses for a title
sed -i '1,/^$/d' "${relnotes}"

echo "Release ${release} ready to push and tag"
while true; do
  echo "Continue? Yes/[No]"
  read -r response
  case "${response,,}" in
    yes|y)
      break
      ;;
    no|n|"")
      error "Release aborted by user request; clean up your local branch!"
      ;;
    *)
      echo "Unrecognized response, please answer 'yes' or 'no'"
      ;;
  esac
done

if ! git push; then
  error "ERROR: failed to push to default branch; release aborted"
fi

if ! gh release create "${tag}" "${prerelease[@]}" \
    --target "${release_branch}" -F "${relnotes}" \
    -t "ZFSBootMenu ${tag}" "${asset_files[@]}"; then
  error "ERROR: release creation failed"
fi

echo "Pushed and tagged release ${release}"

# Bump the verson to a development tag
dver="${release}+dev"
if ! (
  releng/version.sh -v "${dver}" -u || exit 1
  git add bin/generate-zbm zfsbootmenu/zbm-release || exit 1
  git commit -m "Bump to version ${dver}" || exit 1
  git push
); then
  error "ERROR: failed to update to development version"
fi
