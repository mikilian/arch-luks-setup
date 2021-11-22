# arch-luks-setup

Automated minimalistic [Arch Linux](https://archlinux.org/) installation with
an encrypted file system in UEFI mode.

## Installation

> Every script supports the `--help` parameter, use it to get more information.
> Script two and three can be downloaded automatically by the respective parent script.

1. Base installation: `bash -c "$(curl -s https://raw.githubusercontent.com/mikilian/arch-luks-setup/main/arch_install.sh)"`
2. arch-chroot: `bash -c "$(curl -s https://raw.githubusercontent.com/mikilian/arch-luks-setup/main/arch_setup.sh)"`
3. Post installation: `bash -c "$(curl -s https://raw.githubusercontent.com/mikilian/arch-luks-setup/main/arch_install.sh)"`

## Complete example with auto script downloader

```bash
bash -c "$(curl -s https://raw.githubusercontent.com/mikilian/arch-luks-setup/main/arch_install.sh)" -- --intel --target=/dev/sda --swap-size 16
./arch_setup.sh --user foo --host arch-vm --keymap de-latin1 --vfio --intel
exit
mount -R /mnt && swapoff -a
reboot

# login into account foo
./post_install.sh --desktop xfce --nvidia --kvm
```
