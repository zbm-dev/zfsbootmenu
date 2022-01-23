#!/bin/sh
# vim: softtabstop=2 shiftwidth=2 expandtab

set -o errexit

# A tag for the image is required
tag="${1}"
if [ -z "${tag}" ]; then
  echo "USAGE: $0 <tag> [zbm-commit-like]"
  exit 1
fi

# If a commit hash is unspecified, try to pull HEAD from git
zbm_commit_hash="$2"
if [ -z "${zbm_commit_hash}" ]; then
  if ! zbm_commit_hash="$(git rev-parse HEAD 2>/dev/null)"; then
    unset zbm_commit_hash
  fi
fi

if [ -z "${ZBM_BUILDER}" ]; then
  ZBM_BUILDER="./releng/docker/zbm-build.sh"
fi

if [ ! -r "${ZBM_BUILDER}" ]; then
  echo "ERROR: cannot find build script at ${ZBM_BUILDER}"
  echo "Run from ZFSBootMenu root or override \$ZBM_BUILDER"
  exit 1
fi

maintainer="ZFSBootMenu Team, https://zfsbootmenu.org"
container="$(buildah from voidlinux/voidlinux:latest)"

buildah config --label author="${maintainer}" "${container}"

# Make sure image is up to date
buildah run "${container}" xbps-install -Syu xbps
buildah run "${container}" xbps-install -yu

# Prefer an LTS version over whatever Void thinks is current
buildah run "${container}" sh -c "cat > /etc/xbps.d/10-nolinux.conf" <<-EOF
	ignorepkg=linux
	ignorepkg=linux-headers
EOF

# Install ZFSBootMenu dependencies and components necessary to build images
buildah run "${container}" \
  sh -c 'xbps-query -Rp run_depends zfsbootmenu | xargs xbps-install -y'
buildah run "${container}" xbps-install -y \
  linux5.10 linux5.10-headers gummiboot-efistub curl yq-go bash kbd terminus-font \
  dracut mkinitcpio dracut-network gptfdisk iproute2 iputils parted curl \
  dosfstools e2fsprogs efibootmgr

# Remove headers and development toolchain, but keep binutils for objcopy
buildah run "${container}" sh -c 'echo "ignorepkg=dkms" > /etc/xbps.d/10-nodkms.conf'
buildah run "${container}" xbps-pkgdb -m manual binutils
buildah run "${container}" xbps-remove -Roy linux5.10-headers dkms
buildah run "${container}" sh -c 'rm -f /var/cache/xbps/*'

# Record a commit hash if one is available
if [ -n "${zbm_commit_hash}" ]; then
  echo "${zbm_commit_hash}" | \
    buildah run "${container}" sh -c 'cat > /etc/zbm-commit-hash'
fi

buildah copy "${container}" "${ZBM_BUILDER}" /zbm-build.sh
buildah run "${container}" chmod 755 /zbm-build.sh

buildah config \
  --workingdir / \
  --entrypoint '[ "/zbm-build.sh" ]' \
  --cmd '[ ]' \
  "${container}"

buildah commit --rm "${container}" "${tag}"
