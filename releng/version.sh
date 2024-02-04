#!/bin/sh
# vim: softtabstop=2 shiftwidth=2 expandtab

usage() {
  cat <<-EOF
	USAGE: $0 [options]
	
	OPTIONS
	-h
	   Display this message and exit
	
	-u
	   Update zbm-release and generate-zbm version information
	
	-v <version>
	   Specify a particular version to use
	
	EOF
}

# This should always run in a subshell because it manipulates the environment
detect_version() (
  # Do not allow git to walk past the ZFSBootMenu tree to find a repository
  export GIT_CEILING_DIRECTORIES="${PWD}/.."

  # If git-describe does the job, the job is done
  version="$(git describe --tags HEAD 2>/dev/null)" || version=""

  case "${version}" in
    v[0-9]*) version="${version#v}"
  esac

  if [ -n "${version}" ]; then
    echo "${version}"
    return 0
  fi

  # Otherwise, use git-rev-parse if possible
  if branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"; then
    case "${branch}" in
      v[0-9]*) branch="${branch#v}"
    esac

    hash="$(git rev-parse --short HEAD 2>/dev/null)" || hash=""
    [ -n "${hash}" ] && version="${branch:-UNKNOWN} (${hash})"

    if [ -n "${version}" ]; then
      echo "${version}"
      return 0
    fi
  fi

  # Everything fell apart, so just try reading zbm-release
  relfile="zfsbootmenu/zbm-release"
  if [ -r "${relfile}" ]; then
    # shellcheck disable=SC2153
    # shellcheck disable=SC1090
    version="$( . "${relfile}" 2>/dev/null && echo "${VERSION}" )" || version=""

    if [ -n "${version}" ]; then
      echo "${version}"
      return 0
    fi
  fi

  # If there is no zbm-release, look to generate-zbm
  genzbm="bin/generate-zbm"
  if [ -r "${genzbm}" ]; then
    # shellcheck disable=SC2016
    if verline="$(grep 'our $VERSION[[:space:]]*=' "${genzbm}")"; then
      version="$(echo "${verline}" | head -n1 | sed -e "s/.*=[[:space:]]*['\"]//" -e "s/['\"].*//")" || version=""
      if [ -n "${version}" ]; then
        echo "${version}"
        return 0
      fi
    fi
  fi

  # There is apparently no version
  echo "UNKNOWN"
  return 1
)

update_version() {
  version="${1?a version is required}"

  # Write zbm-release
  if [ -d zfsbootmenu ] && [ -w zfsbootmenu ]; then
    echo "Updating zfsbootmenu/zbm-release"
    cat > zfsbootmenu/zbm-release <<-EOF
	NAME="ZFSBootMenu"
	PRETTY_NAME="ZFSBootMenu"
	ID="zfsbootmenu"
	ID_LIKE="void"
	HOME_URL="https://zfsbootmenu.org"
	DOCUMENTATION_URL="https://docs.zfsbootmenu.org"
	BUG_REPORT_URL="https://github.com/zbm-dev/zfsbootmenu/issues"
	SUPPORT_URL="https://github.com/zbm-dev/zfsbootmenu/discussions"
	VERSION="${version}"
	EOF
  fi

  # Update generate-zbm
  if [ -w bin/generate-zbm ]; then
    echo "Updating bin/generate-zbm"
    sed -e "s/our \$VERSION.*/our \$VERSION = '${version}';/" -i bin/generate-zbm
  fi
}

version=
update=
while getopts "huv:" opt; do
  case "${opt}" in
    u)
      update="yes"
      ;;
    v)
      version="${OPTARG}"
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

[ -n "${version}" ] || version="$(detect_version)"

if [ "${update}" = yes ]; then
  update_version "${version}"
else
  echo "ZFSBootMenu version: ${version}"
fi
