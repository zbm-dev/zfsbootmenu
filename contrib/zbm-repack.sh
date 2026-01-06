#!/bin/bash
# zbm-repack.sh - Repackage ZFSBootMenu image with SSH keys
#
# This script takes an existing ZFSBootMenu initramfs image and repackages it
# with SSH keys for remote access. Use remote-ssh-build.sh for building new
# images with SSH support - this script is for repacking existing images.
#
# Usage: sudo ./zbm-repack.sh [options]
#
# Options:
#   -i, --input <file>     Input ZFSBootMenu initramfs/EFI (required)
#   -o, --output <file>    Output file (default: input with .repack suffix)
#   -k, --ssh-key <file>   SSH authorized_keys file (default: auto-detect)
#   -H, --host-keys <dir>  Directory with SSH host keys (default: /etc/ssh or /etc/dropbear)
#   -h, --help             Show this help message
#
# The script will:
# 1. Extract the initramfs from the image
# 2. Copy/convert SSH host keys for dropbear
# 3. Add user's SSH public key for authentication
# 4. Repack the image
#
# Requirements:
#   - cpio (for initramfs extraction/repacking)
#   - zstd or gzip (depending on initramfs compression)
#   - objcopy (for EFI bundle manipulation, usually in binutils)
#
# For SSH host key conversion (at least one of):
#   - openssl + xxd (embedded converter - usually pre-installed)
#   - Pre-generated dropbear keys (use -H /path/to/dropbear-keys)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ===== Embedded SSH to Dropbear Key Converter =====
# Converts OpenSSH private keys to dropbear format using OpenSSL and bash
# Supports: RSA, ECDSA (nistp256/384/521), Ed25519

# Write a length-prefixed string in dropbear format (big-endian length + data)
_dropbear_write_string() {
    local data="$1"
    local len=${#data}
    printf "\\x$(printf '%02x' $((len >> 24 & 0xff)))"
    printf "\\x$(printf '%02x' $((len >> 16 & 0xff)))"
    printf "\\x$(printf '%02x' $((len >> 8 & 0xff)))"
    printf "\\x$(printf '%02x' $((len & 0xff)))"
    printf '%s' "$data"
}

# Write a length-prefixed binary blob from hex
_dropbear_write_binary() {
    local hex="$1"
    hex=$(echo "$hex" | tr -d ' :\n')
    local len=$((${#hex} / 2))
    printf "\\x$(printf '%02x' $((len >> 24 & 0xff)))"
    printf "\\x$(printf '%02x' $((len >> 16 & 0xff)))"
    printf "\\x$(printf '%02x' $((len >> 8 & 0xff)))"
    printf "\\x$(printf '%02x' $((len & 0xff)))"
    echo -n "$hex" | xxd -r -p
}

# Write a multi-precision integer (with leading zero if high bit set)
_dropbear_write_mpint() {
    local hex="$1"
    hex=$(echo "$hex" | tr -d ' :\n' | tr 'A-F' 'a-f')
    # Pad to even length
    if [[ $((${#hex} % 2)) -eq 1 ]]; then
        hex="0$hex"
    fi
    # Remove leading zero bytes but keep at least one byte
    while [[ ${#hex} -gt 2 && "${hex:0:2}" == "00" ]]; do
        hex="${hex:2}"
    done
    # Add leading zero if high bit is set (to indicate positive number)
    local first_byte=$((16#${hex:0:2}))
    if [[ $((first_byte & 0x80)) -ne 0 ]]; then
        hex="00$hex"
    fi
    _dropbear_write_binary "$hex"
}

# Convert RSA key to dropbear format
_convert_rsa_to_dropbear() {
    local input="$1"
    local output="$2"
    local tempdir=$(mktemp -d)
    trap "rm -rf $tempdir" RETURN
    
    if grep -q "OPENSSH PRIVATE KEY" "$input"; then
        cp "$input" "$tempdir/key"
        chmod 600 "$tempdir/key"
        ssh-keygen -p -m PEM -N "" -f "$tempdir/key" >/dev/null 2>&1
        input="$tempdir/key"
    fi
    
    local text=$(openssl rsa -in "$input" -text -noout 2>/dev/null)
    [[ -z "$text" ]] && return 1
    
    local n=$(echo "$text" | awk '/^modulus:$/,/^publicExponent:/' | grep -v '^modulus:' | grep -v '^publicExponent:' | tr -d ' \n:')
    local e=$(echo "$text" | grep "^publicExponent:" | sed 's/.*0x\([0-9a-fA-F]*\).*/\1/')
    local d=$(echo "$text" | awk '/^privateExponent:$/,/^prime1:/' | grep -v '^privateExponent:' | grep -v '^prime1:' | tr -d ' \n:')
    local p=$(echo "$text" | awk '/^prime1:$/,/^prime2:/' | grep -v '^prime1:' | grep -v '^prime2:' | tr -d ' \n:')
    local q=$(echo "$text" | awk '/^prime2:$/,/^exponent1:/' | grep -v '^prime2:' | grep -v '^exponent1:' | tr -d ' \n:')
    
    [[ -z "$n" || -z "$e" || -z "$d" || -z "$p" || -z "$q" ]] && return 1
    
    { _dropbear_write_string "ssh-rsa"; _dropbear_write_mpint "$e"; _dropbear_write_mpint "$n"; _dropbear_write_mpint "$d"; _dropbear_write_mpint "$p"; _dropbear_write_mpint "$q"; } > "$output"
}

# Convert ECDSA key to dropbear format
_convert_ecdsa_to_dropbear() {
    local input="$1"
    local output="$2"
    local tempdir=$(mktemp -d)
    trap "rm -rf $tempdir" RETURN
    
    if grep -q "OPENSSH PRIVATE KEY" "$input"; then
        cp "$input" "$tempdir/key"
        chmod 600 "$tempdir/key"
        ssh-keygen -p -m PEM -N "" -f "$tempdir/key" >/dev/null 2>&1
        input="$tempdir/key"
    fi
    
    local text=$(openssl ec -in "$input" -text -noout 2>/dev/null)
    local curve_oid=$(echo "$text" | grep "ASN1 OID:" | awk '{print $3}')
    
    local curve_name curve_size
    case "$curve_oid" in
        prime256v1|secp256r1) curve_name="nistp256"; curve_size=32 ;;
        secp384r1) curve_name="nistp384"; curve_size=48 ;;
        secp521r1) curve_name="nistp521"; curve_size=66 ;;
        *) return 1 ;;
    esac
    
    local key_type="ecdsa-sha2-$curve_name"
    local pub=$(echo "$text" | sed -n '/^pub:$/,/^ASN1/p' | grep -v '^pub:' | grep -v '^ASN1' | tr -d ' \n:')
    local priv=$(echo "$text" | sed -n '/^priv:$/,/^pub:/p' | grep -v '^priv:' | grep -v '^pub:' | tr -d ' \n:')
    
    while [[ ${#priv} -lt $((curve_size * 2)) ]]; do
        priv="00$priv"
    done
    
    { _dropbear_write_string "$key_type"; _dropbear_write_string "$curve_name"; _dropbear_write_binary "$pub"; _dropbear_write_binary "$priv"; } > "$output"
}

# Convert Ed25519 key to dropbear format
_convert_ed25519_to_dropbear() {
    local input="$1"
    local output="$2"
    
    grep -q "OPENSSH PRIVATE KEY" "$input" 2>/dev/null || return 1
    
    local b64=$(grep -v '^-' "$input" | tr -d '\n')
    local raw_hex=$(echo "$b64" | base64 -d | xxd -p | tr -d '\n')
    local magic="6f70656e7373682d6b65792d763100"
    
    [[ "${raw_hex:0:${#magic}}" != "$magic" ]] && return 1
    
    local pos=${#magic}
    _read_len() { printf '%d' "0x${raw_hex:$1:8}"; }
    
    # Skip ciphername, kdfname, kdfoptions
    local len=$(_read_len $pos); pos=$((pos + 8 + len * 2))
    len=$(_read_len $pos); pos=$((pos + 8 + len * 2))
    len=$(_read_len $pos); pos=$((pos + 8 + len * 2))
    pos=$((pos + 8))  # Skip number of keys
    len=$(_read_len $pos); pos=$((pos + 8 + len * 2))  # Skip public key blob
    len=$(_read_len $pos); pos=$((pos + 8))  # Private section
    pos=$((pos + 16))  # Skip checkints
    
    len=$(_read_len $pos); pos=$((pos + 8 + len * 2))  # Skip keytype
    len=$(_read_len $pos); pos=$((pos + 8))
    local pubkey_hex="${raw_hex:$pos:$((len * 2))}"; pos=$((pos + len * 2))
    len=$(_read_len $pos); pos=$((pos + 8))
    local seed_hex="${raw_hex:$pos:64}"
    
    { _dropbear_write_string "ssh-ed25519"; _dropbear_write_binary "$pubkey_hex"; _dropbear_write_binary "$seed_hex"; } > "$output"
}

# Detect SSH key type
_detect_ssh_key_type() {
    local input="$1"
    if grep -q "RSA PRIVATE KEY" "$input" 2>/dev/null; then
        echo "rsa"
    elif grep -q "EC PRIVATE KEY" "$input" 2>/dev/null; then
        echo "ecdsa"
    elif grep -q "OPENSSH PRIVATE KEY" "$input" 2>/dev/null; then
        local content=$(cat "$input")
        if echo "$content" | base64 -d 2>/dev/null | grep -q "ssh-ed25519"; then
            echo "ed25519"
        elif echo "$content" | base64 -d 2>/dev/null | grep -q "ssh-rsa"; then
            echo "rsa"
        elif echo "$content" | base64 -d 2>/dev/null | grep -q "ecdsa-sha2"; then
            echo "ecdsa"
        else
            local keytype=$(ssh-keygen -l -f "$input" 2>/dev/null | awk '{print $NF}' | tr -d '()')
            case "$keytype" in
                RSA) echo "rsa" ;; ECDSA) echo "ecdsa" ;; ED25519) echo "ed25519" ;; *) echo "unknown" ;;
            esac
        fi
    else
        echo "unknown"
    fi
}

# Convert OpenSSH key to dropbear format (main entry point)
convert_ssh_to_dropbear() {
    local input="$1"
    local output="$2"
    
    [[ ! -f "$input" ]] && return 1
    command -v openssl >/dev/null 2>&1 || return 1
    command -v xxd >/dev/null 2>&1 || return 1
    
    local keytype=$(_detect_ssh_key_type "$input")
    case "$keytype" in
        rsa) _convert_rsa_to_dropbear "$input" "$output" ;;
        ecdsa) _convert_ecdsa_to_dropbear "$input" "$output" ;;
        ed25519) _convert_ed25519_to_dropbear "$input" "$output" ;;
        *) return 1 ;;
    esac
}
# ===== End Embedded SSH to Dropbear Key Converter =====

usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Repackage ZFSBootMenu image with SSH keys for remote access.

Options:
  -i, --input <file>     Input ZFSBootMenu initramfs or EFI bundle (required)
  -o, --output <file>    Output file (default: input with .repack suffix)
  -k, --ssh-key <file>   SSH authorized_keys file (default: auto-detect from ~/.ssh/)
  -H, --host-keys <dir>  Directory with SSH host keys (default: /etc/ssh or /etc/dropbear)
  -h, --help             Show this help message

Examples:
  # Repack with auto-detected SSH keys
  sudo ./zbm-repack.sh -i /boot/efi/EFI/zbm/vmlinuz.EFI

  # Repack with specific SSH key
  sudo ./zbm-repack.sh -i vmlinuz.EFI -k ~/.ssh/authorized_keys

  # Use pre-generated dropbear keys (no conversion needed)
  sudo ./zbm-repack.sh -i vmlinuz.EFI -H /path/to/dropbear-keys

SSH Host Keys:
  The script converts OpenSSH keys to dropbear format using the embedded
  converter (requires openssl + xxd, usually pre-installed).

  Alternatively, pre-generate dropbear keys directly (no conversion needed):
       mkdir -p /etc/dropbear-zbm
       dropbearkey -t ed25519 -f /etc/dropbear-zbm/dropbear_ed25519_host_key
       dropbearkey -t ecdsa -f /etc/dropbear-zbm/dropbear_ecdsa_host_key
       dropbearkey -t rsa -s 4096 -f /etc/dropbear-zbm/dropbear_rsa_host_key
       sudo ./zbm-repack.sh -i vmlinuz.EFI -H /etc/dropbear-zbm
EOF
    exit 0
}

# Parse arguments
INPUT_FILE=""
OUTPUT_FILE=""
SSH_KEY_FILE=""
HOST_KEYS_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUT_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -k|--ssh-key)
            SSH_KEY_FILE="$2"
            shift 2
            ;;
        -H|--host-keys)
            HOST_KEYS_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

# Validate input
if [ -z "$INPUT_FILE" ]; then
    print_error "Input file is required. Use -i <file>"
    usage
fi

if [ ! -f "$INPUT_FILE" ]; then
    print_error "Input file not found: $INPUT_FILE"
    exit 1
fi

# Set output file
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="${INPUT_FILE%.EFI}.repack.EFI"
    OUTPUT_FILE="${OUTPUT_FILE%.img}.repack.img"
    if [ "$OUTPUT_FILE" = "$INPUT_FILE" ]; then
        OUTPUT_FILE="${INPUT_FILE}.repack"
    fi
fi

print_info "ZFSBootMenu SSH Repack Tool"
print_info "==========================="
print_info "Input:  $INPUT_FILE"
print_info "Output: $OUTPUT_FILE"

# Create temp directory
TEMP_DIR=$(mktemp -d)
INITRAMFS_DIR="$TEMP_DIR/initramfs"
mkdir -p "$INITRAMFS_DIR"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Detect image type and extract
print_info "Detecting image type..."

IS_EFI=false
IS_BZIMAGE=false
KERNEL_FILE=""

# Check if it's an EFI bundle (has PE header or specific signature)
if file "$INPUT_FILE" | grep -qE "PE32\+|EFI"; then
    IS_EFI=true
    print_info "Detected EFI bundle"
    
    # Extract initramfs from EFI bundle using objcopy
    if ! command -v objcopy >/dev/null 2>&1; then
        print_error "objcopy not found. Install binutils package."
        exit 1
    fi
    
    # EFI bundles have the initramfs in .initrd section
    objcopy -O binary -j .initrd "$INPUT_FILE" "$TEMP_DIR/initramfs.img" 2>/dev/null || {
        print_error "Failed to extract initramfs from EFI bundle"
        exit 1
    }
    
    # Also extract kernel for later repacking
    objcopy -O binary -j .linux "$INPUT_FILE" "$TEMP_DIR/vmlinuz" 2>/dev/null || {
        print_error "Failed to extract kernel from EFI bundle"
        exit 1
    }
    
    # Extract cmdline if present
    objcopy -O binary -j .cmdline "$INPUT_FILE" "$TEMP_DIR/cmdline.txt" 2>/dev/null || true
    
    KERNEL_FILE="$TEMP_DIR/vmlinuz"
    INITRAMFS_FILE="$TEMP_DIR/initramfs.img"
elif file "$INPUT_FILE" | grep -q "Linux kernel.*bzImage"; then
    IS_BZIMAGE=true
    print_info "Detected bzImage with embedded initramfs"
    print_warn "bzImage repacking is experimental"
    
    # Extract embedded initramfs from bzImage
    if command -v binwalk >/dev/null 2>&1; then
        print_info "Using binwalk to extract initramfs..."
        binwalk -e -C "$TEMP_DIR" "$INPUT_FILE" 2>/dev/null || true
        
        # Find the extracted cpio/initramfs
        EXTRACTED_INITRAMFS=$(find "$TEMP_DIR" -name "*.cpio*" -o -name "initramfs*" 2>/dev/null | head -1)
        if [ -z "$EXTRACTED_INITRAMFS" ]; then
            EXTRACTED_INITRAMFS=$(find "$TEMP_DIR" -type f -size +1M 2>/dev/null | head -1)
        fi
        
        if [ -n "$EXTRACTED_INITRAMFS" ] && [ -f "$EXTRACTED_INITRAMFS" ]; then
            cp "$EXTRACTED_INITRAMFS" "$TEMP_DIR/initramfs.img"
            INITRAMFS_FILE="$TEMP_DIR/initramfs.img"
        else
            print_error "Could not find initramfs in binwalk extraction"
            exit 1
        fi
    else
        # Manual extraction: search for compressed cpio signatures
        print_info "Searching for embedded initramfs..."
        
        OFFSET=$(grep -abo $'\x28\xB5\x2F\xFD' "$INPUT_FILE" 2>/dev/null | head -1 | cut -d: -f1)
        if [ -n "$OFFSET" ]; then
            print_info "Found zstd-compressed initramfs at offset $OFFSET"
            dd if="$INPUT_FILE" bs=1 skip="$OFFSET" of="$TEMP_DIR/initramfs.img" 2>/dev/null
        else
            OFFSET=$(grep -abo $'\x1F\x8B' "$INPUT_FILE" 2>/dev/null | tail -1 | cut -d: -f1)
            if [ -n "$OFFSET" ]; then
                print_info "Found gzip-compressed initramfs at offset $OFFSET"
                dd if="$INPUT_FILE" bs=1 skip="$OFFSET" of="$TEMP_DIR/initramfs.img" 2>/dev/null
            else
                print_error "Could not locate embedded initramfs"
                print_error "Install 'binwalk' for better extraction support: apt install binwalk"
                exit 1
            fi
        fi
        INITRAMFS_FILE="$TEMP_DIR/initramfs.img"
    fi
    
    # Save original for kernel data
    cp "$INPUT_FILE" "$TEMP_DIR/original.bzImage"
    KERNEL_FILE="$TEMP_DIR/original.bzImage"
else
    # Assume it's a plain initramfs
    print_info "Detected plain initramfs"
    INITRAMFS_FILE="$INPUT_FILE"
fi

# Detect compression and extract
print_info "Extracting initramfs..."

cd "$INITRAMFS_DIR"

# Try different decompression methods
if zstdcat "$INITRAMFS_FILE" 2>/dev/null | cpio -idm 2>/dev/null; then
    COMPRESS_CMD="zstd -19"
    print_info "Detected zstd compression"
elif gzip -dc "$INITRAMFS_FILE" 2>/dev/null | cpio -idm 2>/dev/null; then
    COMPRESS_CMD="gzip -9"
    print_info "Detected gzip compression"
elif xz -dc "$INITRAMFS_FILE" 2>/dev/null | cpio -idm 2>/dev/null; then
    COMPRESS_CMD="xz -9"
    print_info "Detected xz compression"
elif lz4 -dc "$INITRAMFS_FILE" 2>/dev/null | cpio -idm 2>/dev/null; then
    COMPRESS_CMD="lz4 -9"
    print_info "Detected lz4 compression"
elif cpio -idm < "$INITRAMFS_FILE" 2>/dev/null; then
    COMPRESS_CMD="cat"
    print_info "Detected uncompressed cpio"
else
    print_error "Failed to extract initramfs. Unknown format."
    exit 1
fi

cd - >/dev/null

# Verify extraction
if [ ! -d "$INITRAMFS_DIR/usr" ] && [ ! -d "$INITRAMFS_DIR/bin" ]; then
    print_error "Extraction seems to have failed - no standard directories found"
    exit 1
fi

print_info "Initramfs extracted successfully"

# ===== SSH Host Keys =====
print_info "Configuring SSH host keys..."

# The dropbear directory in initramfs where keys should go
DROPBEAR_DIR="$INITRAMFS_DIR/etc/dropbear"
mkdir -p "$DROPBEAR_DIR"

# Find host keys directory on the running system
if [ -z "$HOST_KEYS_DIR" ]; then
    for dir in /etc/dropbear /etc/ssh; do
        if [ -d "$dir" ] && ls "$dir"/*key* >/dev/null 2>&1; then
            HOST_KEYS_DIR="$dir"
            break
        fi
    done
fi

if [ -z "$HOST_KEYS_DIR" ]; then
    print_warn "No SSH host keys directory found on host"
    print_warn "Keeping original keys from the image"
else
    print_info "Using host keys from: $HOST_KEYS_DIR"
    
    # Check if host has dropbear keys (already in correct format)
    if [ -f "$HOST_KEYS_DIR/dropbear_ed25519_host_key" ] || \
       [ -f "$HOST_KEYS_DIR/dropbear_ecdsa_host_key" ] || \
       [ -f "$HOST_KEYS_DIR/dropbear_rsa_host_key" ]; then
        print_info "Found dropbear-format host keys, copying directly..."
        for keytype in ed25519 ecdsa rsa; do
            src_key="$HOST_KEYS_DIR/dropbear_${keytype}_host_key"
            dst_key="$DROPBEAR_DIR/dropbear_${keytype}_host_key"
            if [ -f "$src_key" ]; then
                cp "$src_key" "$dst_key"
                chmod 600 "$dst_key"
                print_info "Copied $keytype host key"
            fi
        done
    else
        # Convert OpenSSH keys to dropbear format using embedded converter
        if command -v openssl >/dev/null 2>&1 && command -v xxd >/dev/null 2>&1; then
            print_info "Converting OpenSSH keys to dropbear format..."
            converted=0
            for keytype in ed25519 ecdsa rsa; do
                openssh_key="$HOST_KEYS_DIR/ssh_host_${keytype}_key"
                dropbear_key="$DROPBEAR_DIR/dropbear_${keytype}_host_key"
                
                if [ -f "$openssh_key" ]; then
                    if convert_ssh_to_dropbear "$openssh_key" "$dropbear_key" 2>/dev/null; then
                        chmod 600 "$dropbear_key"
                        print_info "Converted $keytype host key"
                        converted=$((converted + 1))
                    else
                        print_warn "Failed to convert $keytype host key"
                    fi
                fi
            done
            if [ $converted -eq 0 ]; then
                print_warn "No keys were converted, keeping original keys"
            fi
        else
            print_warn "No key conversion method available"
            print_warn "Required: openssl and xxd (usually pre-installed)"
            print_warn "Keeping original keys from the image"
        fi
    fi
fi

# ===== SSH Authorized Keys =====
print_info "Configuring SSH authorized keys..."

# Auto-detect SSH key file
if [ -z "$SSH_KEY_FILE" ]; then
    for keyfile in /root/.ssh/authorized_keys ~/.ssh/authorized_keys; do
        if [ -f "$keyfile" ]; then
            SSH_KEY_FILE="$keyfile"
            break
        fi
    done
fi

# Create authorized_keys in initramfs
AUTH_KEYS_DIR="$INITRAMFS_DIR/root/.ssh"
mkdir -p "$AUTH_KEYS_DIR"
chmod 700 "$AUTH_KEYS_DIR"

if [ -n "$SSH_KEY_FILE" ] && [ -f "$SSH_KEY_FILE" ]; then
    # Prepend command="/bin/zfsbootmenu" to each key so ZBM auto-launches on SSH login
    key_count=0
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        if [ -z "$line" ] || [[ "$line" == \#* ]]; then
            echo "$line" >> "$AUTH_KEYS_DIR/authorized_keys"
        # Skip lines that already have command= prefix
        elif [[ "$line" == command=* ]]; then
            echo "$line" >> "$AUTH_KEYS_DIR/authorized_keys"
            key_count=$((key_count + 1))
        else
            echo "command=\"/bin/zfsbootmenu\" $line" >> "$AUTH_KEYS_DIR/authorized_keys"
            key_count=$((key_count + 1))
        fi
    done < "$SSH_KEY_FILE"
    chmod 600 "$AUTH_KEYS_DIR/authorized_keys"
    print_info "Copied $key_count SSH public key(s) from $SSH_KEY_FILE"
    print_info "Keys configured to auto-launch ZFSBootMenu on SSH login"
else
    print_warn "No SSH authorized_keys file found!"
    print_warn "You may not be able to SSH into ZFSBootMenu"
fi

# ===== Repack initramfs =====
print_info "Repacking initramfs..."

cd "$INITRAMFS_DIR"

# Create cpio archive and compress
find . | cpio -H newc -o 2>/dev/null > "$TEMP_DIR/initramfs.cpio"

case "$COMPRESS_CMD" in
    "zstd -19")
        zstd -19 -f -q "$TEMP_DIR/initramfs.cpio" -o "$TEMP_DIR/initramfs.new"
        ;;
    "gzip -9")
        gzip -9 -c "$TEMP_DIR/initramfs.cpio" > "$TEMP_DIR/initramfs.new"
        ;;
    "xz -9")
        xz -9 -c "$TEMP_DIR/initramfs.cpio" > "$TEMP_DIR/initramfs.new"
        ;;
    "lz4 -9")
        lz4 -9 -c "$TEMP_DIR/initramfs.cpio" > "$TEMP_DIR/initramfs.new"
        ;;
    *)
        cp "$TEMP_DIR/initramfs.cpio" "$TEMP_DIR/initramfs.new"
        ;;
esac
rm -f "$TEMP_DIR/initramfs.cpio"
cd - >/dev/null

INITRAMFS_NEW="$TEMP_DIR/initramfs.new"

# ===== Create output =====
if [ "$IS_EFI" = true ]; then
    print_info "Creating EFI bundle..."
    
    # Get the EFI stub
    EFI_STUB=""
    for stub in /usr/lib/systemd/boot/efi/linuxx64.efi.stub \
                /usr/lib/gummiboot/linuxx64.efi.stub \
                /usr/share/systemd/bootctl/linuxx64.efi.stub; do
        if [ -f "$stub" ]; then
            EFI_STUB="$stub"
            break
        fi
    done
    
    if [ -z "$EFI_STUB" ]; then
        print_error "EFI stub not found. Install systemd-boot or equivalent."
        print_info "Saving as plain initramfs instead..."
        cp "$INITRAMFS_NEW" "$OUTPUT_FILE"
    else
        # Read cmdline
        CMDLINE=""
        if [ -f "$TEMP_DIR/cmdline.txt" ]; then
            CMDLINE=$(cat "$TEMP_DIR/cmdline.txt" | tr -d '\0')
        fi
        
        # Create EFI bundle
        objcopy \
            --add-section .osrel=/etc/os-release --change-section-vma .osrel=0x20000 \
            --add-section .cmdline=<(echo -n "$CMDLINE") --change-section-vma .cmdline=0x30000 \
            --add-section .linux="$KERNEL_FILE" --change-section-vma .linux=0x2000000 \
            --add-section .initrd="$INITRAMFS_NEW" --change-section-vma .initrd=0x3000000 \
            "$EFI_STUB" "$OUTPUT_FILE" 2>/dev/null || {
                print_warn "Failed to create EFI bundle, saving as plain initramfs"
                cp "$INITRAMFS_NEW" "${OUTPUT_FILE%.EFI}.img"
                OUTPUT_FILE="${OUTPUT_FILE%.EFI}.img"
            }
    fi
elif [ "$IS_BZIMAGE" = true ]; then
    print_warn "bzImage repacking is not fully supported"
    print_info "Saving modified initramfs separately..."
    
    INITRAMFS_OUTPUT="${OUTPUT_FILE%.cpio}.initramfs"
    cp "$INITRAMFS_NEW" "$INITRAMFS_OUTPUT"
    
    print_info "Modified initramfs saved to: $INITRAMFS_OUTPUT"
    print_info ""
    print_warn "To use with bzImage, you have two options:"
    print_info "  1. Load as separate initrd in your bootloader:"
    print_info "     kernel /vmlinuz-bootmenu"
    print_info "     initrd $INITRAMFS_OUTPUT"
    print_info ""
    print_info "  2. Rebuild ZBM with the new config and use the EFI bundle"
    
    OUTPUT_FILE="$INITRAMFS_OUTPUT"
else
    cp "$INITRAMFS_NEW" "$OUTPUT_FILE"
fi

# Set permissions
chmod 644 "$OUTPUT_FILE"

# Summary
echo ""
print_info "=== Repack Complete ==="
print_info "Output: $OUTPUT_FILE"
print_info "Size: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"
echo ""

if [ -f "$AUTH_KEYS_DIR/authorized_keys" ]; then
    print_info "SSH keys installed: $(wc -l < "$AUTH_KEYS_DIR/authorized_keys") key(s)"
fi

echo ""
print_info "To use this image:"
if [ "$IS_EFI" = true ]; then
    echo "  1. Copy to your ESP: cp $OUTPUT_FILE /boot/efi/EFI/zbm/"
    echo "  2. Update your boot configuration if needed"
elif [ "$IS_BZIMAGE" = true ]; then
    echo "  1. Keep the original bzImage kernel"
    echo "  2. Add the modified initramfs as a separate initrd"
    echo "  3. Configure bootloader to load both"
else
    echo "  1. Copy to /boot or your boot location"
    echo "  2. Update your bootloader configuration"
fi
