#!/bin/sh
# An experimental simple build command.
#

# === Initialize Shell Environment =============================================
set -u
umask 0022
unset IFS
export LC_ALL='C'
SCRIPT_DIR="$(cd $(dirname $0); pwd)"
KRABS_DIR="${SCRIPT_DIR%/*}"
cd $KRABS_DIR

# === Define the functions =====================================================
error_exit() {
    ${2+:} false && echo "${0##*/}: $2" 1>&2
    exit $1
}
print_usage_and_exit() {
cat <<-USAGE 1>&2
Usage   : ${0##*/} [options] path_to_disk_image
Options : -k ELF_file
            Set the 32bit/64bit ELF kernel you want to boot.
          -i initrd_file
            Set initrd.
          -c "command line"
            Set the kernel command line like "root=ram"
USAGE
  exit 1
}

################################################################################
# Parse Arguments
################################################################################
# === Print the usage when "--help" is put =====================================
case "$# ${1:-}" in
    '1 -h'|'1 --help'|'1 --version') print_usage_and_exit;;
esac

# === Setting some parameter  ==================================================
# --- 1. Initialize
STAGE3SIZE=''
BINSTAGE3S=''
BZKERNFILE=''
BZKERNSIZE=''
BINBZKERNS=''
INITRDFILE=''
BININITRDS=''
# --- 2. get opts
while getopts k:i:c: OPT
do
    case $OPT in
        k)  ELF_KERNEL="${OPTARG}"
            bzip2 -zcfk1 "${ELF_KERNEL}" > "${ELF_KERNEL}.bz2"
            BZKERNFILE="${ELF_KERNEL}.bz2"
            BZKERNSIZE="$(cat ${BZKERNFILE} | wc -c | awk '{print $1}' | sed 's:$:/512+1:' | bc)"
            BINBZKERNS="$(printf '\%03o\%03o\n' $((${BZKERNSIZE} & 0xFF)) $(((${BZKERNSIZE} & 0xFF00)>>8)))"
            ;;
        i)  INITRDFILE="${OPTARG}"
            INITRDSIZE="$(cat ${INITRDFILE} | wc -c | awk '{print $1}' | sed 's:$:/512+1:' | bc)"
            BININITRDS="$(printf '\%03o\%03o\n' $((${INITRDSIZE} & 0xFF)) $(((${INITRDSIZE} & 0xFF00)>>8)))"
            ;;
        c)  COMANDLINE="${OPTARG}"
            if [ "${#COMANDLINE}" -gt 120 ]; then
                error_exit 1 'cmdline is too long. it should be under 120 bytes.'
            fi
            ;;
    esac
done
shift $((OPTIND - 1))
# --- 3. set DISKIMAGE & extract boot patition sector
case "$#" in
    0)  print_usage_and_exit
        ;;
    1)  if [   -f "$1"  ] || 
           [   -b "$1"  ] ||
           [   -c "$1"  ] || 
           [   -p "$1"  ]; then
          DISKIMAGE=$1
        fi
        ;;
    *)  print_usage_and_exit
        ;;
esac
BOOTPART="$(od -Ax -tx1 -j0x1bE -N64 -v ${DISKIMAGE} | 
awk '$2~/80/{print $13 $12 $11 $10}'                 | 
tr '[:lower:]' '[:upper:]'                           |
sed 's/.*/obase=10; ibase=16; &/'                    | 
bc                                                  )"
if [ -z "${BOOTPART:-}" ]; then
    error_exit 1 "There is no boot partition in ${DISKIMAGE}"
fi

{
printf "== Writing stage_1st into boot sector. ==\n"
cd ./src/stage_1st
if cargo xbuild --release; then
    cargo objcopy -- -I elf32-i386 -O binary ../../target/i586-stage_1st/release/stage_1st ../../target/i586-stage_1st/release/stage_1st.bin
else
    cd $KRABS_DIR
    error_exit 1 'stage_1st build failed'
fi 2>&1
cd $KRABS_DIR
dd if=target/i586-stage_1st/release/stage_1st.bin of="${DISKIMAGE}" conv=notrunc


printf "\n== Writing stage_2nd into Disk image. ==\n"
cd ./src/stage_2nd
if cargo xbuild --release; then
    cargo objcopy -- -I elf32-i386 -O binary ../../target/i586-stage_2nd/release/stage_2nd ../../target/i586-stage_2nd/release/stage_2nd.bin
else
    cd $KRABS_DIR
    error_exit 1 'stage_2nd build failed'
fi 2>&1
cd $KRABS_DIR
dd if=target/i586-stage_2nd/release/stage_2nd.bin of="${DISKIMAGE}" bs=512 seek=1 conv=notrunc
STAGE2SIZE="$(cat target/i586-stage_2nd/release/stage_2nd.bin | wc -c | awk '{print $1}' | sed 's:$:/512+1:' | bc)"
BINSTAGE2S="$(printf '\%03o\%03o\n' $((${STAGE2SIZE} & 0xFF)) $(((${STAGE2SIZE} & 0xFF00)>>8)))"
printf "${BINSTAGE2S}" | dd of="${DISKIMAGE}" bs=1 seek=$((0x1bc)) count=2 conv=notrunc

printf "\n== Building stage_3. ==\n"
cd ./src/stage_3rd
if cargo xbuild --release; then
    cargo objcopy -- -I elf32-i386 -O binary ../../target/i586-stage_3rd/release/stage_3rd ../../target/i586-stage_3rd/release/stage_3rd.bin
else
    cd $KRABS_DIR
    error_exit 1 'stage_3rd build failed'
fi 2>&1
cd $KRABS_DIR
dd if=target/i586-stage_3rd/release/stage_3rd.bin of="${DISKIMAGE}" bs=512 seek="${BOOTPART}" conv=notrunc 
STAGE3SIZE="$(cat target/i586-stage_3rd/release/stage_3rd.bin | wc -c | awk '{print $1}' | sed 's:$:/512+1:' | bc)"
BINSTAGE3S="$(printf '\%03o\%03o\n' $((${STAGE3SIZE} & 0xFF)) $(((${STAGE3SIZE} & 0xFF00)>>8)))"
printf "${BINSTAGE3S}" | dd of="${DISKIMAGE}" bs=1 seek=$((0x278)) count=2 conv=notrunc


printf "\n== Building stage_4. ==\n"
cd ./src/stage_4th
if cargo xbuild --release; then
    cargo objcopy -- -I elf32-i386 -O binary ../../target/i586-stage_4th/release/stage_4th ../../target/i586-stage_4th/release/stage_4th.bin
else
    cd $KRABS_DIR
    error_exit 1 'stage_4th build failed'
fi 2>&1
cd $KRABS_DIR
dd if=target/i586-stage_4th/release/stage_4th.bin of="${DISKIMAGE}" bs=512 seek="$((${BOOTPART}+${STAGE3SIZE}))" conv=notrunc 
STAGE4SIZE="$(cat target/i586-stage_4th/release/stage_4th.bin | wc -c | awk '{print $1}' | sed 's:$:/512+1:' | bc)"
BINSTAGE4S="$(printf '\%03o\%03o\n' $((${STAGE4SIZE} & 0xFF)) $(((${STAGE4SIZE} & 0xFF00)>>8)))"
printf "${BINSTAGE4S}" | dd of="${DISKIMAGE}" bs=1 seek=$((0x27a)) count=2 conv=notrunc


# Writing kenrel and initrd, if exists.
if [ -n "${BZKERNFILE:-}" ]; then
    printf "\n== Writing kernel into boot partition. ==\n"
    dd if="${BZKERNFILE}" of="${DISKIMAGE}" bs=512 seek="$((${BOOTPART}+${STAGE3SIZE}+${STAGE4SIZE}))" conv=notrunc 
    printf "${BINBZKERNS}" | dd of="${DISKIMAGE}" bs=1 seek=$((0x27c)) count=2 conv=notrunc
    rm "${BZKERNFILE}"
fi

if [ -n "${INITRDFILE:-}" ]; then
    printf "\n== Writing initrd into boot partition. ==\n"
    dd if="${INITRDFILE}" of="${DISKIMAGE}" bs=512 seek="$((${BOOTPART}+${STAGE3SIZE}+${STAGE4SIZE}+${BZKERNSIZE}))" conv=notrunc 
    printf "${BININITRDS}" | dd of="${DISKIMAGE}" bs=1 seek=$((0x27e)) count=2 conv=notrunc  
fi

# Writing command line, if exists.
if [ -n "${COMANDLINE:-}" ]; then
    printf "\n== Writing kernel cmdline into boot param table. ==\n"
    printf "${COMANDLINE}" | cut -c 1-120 | dd of="${DISKIMAGE}" bs=1 seek=$((0x200)) count="${#COMANDLINE}" conv=notrunc 
fi
} | grep -Ev '(the table of contents is empty|is valid for Java but not for C)'

