#!/bin/bash
# SAVE AS: install_base.sh

# --- CONFIG ---
# Your rEFInd config location (Standard for archinstall)
REFIND_CONFIG="/boot/refind_linux.conf"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== ARCH LINUX: MINIMAL TO HYPRLAND ===${NC}"
echo -e "${BLUE}Target: RTX 5070 Ti | Pipewire | Gigabyte Z890${NC}"

# 1. IMMEDIATE IPv6 DISABLE (Fixes download speeds)
echo -e "${BLUE}[1/6] Disabling IPv6...${NC}"
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 &> /dev/null
# Make it permanent for the session
echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee /etc/sysctl.d/90-disable-ipv6.conf > /dev/null
echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.d/90-disable-ipv6.conf > /dev/null

# 2. SYSTEM UPDATES & REPOSITORIES
echo -e "${BLUE}[2/6] Enabling Repos & Updating...${NC}"
# Enable Multilib (Required for Steam/NVIDIA 32-bit)
sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sudo pacman -Syu --noconfirm

# 3. INSTALLING CORE DRIVERS & UTILITIES
echo -e "${BLUE}[3/6] Installing Drivers & Audio...${NC}"

# CORE PACKAGES:
# - base-devel/git: For compiling AUR packages
# - linux-zen-headers: CRITICAL for NVIDIA drivers on Zen kernel
# - pipewire stack: Modern audio
# - bluez: Bluetooth
# - networkmanager: WiFi/Ethernet
# - nvidia-dkms: The 5070 Ti Driver
# - sof-firmware: Required for audio on modern Intel Motherboards (Z890)
sudo pacman -S --needed --noconfirm \
    base-devel git linux-zen-headers \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
    bluez bluez-utils \
    networkmanager \
    nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings \
    lm_sensors \
    sof-firmware alsa-utils \
    hyprland kitty dolphin

# 4. INSTALL YAY (AUR Helper)
if ! command -v yay &> /dev/null; then
    echo -e "${BLUE}[4/6] Installing 'yay'...${NC}"
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd ..
    rm -rf yay-bin
else
    echo -e "${GREEN}'yay' already installed.${NC}"
fi

# 5. INSTALL MOTHERBOARD TOOLS (AUR)
echo -e "${BLUE}[5/6] Installing Gigabyte Tools...${NC}"
# openrgb: Controls your Z890 headers and NZXT RAM
# liquidctl: Controls your AIO pump/fans
yay -S --needed --noconfirm openrgb liquidctl

# 6. PATCH REFIND CONFIG (The Critical Boot Fix)
echo -e "${BLUE}[6/6] Patching rEFInd Kernel Flags...${NC}"

if [[ -f "$REFIND_CONFIG" ]]; then
    sudo cp "$REFIND_CONFIG" "$REFIND_CONFIG.bak"
    
    # This command injects:
    # 1. nvidia_drm.modeset=1 (REQUIRED for Hyprland on NVIDIA)
    # 2. ipv6.disable=1 (For your network issues)
    # into the kernel boot line.
    sudo sed -i 's/\(root=UUID=.*\)"/\1 nvidia_drm.modeset=1 nvidia_drm.fbdev=1 ipv6.disable=1"/' "$REFIND_CONFIG"
    
    echo -e "${GREEN}SUCCESS: Boot flags patched.${NC}"
else
    echo -e "${RED}WARNING: Could not find $REFIND_CONFIG${NC}"
    echo "Please check /boot manually."
fi

# ENABLE SERVICES
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now pipewire

echo -e "${GREEN}=== BASE INSTALL COMPLETE ===${NC}"
echo -e "1. Reboot now ('reboot')."
echo -e "2. Select Linux Zen in rEFInd."
echo -e "3. You will see a raw Hyprland terminal."
echo -e "4. Run Step 2 (The App Installer)."
