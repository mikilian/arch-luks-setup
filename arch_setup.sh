#!/usr/bin/env bash

ARCH_KEYMAP='us'
ARCH_LANGUAGE='en_US.UTF-8'
ARCH_TIME_ZONE='Europe/Berlin'
ARCH_VFIO=0
ARCH_VFIO_KERNEL_PARAM=''
ARCH_HELP=0

declare -a ARCH_LOCALES=('en_US.UTF-8 UTF-8')

while [[ $# -gt 0 ]];
do
  i="${1}"

  case "${i}" in
    -h|--help)
      ARCH_HELP=1
      shift;
      ;;
    -u=*|--user=*)
      ARCH_USER="${i#*=}"
      shift;
      ;;
    -u|--user)
      ARCH_USER="${2}"
      shift; shift;
      ;;
    -h=*|--host=*|--hostname=*)
      ARCH_HOSTNAME="${i#*=}"
      shift;
      ;;
    -h|--host|--hostname)
      ARCH_HOSTNAME="${2}"
      shift; shift;
      ;;
    --lang=*|--language=*)
      ARCH_LANGUAGE="${i#*=}"
      shift;
      ;;
    --lang|--language)
      ARCH_LANGUAGE="${2}"
      shift; shift;
      ;;
    -l=*|--locale=*)
      ARCH_LOCALES+=("${i#*=}")
      shift;
      ;;
    -l|--locale)
      ARCH_LOCALES+=("${2}")
      shift; shift;
      ;;
    -k=*|--keymap=*)
      ARCH_KEYMAP="${i#*=}"
      shift;
      ;;
    -k|--keymap)
      ARCH_KEYMAP="${2}"
      shift; shift;
      ;;
    -tz=*|--time-zone=*)
      ARCH_TIME_ZONE="${i#*=}"
      shift;
      ;;
    -tz|--time-zone)
      ARCH_TIME_ZONE="${2}"
      shift; shift;
      ;;
    --vfio)
      ARCH_VFIO=1
      shift;
      ;;
    --amd)
      ARCH_VFIO_KERNEL_PARAM='amd_iommu=1'
      shift;
      ;;
    --intel)
      ARCH_VFIO_KERNEL_PARAM='intel_iommu=1'
      shift;
      ;;
    *)
      shift;
      ;;
  esac
done

if [ "${ARCH_HELP}" -eq 1 ];
then
  cat <<EOF
USAGE:
    arch_setup.sh [OPTIONS]

OPTIONS:
    -h, --help
            Prints help information
    -u, --user
            Specifies the name of the user to be created
    -h --host, --hostname
            Determines the host name of the system
    --lang, --language
            Determines the system language, by default 'en_US.UTF-8'
    -l, --locale
            Can be used multiple times, determines in each case a Locale which is
            to be generated. The exact name is necessary!
    -tz, --timezone
            Sets the time zone, by default 'Europe/Berlin'
    -k, --keymap
            Determines the default console layout, by default 'us'
    v, --vfio
            Loads the vfio kernel modules early, required for PCI passthrough
    a, --amd
            Adds amd_iommu=1 to the kernel parameters
    i, --intel
            Adds intel_iommu=1 to the kernel parameters

EOF
  exit 0
fi

if [[ "${ARCH_VFIO}" -eq 1 && -z "${ARCH_VFIO_KERNEL_PARAM}" ]];
then
  printf -- "[!] missing --amd OR --intel flag to setup vfio\n"
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

if test -z "${ARCH_USER}";
then
  printf -- "[!] missing username, please provide --user parameter\n"
  exit 1
fi

if test -z "${ARCH_HOSTNAME}";
then
  printf -- "[!] missing hostname, please provide --host parameter\n"
  exit 1
fi

if ! test -f "/usr/share/zoneinfo/${ARCH_TIME_ZONE}";
then
  printf -- "[!] invalid timezone, could not find %s\n" "${ARCH_TIME_ZONE}"
  exit 1
fi

printf -- "[+] set timezone to %s and synchronizing clock...\n"
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc --utc

printf -- "[+] setting hostname to %s\n" "${ARCH_HOSTNAME}"
echo "${ARCH_HOSTNAME}" > /etc/hostname

printf -- "[+] configuring hosts file...\n"
cat <<EOF > /etc/hosts
# Static table lookup for hostnames.
# See hosts(5) for details.
127.0.0.1     localhost
::1           localhost
127.0.0.1     $ARCH_HOSTNAME        $ARCH_HOSTNAME
EOF

printf -- "[+] configuring locales...\n"

for i in "${ARCH_LOCALES[@]}";
do
  sed -i "/s#${i}/${i}/g" /etc/locale.gen
done
locale-gen

echo "LANGUAGE=${ARCH_LANGUAGE}" >> /etc/locale.conf

printf -- "[+] setting root password...\n"
passwd

printf -- "[+] creating user %s...\n" "${ARCH_USER}"
useradd -m -g users -G wheel -s /bin/zsh "${ARCH_USER}"

passwd "${ARCH_USER}"
groupadd "${ARCH_USER}"
usermod -aG "${ARCH_USER}" "${ARCH_USER}"

printf -- "[+] allow members of group wheel to execute any command\n"
sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" /etc/sudoers

printf -- "[+] configuring mkinitcpio and regenerating initramfs...\n"
if [ "${ARCH_VFIO}" -eq 1 ];
then
  sed -i "s/MODULES=()/MODULES=(ext4 vfio_pci vfio vfio_iommu_type1 vfio_virqfd)/g" /etc/mkinitcpio.conf
else
  sed -i "s/MODULES=()/MODULES=(ext4)/g" /etc/mkinitcpio.conf
fi

sed -i "s/block filesystems/block keymap encrypt lvm2 resume filesystems/g" /etc/mkinitcpio.conf

mkinitcpio -P

printf -- "[+] installing GRUB...\n"
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux --removable --recheck --debug

printf -- "[+] configuring GRUB...\n"
sed -i "s/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/g" /etc/default/grub

ARCH_PARTITION_ROOT="$(df -h | grep /boot/efi | awk '{ print $1 }')"
ARCH_PARTITION_ROOT="${ARCH_PARTITION_ROOT##*/}"
ARCH_PARTITION_ROOT="${ARCH_PARTITION_ROOT::-1}"

sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=\/dev\/${ARCH_PARTITION_ROOT}3:luks root=\/dev\/mapper\/vg0-root resume=\/dev\/mapper\/vg0-swap\"/g" /etc/default/grub

if [ "${ARCH_VFIO}" -eq 1 ];
then
  sed -i "s/loglevel=3 quiet/loglevel=3 quiet ${ARCH_VFIO_KERNEL_PARAM}/g" /etc/default/grub

  declare -a GITHUB_BINARIES=('iommu_groups' 'vfio_check')

  for i in "${GITHUB_BINARIES[@]}";
  do
    curl -o "/usr/local/bin/${i}" "https://raw.githubusercontent.com/mikilian/arch-luks-setup/main/bin/${i}"
    chmod a+x "/usr/local/bin/${i}"
  done
fi

grub-mkconfig -o /boot/grub/grub.cfg

printf -- "[+] allowing parallel downloads for pacman...\n"
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5/g" /etc/pacman.conf

printf -- "[+] enabling DHCP service...\n"
systemctl enable dhcpcd.service

if ! test -z "${ARCH_KEYMAP}";
then
  echo "KEYMAP=${ARCH_KEYMAP}" > /etc/vconsole.conf
fi

while true;
do
  printf -- "[?] Do you want to download the next script (y/n): "

  read input
  case "${input}" in
    y|yes|Y|YES)
      curl -o "/home/${ARCH_USER}/post_install.sh" https://raw.githubusercontent.com/mikilian/arch-luks-setup/main/post_install.sh
      chmod a+x "/home/${ARCH_USER}/post_install.sh"

      printf -- "[+] Saved the post_install.sh script in /home/%s\n" "${ARCH_USER}"
      break;
      ;;
    n|no|N|NO)
      break;
      ;;
    *)
      ;;
  esac
done

printf -- "[+] The installation has been completed successfully.\n"
printf -- "[+] Exit arch-chroot with 'exit' and unmount all partitions using 'umount -R /mnt && swapoff -a\n"
printf -- "[+] Reboot your machine aftewards!\n"
