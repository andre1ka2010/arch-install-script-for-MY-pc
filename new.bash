#!/bin/bash

echo "Make 2 partitions first >1G with EFI system type"
echo "Second partition is the rest of the remaining space with type Linux root x86-64 "
sleep 10

cfdisk /dev/nvme0n1

mkfs.vfat -F 32 /dev/nvme0n1p1
mkfs.ext4 -F /dev/nvme0n1p2

mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot /mnt/mnt/sdb1
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/sdb1 /mnt/mnt/sdb1

pacstrap /mnt base linux-zen linux-zen-headers linux-firmware amd-ucode base-devel nano git bash-completion reflector

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt <<EOF

ln -sf /usr/share/zoneinfo/Europe/Kyiv /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "uk_UA.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "1285" > /etc/hostname

echo "root:zaza" | chpasswd
useradd -m -G wheel andre1ka
echo "andre1ka:zaza" | chpasswd
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacman -Sy

PKGS=(
    networkmanager irqbalance
    mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
    libva-mesa-driver lib32-libva-mesa-driver
    vulkan-tools radeontop vkd3d lib32-vkd3d

    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
    lib32-pipewire lib32-pipewire-jack qpwgraph

    vlc vlc-plugins-all telegram-desktop firefox
    obs-studio discord gwenview okular
    zip unzip p7zip unrar kitty

    steam prismlauncher gamemode lib32-gamemode
    wine winetricks spotify-player spotify-launcher mangohud lib32-mangohud goverlay

    fastfetch hwinfo inxi htop btop timeshift kio-admin lact bluez bluez-utils dolphin ark kate sddm

    ttf-jetbrains-mono ttf-dejavu ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji
    wqy-zenhei wqy-microhei otf-ipafont ttf-arphic-uming ttf-arphic-ukai
    ttf-baekmuk ttf-cascadia-code
)

pacman -S --noconfirm --needed "\${PKGS[@]}"

pacman -S --noconfirm grub efibootmgr

sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' /etc/default/grub


sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nowatchdog amd_pstate=active amdgpu.ppfeaturemask=0xffffffff"/g' /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable irqbalance
systemctl enable fstrim.timer
systemctl enable pipewire pipewire-pulse wireplumber
systemctl enable bluetooth.service
systemctl enable lactd

echo "RADV_PERFTEST=aco" >> /etc/environment
echo "vblank_mode=0" >> /etc/environment
EOF

arch-chroot /mnt /bin/bash -c "su - andre1ka -c '
    cd ~
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
    yay -S --noconfirm --needed spotx protonup-qt
'"

echo "Done! Please umount your drives and reboot."
