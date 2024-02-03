#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

usage() {
  cat <<-EOF
	USAGE: $0 [OPTIONS] <tag> [zbm-commit-like]
	Create a container image for building ZFSBootMenu
	
	OPTIONS
	
	-h: Display this message and exit
	
	-r <path>:
	   Mount the specified path into the build container when installing
	   packages and configure XBPS to use the path as a package repository
	
	   (One path per argument; may be repeated as needed)
	
	-R <repo>:
	   Configure XBPS to use the specified Void Linux package repository
	
	   Default: https://repo-fastly.voidlinux.org/current/
	
	   (One repository per argument; may be repeated as needed)
	
	-k <kver>:
	   Include the specified Void Linux kernel series in the image; kernel
	   series take the form <major>.<minor> and correspond to Void packages
	   linux<kver> and linux<kver>-headers
	
	   Default: install 5.10, 5.15 and 6.1
	
	   (One version per argument; may be repeated as needed)
	
	-p <pkg>:
	   Include the specified Void Linux package in the image
	   (One package per argument; may be repeated as needed)
	
	
	ARGUMENTS
	
	<tag>:
	   Tag assigned to container image
	
	[zbm-commit-like]:
	   ZFSBootMenu commit hash, tag or branch name used by
	   default to build ZFSBootMenu images (default: master)
	EOF
}

set -o errexit

extra_pkgs=()

kern_series=()

# By default, mount tmpfs on /var/cache/xbps
host_mounts=( --mount "type=tmpfs,dst=/var/cache/xbps" )

host_repos=()

web_repos=()

while getopts "hr:R:k:p:" opt; do
  case "${opt}" in
    r)
      target="/pkgs/${#host_repos[@]}"
      host_repos+=( "${target}" )
      host_mounts+=( --mount "type=bind,src=${OPTARG},dst=${target},ro" )
      ;;
    R)
      # Sanitize repo arguments
      case "${OPTARG}" in
        /*|http://*|https://*)
          ;;
        *)
          echo "ERROR: '${OPTARG}' does not appear to be a valid repository"
          exit 1
          ;;
      esac

      web_repos+=( "${OPTARG}" )
      ;;
    k)
      kern_series+=( "linux${OPTARG}" )
      ;;
    p)
      extra_pkgs+=( "${OPTARG}" )
      ;;
    h)
      usage
      exit
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

# A tag for the image is required
tag="${1}"
if [ -z "${tag}" ]; then
  usage
  exit 1
fi

# If a commit hash is unspecified, try to pull HEAD from git
zbm_commit_hash="$2"
if [ -z "${zbm_commit_hash}" ]; then
  if ! zbm_commit_hash="$(git rev-parse HEAD 2>/dev/null)"; then
    unset zbm_commit_hash
  fi
fi

# Use default Void repo when nothing was specified
if [ "${#web_repos[@]}" -lt 1 ]; then
  web_repos=( "https://repo-fastly.voidlinux.org/current" )
fi

# Use default kernel series when nothing was specified
if [ "${#kern_series[@]}" -lt 1 ]; then
  kern_series=( "linux5.10" "linux5.15" "linux6.1" )
fi

# Populate the correspoding headers list
kern_headers=()
for _kern in "${kern_series[@]}"; do
  kern_headers+=( "${_kern}-headers" )
done

if [ -z "${ZBM_BUILDER}" ]; then
  ZBM_BUILDER="./releng/docker/build-init.sh"
fi

if [ ! -r "${ZBM_BUILDER}" ]; then
  echo "ERROR: cannot find build script at ${ZBM_BUILDER}"
  echo "Run from ZFSBootMenu root or override \$ZBM_BUILDER"
  exit 1
fi

maintainer="ZFSBootMenu Team, https://zfsbootmenu.org"
container="$(buildah from ghcr.io/void-linux/void-glibc-full:latest)"

buildah config --label author="${maintainer}" "${container}"

# Favor custom repositories
for repo in "${host_repos[@]}" "${web_repos[@]}"; do
  buildah run "${container}" sh -c "cat >> /etc/xbps.d/00-custom-repos.conf" <<-EOF
	repository=${repo}
	EOF
done

# Make sure image is up to date
buildah run "${host_mounts[@]}" "${container}" xbps-install -Syu xbps
buildah run "${host_mounts[@]}" "${container}" xbps-install -Syu

# Add extra packages, as desired
if [ "${#extra_pkgs[@]}" -gt 0 ]; then
  echo "INFO: adding extra Void packages: ${extra_pkgs[*]}"
  # shellcheck disable=SC2086
  buildah run "${host_mounts[@]}" "${container}" xbps-install -y "${extra_pkgs[@]}"
fi

# Prefer an LTS version over whatever Void thinks is current
buildah run "${container}" sh -c "cat > /etc/xbps.d/10-nolinux.conf" <<-EOF
	ignorepkg=linux
	ignorepkg=linux-headers
EOF

# Prevent initramfs kernel hooks from being installed
buildah run "${container}" sh -c "cat > /etc/xbps.d/15-noinitramfs.conf" <<-EOF
	noextract=/usr/libexec/mkinitcpio/*
	noextract=/usr/libexec/dracut/*
EOF

# Install ZFSBootMenu dependencies and components necessary to build images
buildah run "${host_mounts[@]}" "${container}" \
  sh -c 'xbps-query -Rp run_depends zfsbootmenu | xargs xbps-install -y'

buildah run "${host_mounts[@]}" "${container}" \
  xbps-install -y "${kern_series[@]}" "${kern_headers[@]}" \
  git zstd systemd-boot-efistub curl yq-go bash kbd \
  dracut mkinitcpio dracut-network gptfdisk iproute2 iputils parted \
  curl dosfstools e2fsprogs efibootmgr cryptsetup openssh util-linux kpartx

# Remove headers and development toolchain, but keep binutils for objcopy
buildah run "${container}" sh -c 'echo "ignorepkg=dkms" > /etc/xbps.d/10-nodkms.conf'
buildah run "${container}" xbps-pkgdb -m manual binutils
buildah run "${container}" xbps-remove -Roy dkms "${kern_headers[@]}"

# Record a commit hash if one is available
if [ -n "${zbm_commit_hash}" ]; then
  echo "${zbm_commit_hash}" | \
    buildah run "${container}" sh -c 'cat > /etc/zbm-commit-hash'
fi

buildah copy "${container}" "${ZBM_BUILDER}" /build-init.sh
buildah run "${container}" chmod 755 /build-init.sh

buildah config \
  --workingdir / \
  --entrypoint '[ "/build-init.sh" ]' \
  --cmd '[ ]' \
  "${container}"

buildah commit --rm "${container}" "${tag}"
