#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

error() {
  echo "ERROR: $*" >&2
}


usage() {
  cat <<-EOF
	USAGE: $0 [OPTIONS] <distro> <pool> <testdir>
	
	  Set up a distribution on the given ZFS pool, in a qemu VM
	
	OPTIONS
	-h
	   Display this message and exit
	
	-c <compat>
	   Use the specified ZFS compatibility option
	
	-e <keyfile>
	   If the pool is (to be) encrypted, unlock with the given key file
	
	-E <environ>
	   Add a variable to the install environrment
	   (The argument environ should take the form 'KEY=VALUE')
	
	-i <imgfile>
	   Specify the path to the disk image file
	   (Default: \${testdir}/\${pool}-pool.img)
	
	-x
	   Assume the pool already exists
	EOF
}

# Support x86_64 for now
case "$(uname -m)" in
  x86_64)
    QEMU_BIN="qemu-system-x86_64"
    MACHINE="type=q35,accel=kvm"
    SERDEV="ttyS0"
    ;;
  *)
    error "Unknown machine type '$(uname -m)'"
    exit 1
    ;;
esac

encrypt_keyfile=
existing_pool=
zpool_compat=
disk_image=

environs=( )

while getopts "hc:e:E:i:x" opt; do
  case "${opt}" in
    c)
      zpool_compat="${OPTARG}"
      ;;
    e)
      encrypt_keyfile="${OPTARG}"
      ;;
    E)
      environs+=( "${OPTARG}" )
      ;;
    i)
      disk_image="${OPTARG}"
      ;;
    x)
      existing_pool="yes"
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

shift "$((OPTIND - 1))"

distro="${1?a distribution name is required}"
zpool_name="${2?a pool name is required}"

testdir="${3}"
if [ ! -d "${testdir}" ]; then
  error "test directory must be specified and must exist"
  exit 1
fi

[ -n "${disk_image}" ] || disk_image="${testdir}/${zpool_name}-pool.img"

if [ ! -r "${disk_image}" ]; then
  error "disk image does not exist or is not accessible"
  exit 1
fi

if ! FIRMWARE="$(realpath -e stubs/OVMF_CODE.fd 2>/dev/null)"; then
  error "unable to find EFI firmware"
  exit 1
fi

if [ ! -d ./initcpio ]; then
  error "initcpio directory must exist"
  exit 1
fi

if [ ! -f ./initcpio/zbm-test.kernel ] || [ ! -f ./initcpio/zbm-test.img ]; then
  QEMU_SETUP_REBUILD=yes
fi

case "${QEMU_SETUP_REBUILD,,}" in
  yes|y|on|true|1)
    if ! ( cd ./initcpio && ./mkimage.sh ); then
      error "failed to prepare kernel and image for setup"
      exit 1
    fi
    ;;
esac

qemu_args=(
  "-m" "${QEMU_VM_MEMSIZE:-2048M}"
  "-smp" "${QEMU_VM_SMP:-4}"
  "-cpu" "host"
  "-bios" "${FIRMWARE}"
  "-drive" "format=raw,file=${disk_image}"
  "-machine" "${MACHINE}"
  "-object" "rng-random,id=rng0,filename=/dev/urandom"
  "-device" "virtio-rng-pci,rng=rng0"
  "-nographic"
  "-serial" "mon:stdio"
  "-append" "console=tty1 console=${SERDEV},115200n8"
  "-nic" "user,model=virtio-net-pci,ipv6=off,mac=52:54:00:ba:b1:0c"
  "-kernel" "./initcpio/zbm-test.kernel"
  "-initrd" "./initcpio/zbm-test.img"
  "-virtfs" "local,path=./helpers,mount_tag=helpers,security_model=none"
  "-virtfs" "local,path=${testdir},mount_tag=testbed,security_model=none"
)

[ -n "${zpool_compat}" ] && environs+=( "ZPOOL_COMPAT='${zpool_compat}'" )
[ "${existing_pool,,}" = "yes" ] && environs+=( "USE_EXISTING_POOL='yes'" )


if [ -d "./cache" ]; then
  qemu_args+=( "-virtfs" "local,path=./cache,mount_tag=cache,security_model=none" )
  environs+=( "USE_HOST_CACHE='yes'" )
fi

if [ -d "./keys" ]; then
  qemu_args+=( "-virtfs" "local,path=./keys,mount_tag=keys,security_model=none" )
  environs+=( "USE_HOST_KEYS='yes'" )
fi

if [ -n "${encrypt_keyfile}" ]; then
  rtdir="$(realpath -e "${testdir}")"

  encrypt_keyfile="$(realpath "${encrypt_keyfile}")"
  rel_keyfile="${encrypt_keyfile#"${rtdir}"}"

  if [ "${encrypt_keyfile}" = "${rel_keyfile}" ]; then
    error "keyfile must be a child of the test directory"
    exit 1
  fi

  environs+=( "ENCRYPT_KEYFILE='/testbed/${rel_keyfile}'" )
fi

# Build the install environment
install_env="${testdir}/install.env"
if ! true > "${install_env}"; then
  error "cannot write install environment"
  exit 1
fi

environs+=( "DISTRIBUTION='${distro}'" "ZPOOL_NAME='${zpool_name}'" )

for environ in "${environs[@]}"; do
  echo "export ${environ}" >> "${install_env}"
done

exec "${QEMU_BIN}" "${qemu_args[@]}"
