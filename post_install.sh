#!/usr/bin/env bash

ARCH_GPU_TYPE=0
ARCH_DKMS=0
ARCH_NOUVEAU=0
ARCH_NO_YAY=0
ARCH_MOBILE=0
ARCH_USE_KDE_APPLICATIONS=0
ARCH_SWTPM_FIX=0
ARCH_HELP=0

function exec_pacman() {
  local array_of_packages="${1}"
  sudo pacman -S --noconfirm $(IFS=' ' ; echo "${array_of_packages[*]}")
}

function exec_pacman_list() {
  local array_of_packages="${1}"

  if [[ ! -z "${2}" && "${2}" -eq 1 ]];
  then
    sudo pacman -S $(IFS=' ' ; echo "${array_of_packages[*]}")
  else
    sudo pacman -S --noconfirm $(IFS=' ' ; echo "${array_of_packages[*]}")
  fi
}


declare -a ARCH_BASE_PACKAGES=(
  'xorg-server'
  'xorg-apps'
  'xorg-xinit'
  'xterm xorg-fonts-100dpi'
  'xorg-fonts-75dpi'
  'autorandr'
)

declare -a ARCH_KDE_PACKAGES=(
  'sddm'
  'plasma'
  'plasma-nm'
  'ttf-dejavu'
  'ttf-liberation'
)

declare -a ARCH_XFCE_PACKAGES=(
  'sddm'
  'xfce4'
  'ristretto'
  'xfce4-datetime-plugin'
  'xfce4-mount-plugin'
  'xfce4-netload-plugin'
  'xfce4-notifyd'
  'xfce4-pulseaudio-plugin'
  'xfce4-screensaver'
  'xfce4-taskmanager'
  'xfce4-wavelan-plugin'
  'xfce4-whiskermenu-plugin'
  'thunar-archive-plugin'
  'thunar-media-tags-plugin'
  'xarchiver'
  'networkmanager'
  'pulseaudio'
  'pulseaudio-alsa'
  'pulseaudio-bluetooth'
  'network-manager-applet'
  'paprefs'
  'pavucontrol'
  'galculator'
  'libcanberra'
  'libcanberra-pulse'
)

declare -a ARCH_NVIDIA_PACKAGES=('nvidia-settings')


while [[ $# -gt 0 ]];
do
  i="${1}"

  case "${i}" in
    -h|--help)
      ARCH_HELP=1
      shift;
      ;;
    -d=*|--desktop=*)
      ARCH_DESKTOP="${i#*=}"
      shift;
      ;;
    -d|--desktop)
      ARCH_DESKTOP="${2}"
      shift; shift;
      ;;
    -i|--intel)
      ARCH_GPU_TYPE=1
      shift;
      ;;
    -n|--nvidia)
      ARCH_GPU_TYPE=2
      shift;
      ;;
    -m|--mobile)
      ARCH_BASE_PACKAGES+=('xf86-input-synaptics' 'synaptics')
      ARCH_XFCE_PACKAGES+=(
        'mousepad'
        'parole'
        'xfce4-battery-plugin'
        'xfce4-weather-plugin'
        'xfce4-xkb-plugin'
        'file-roller'
        'leafpad'
        'capitaine-cursors'
        'xdg-user-dirs-gtk'
      )
      ;;
    --dkms)
      ARCH_DKMS=1
      shift;
      ;;
    --use-nouveau)
      ARCH_NOUVEAU=1
      shift;
      ;;
    --no-yay)
      ARCH_NO_YAY=1
      shift;
      ;;
    --xfce-lightdm)
      ARCH_XFCE_PACKAGES[0]='sddm'
      ARCH_XFCE_PACKAGES+=('lightdm-gtk-greeter' 'lightdm-gtk-greeter-settings')
      shift;
      ;;
    --kde-applications)
      ARCH_USE_KDE_APPLICATIONS=1
      shift;
      ;;
    --kde-applications-light)
      ARCH_USE_KDE_APPLICATIONS=2
      shift;
      ;;
    --kvm)
      ARCH_KVM=1
      shift;
      ;;
    --kvm-user=*)
      ARCH_KVM_USER="${i#*=}"
      shift;
      ;;
    --kvm-user)
      ARCH_KVM_USER="${2}"
      shift; shift;
      ;;
    --kvm-group=*)
      ARCH_KVM_GROUP="${i#*=}"
      shift;
      ;;
    --kvm-group)
      ARCH_KVM_GROUP="${2}"
      shift; shift;
      ;;
    --swtpm-fix)
      ARCH_SWTPM_FIX=1
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
    post_install.sh [OPTIONS]

OPTIONS:
    -d, --desktop
            Determines the desktop environment, currently only 'xfce' or 'kde' are supported
    -i, --intel
            Installs the drivers for an Intel graphics card
    -n, --nvidia
            Installs the latest nvidia graphics card driver
    --dkms
            Installs the nvidia driver using dkms and nvidia-dkms
    --use-nouveau
            Does not blacklist the open source nvidia driver
    --no-yay
            Does not install yay
    --xfce-lightdm
            Installs lightdm instead of sddm for xfce4
    --kde-applications
            Installs the whole kde application stack
    --kde-applications-light
            Installs a reduced kde application stack (no games, third party integrations ...)
    --kvm
            Installs qemu and libvirt
    --kvm-user
            Specifies the user under which the libvirt daemon should run
    --kvm-group
            Specifies the group under which the libvirt daemon should run
    --swtpm-fix
            See https://github.com/stefanberger/swtpm/issues/284

EOF
  exit 0
fi

exec_pacman_list "${ARCH_BASE_PACKAGES[*]}"


if [ "${ARCH_GPU_TYPE}" -eq 1 ];
then
  exec_pacman 'xf86-video-intel'
elif [ "${ARCH_GPU_TYPE}" -eq 2 ];
then
  if [ "${ARCH_NOUVEAU}" -eq 0 ];
  then
    echo 'blacklist' | sudo tee -a /etc/modprobe.d/blacklist.conf
  fi

  if [ "${ARCH_DKMS}" -eq 1 ];
  then
    ARCH_NVIDIA_PACKAGES+=('linux-headers' 'dkms' 'nvidia-dkms')
  else
    ARCH_NVIDIA_PACKAGES+=('nvidia' 'nvidia-setting')
  fi

  exec_pacman_list "${ARCH_NVIDIA_PACKAGES[*]}"
fi

case "${ARCH_DESKTOP}" in
  kde|plasma|kde-plasma)
    if [ "${ARCH_USE_KDE_APPLICATIONS}" -eq 1 ];
    then
      ARCH_KDE_PACKAGES+=('kde-applications')
    elif [ "${ARCH_USE_KDE_APPLICATIONS}" -eq 2 ];
    then
      ARCH_KDE_PACKAGES+=('akonadi-calendar-tools' 'akonadi-import-wizard' 'akonadiconsole')
      ARCH_KDE_PACKAGES+=('akregator' 'ark' 'dolphin' 'dolphin-plugins' 'ffmpegthumbs' 'filelight' 'kalarm' 'kcalc')
      ARCH_KDE_PACKAGES+=('kcharselect' 'kcolorchooser' 'kcron' 'kde-dev-utils' 'kdenlive' 'kdepim-addons' 'kdf')
      ARCH_KDE_PACKAGES+=('kdialog' 'kfind' 'kgpg' 'kleopatra' 'kmail' 'kmail-account-wizard' 'kmix' 'kompare' 'konsole')
      ARCH_KDE_PACKAGES+=('kontact' 'konversation' 'kopete' 'korganizer' 'krdc' 'ksystemlog' 'ktouch' 'kwalletmanager')
      ARCH_KDE_PACKAGES+=('kwrite' 'markdownpart' 'partitionmanager' 'svgpart' 'sweeper' 'umbrello')
    else
      ARCH_KDE_PACKAGES+=('ark' 'dolphin' 'konsole' 'yakuake')
    fi


    exec_pacman_list "${ARCH_KDE_PACKAGES[*]}"
    ;;
  xfce|xfce4)
    exec_pacman_list "${ARCH_XFCE_PACKAGES[*]}"
    ;;
  *)
    printf -- "[!] unsupported desktop environment: %s\n" "${ARCH_DESKTOP}"
    exit 1
esac

if [ "${ARCH_NO_YAY}" -eq 0 ];
then
  cd /opt
  sudo git clone https://aur.archlinux.org/yay.git
  sudo chown -Rh $USER:$USER yay/
  cd yay
  makepkg -si
  yay -Yc
  cd "${HOME}"
fi

declare -a ARCH_KVM_PACKAGES=(
  'qemu'
  'libvirt'
  'edk2-ovmf'
  'virt-manager'
  'iptables-nft'
  'dnsmasq'
  'swtpm'
)

if [ "${ARCH_KVM}" -eq 1 ];
then
  exec_pacman_list "${ARCH_KVM_PACKAGES[*]}" 1

  if ! test -z "${ARCH_KVM_USER}";
  then
    sed -i "s/#user = \"root\"/user = \"${ARCH_KVM_USER}\"/g" /etc/libvirt/qemu.conf
  fi

  if ! test -z "${ARCH_KVM_GROUP}";
  then
    if [ "${ARCH_KVM_GROUP}" = "libvirt" ];
    then
      sudo usermod -aG libvirt $USER
    fi

    sed -i "s/#group = \"root\"/group = \"${ARCH_KVM_GROUP}\"/g" /etc/libvirt/qemu.conf
  fi

  if [ "${ARCH_SWTPM_FIX}" -eq 1 ];
  then
    sed -i "s/#swtpm_user/swtpm_user/g" /etc/libvirt/qemu.conf
    sed -i "s/#swtpm_group/swtpm_group/g" /etc/libvirt/qemu.conf
    sudo chown -Rh tss:tss /var/lib/swtpm-localca
  fi

  sudo systemctl enable libvirtd.service
  sudo systemctl start libvirtd.service

  sudo virsh net-autostart default
  sudo virsh net-start default
fi

sudo systemctl enable NetworkManager

if [ "${ARCH_XFCE_PACKAGES[0]}" = "lightdm" ];
then
  sudo systemctl enable lightdm
else
  sudo systemctl enable sddm
fi

sudo reboot
