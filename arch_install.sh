#!/usr/bin/env bash

ARCH_HELP=0
ARCH_KNOWN_ARCHITECTURE=0
ARCH_SWAP_SIZE='8G'
ARCH_PARTITION_EFI=''
ARCH_PARTITION_BOOT=''
ARCH_PARTITION_ROOT=''

function exec_pacstrap() {
  local array_of_packages="${1}"
  pacstrap /mnt $(IFS=' ' ; echo "${array_of_packages[*]}")
}

declare -a ARCH_PACSTRAP_PACKAGES=(
  'base'
  'base-devel'
  'dhcpcd'
  'efibootmgr'
  'git'
  'gptfdisk'
  'grub-efi-x86_64'
  'lvm2'
  'linux'
  'linux-firmware'
  'openssh'
  'vim'
  'wget'
  'zsh'
)

while [[ $# -gt 0 ]];
do
  i="${1}"

  case "${i}" in
    -h|--help)
      ARCH_HELP=1
      shift;
      ;;
    -a|--amd)
      ARCH_PACSTRAP_PACKAGES+=('amd-ucode')
      ARCH_KNOWN_ARCHITECTURE=1
      shift;
      ;;
    -i|--intel)
      ARCH_PACSTRAP_PACKAGES+=('intel-ucode')
      ARCH_KNOWN_ARCHITECTURE=1
      shift;
      ;;
    -m|--mobile)
      ARCH_PACSTRAP_PACKAGES+=('dialog' 'wireless_tools' 'ow' 'crda' 'wpa_supplicant')
      shift;
      ;;
    -t=*|--target=*)
      ARCH_PARTITION_DEVICE="${i#*=}"
      shift;
      ;;
    -t|--target)
      ARCH_PARTITION_DEVICE="${2}"
      shift; shift;
      ;;
    -s=*|--swap-size=*)
      ARCH_SWAP_SIZE="${i#*=}"
      shift;
      ;;
    -s|--swap-size)
      ARCH_SWAP_SIZE="${2}"
      shift; shift;
      ;;
    -z|--zen)
      ARCH_PACSTRAP_PACKAGES+=('linux-zen' 'linux-zen-headers')
      shift;
      ;;
    *)
      shift
      ;;
  esac
done

if [ "${ARCH_HELP}" -eq 1 ];
then
  cat <<EOF
USAGE:
    arch_install.sh [OPTIONS]

OPTIONS:
    -h, --help
            Prints help information
    -a, --amd
            Enable microcode updates for AMD CPU
    -i, --intel
            Enable microcode updates for Intel CPU
    -m, --mobile
            Installs additional packages which are necessary for
            notebooks (e.g. wlan support).
    -t, --target
            Specifies the target device on which to install Arch Linux,
            for example: --target=/dev/sda
    -s, --swap-size
            Determines the size of the swap, by default '8G'
    -r, --root-size
            Determines the size of the root partition, by default '100%FREE'
    -z, --zen
            Installs additional packages to be able to use the Linux Zen kernel

EOF
  exit 0
fi

if [ "${ARCH_KNOWN_ARCHITECTURE}" -eq 0 ];
then
  printf -- "[!] warning, missing --amd or --intel CPU microcode flag\n"
  ARCH_CONTINUE=''

  while true;
  do
    printf -- "[?] continue (y/n): "
    read line;

    case "${line}" in
      y|yes|Y|YES)
        break
        ;;
      n|no|N|NO)
        exit 1
        ;;
      *)
        ;;
    esac
  done
fi

if test -z "${ARCH_PARTITION_DEVICE}";
then
  printf -- "[!] missing --target parameter\n"
  for i in "${COMMON_HDD_DEVICES[@]}";
  do
    if test -b "/dev/${i}";
    then
      printf -- "[+] found possible target device: /dev/%s\n" "${i}"
    fi
  done

  exit 1
fi

if ! test -b "${ARCH_PARTITION_DEVICE}";
then
  printf -- "[!] %s is not a valid block device\n" "${ARCH_PARTITION_DEVICE}"
  exit 1
fi

if [[ "${ARCH_PARTITION_DEVICE}" == *"nvme"* ]];
then
  ARCH_PARTITION_EFI="${ARCH_PARTITION_DEVICE}p1"
  ARCH_PARTITION_BOOT="${ARCH_PARTITION_DEVICE}p2"
  ARCH_PARTITION_ROOT="${ARCH_PARTITION_DEVICE}p3"
else
  ARCH_PARTITION_EFI="${ARCH_PARTITION_DEVICE}1"
  ARCH_PARTITION_BOOT="${ARCH_PARTITION_DEVICE}2"
  ARCH_PARTITION_ROOT="${ARCH_PARTITION_DEVICE}3"
fi

printf -- "[!] cgdisk will start in a few seconds, please create the following layout:\n"
printf -- "      size in sectors: +100MB, hex code: ef00\n"
printf -- "      size in sectors: +250MB, hex code: 8300\n"
printf -- "      size in sectors: +???G (whatever your want), hex code: 8300\n"

sleep 7s
cgdisk "${ARCH_PARTITION_DEVICE}"

printf -- "[+] formatting %s as FAT32...\n" "${ARCH_PARTITION_EFI}"
mkfs.vfat -F32 "${ARCH_PARTITION_EFI}"

printf -- "[+] formatting %s as ext2...\n" "${ARCH_PARTITION_BOOT}"
mkfs.ext2 "${ARCH_PARTITION_BOOT}"


printf -- "[+] setting up luks to encrypt your root partition...\n"
cryptsetup -c aes-xts-plain64 -y --use-random luksFormat "${ARCH_PARTITION_ROOT}"

printf -- "[+] opening your encrypted root partition...\n"
cryptsetup luksOpen "${ARCH_PARTITION_ROOT}" luks

printf -- "[+] creating volume group and layout (swap, root)...\n"
pvcreate /dev/mapper/luks
vgcreate vg0 /dev/mapper/luks
lvcreate --size "${ARCH_SWAP_SIZE}" vg0 --name swap
lvcreate -l +100%FREE vg0 --name root

printf -- "[+] formatting the logical root volume...\n"
mkfs.ext4 /dev/mapper/vg0-root

printf -- "[+] creating swap...\n"
mkswap /dev/mapper/vg0-swap

printf -- "[+] creating and mount filesystem"
mount /dev/mapper/vg0-root /mnt
swapon /dev/mapper/vg0-swap
mkdir /mnt/boot
mount "${ARCH_PARTITION_BOOT}" /mnt/boot
mkdir /mnt/boot/efi
mount "${ARCH_PARTITION_EFI}" /mnt/boot/efi

printf -- "[+] Installing the base system..."
exec_pacstrap "${ARCH_PACSTRAP_PACKAGES[*]}"
genfstab /mnt >> /mnt/etc/fstab

while true;
do
  printf -- "[?] Do you want to download the next script (y/n): "

  read input
  case "${input}" in
    y|yes|Y|YES)
      curl -o /mnt/arch_setup.sh https://raw.githubusercontent.com/mikilian/arch-luks-setup/main/arch_setup.sh
      chmod a+x /mnt/arch_setup.sh

      printf "[+] Calling arch-chroot, please execute ./arch_setup.sh afterwards\n"
      break;
      ;;
    n|no|N|NO)
      printf "[+] Calling arch-chroot, please download the arch_setup.sh script manually\n"
      break;
      ;;
    *)
      ;;
  esac
done

arch-chroot /mnt bash
