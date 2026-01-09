#!/bin/bash
# -------------------------------------------------------------------------
# ARCH LINUX POST-INSTALL (UKI FINAL)
# Target: RTX 5070 Ti | Zen Kernel | UKI Boot | Hyprland (End-4)
# -------------------------------------------------------------------------

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== STARTING UKI POST-INSTALL SETUP ===${NC}"

# 1. Privilege Check
if [ "$EUID" -eq 0 ]; then 
  echo -e "${RED}Please run as your normal user (not root).${NC}"
  echo "The script needs to run 'makepkg' which fails as root."
  exit 1
fi

# 2. Sudo Keep-Alive (Prevents timeout during long installs)
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# -------------------------------------------------------------------------
# STEP 1: DRIVERS & KERNEL (UKI & NVIDIA)
# -------------------------------------------------------------------------
echo -e "${BLUE}[1/7] Configuring NVIDIA & UKI...${NC}"

# Enable Multilib
sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

# Install Headers & Drivers
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel git linux-headers linux-zen-headers
sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils openrgb liquidctl

# Inject NVIDIA Modules for Early Loading (Fixes black screen)
# We safely replace the modules line to ensure NVIDIA loads first
sudo sed -i 's/MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf

# Configure Kernel Command Line for UKI
if [ ! -f /etc/kernel/cmdline ]; then
    echo "root=PARTUUID=$(findmnt / -o PARTUUID -n) rw quiet" | sudo tee /etc/kernel/cmdline
fi

# Add DRM flags for Wayland/Hyprland
if ! grep -q "nvidia_drm.modeset=1" /etc/kernel/cmdline; then
    sudo sed -i 's/$/ nvidia_drm.modeset=1 nvidia_drm.fbdev=1/' /etc/kernel/cmdline
fi

# Regenerate the UKI
echo -e "${BLUE}...Rebuilding Kernel Image (This may take a moment)...${NC}"
sudo mkinitcpio -P

# -------------------------------------------------------------------------
# STEP 2: YAY (AUR Helper)
# -------------------------------------------------------------------------
if ! command -v yay &> /dev/null; then
    echo -e "${BLUE}[2/7] Installing 'yay'...${NC}"
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd ..
    rm -rf yay-bin
fi

# -------------------------------------------------------------------------
# STEP 3: JAPANESE FONTS & INPUT
# -------------------------------------------------------------------------
echo -e "${BLUE}[3/7] Installing Japanese Support...${NC}"

yay -S --needed --noconfirm \
    noto-fonts-cjk noto-fonts-emoji otf-ipafont \
    ttf-hanazono ttf-jetbrains-mono-nerd ttf-material-design-icons \
    fcitx5-im fcitx5-mozc fcitx5-configtool

# Set Environment Variables for Input
sudo sh -c 'echo "GTK_IM_MODULE=fcitx" >> /etc/environment'
sudo sh -c 'echo "QT_IM_MODULE=fcitx" >> /etc/environment'
sudo sh -c 'echo "XMODIFIERS=@im=fcitx" >> /etc/environment'

# -------------------------------------------------------------------------
# STEP 4: APPLICATIONS
# -------------------------------------------------------------------------
echo -e "${BLUE}[4/7] Installing Applications...${NC}"

yay -S --needed --noconfirm \
    discord vlc steam flatpak nwg-displays \
    fish visual-studio-code-bin google-chrome

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# -------------------------------------------------------------------------
# STEP 5: END-4 DOTFILES (The Big Install)
# -------------------------------------------------------------------------
echo -e "${BLUE}[5/7] Launching End-4 Installer...${NC}"
echo -e "${RED}IMPORTANT INSTRUCTIONS:${NC}"
echo -e "1. Say YES to installing packages."
echo -e "2. If it asks to reboot at the end, say ${RED}NO${NC}."
echo -e "   (We still need to apply your monitor fixes!)"
echo ""
read -p "Press Enter to start the installer..."

bash <(curl -s https://ii.clsty.link/get)

# -------------------------------------------------------------------------
# STEP 6: MONITOR & SCALING (Applied AFTER Dotfiles)
# -------------------------------------------------------------------------
echo -e "${BLUE}[6/7] Applying Custom 4K Scaling...${NC}"

# Ensure directory exists (in case installer cleared it)
mkdir -p "$HOME/.config/hypr"
MONITOR_CONFIG="$HOME/.config/hypr/user_monitors.conf"

# Generate the Monitor Config
cat <<EOT > "$MONITOR_CONFIG"
# --- USER CUSTOM MONITORS ---
# Main Monitor (1080p 144Hz)
monitor = DP-1, 1920x1080@144, 0x0, 1

# Secondary Monitor (4K 60Hz -> Scaled 1.5x)
monitor = HDMI-A-1, 3840x2160@60, 1920x0, 1.5

# Fix Blurry XWayland Apps
xwayland {
  force_zero_scaling = true
}

# Environment Variables
env = ELECTRON_OZONE_PLATFORM_HINT,auto
env = GDK_SCALE,2
env = QT_AUTO_SCREEN_SCALE_FACTOR,1
EOT

# Fix Steam Font Size
echo "Xft.dpi: 144" > "$HOME/.Xresources"

# -------------------------------------------------------------------------
# STEP 7: FINAL INJECTION
# -------------------------------------------------------------------------
echo -e "${BLUE}[7/7] Finalizing Configuration...${NC}"

HYPR_MAIN="$HOME/.config/hypr/hyprland.conf"

# Inject our configs into the main Hyprland file
if [ -f "$HYPR_MAIN" ]; then
    # Check if we already injected to avoid duplicates
    if ! grep -q "user_monitors.conf" "$HYPR_MAIN"; then
        echo "" >> "$HYPR_MAIN"
        echo "# --- USER CUSTOM INJECTIONS ---" >> "$HYPR_MAIN"
        echo "source = ~/.config/hypr/user_monitors.conf" >> "$HYPR_MAIN"
        echo "exec-once = xrdb -merge ~/.Xresources" >> "$HYPR_MAIN"
        echo "exec-once = fcitx5 -d" >> "$HYPR_MAIN"
        echo -e "${GREEN}Successfully patched Hyprland config.${NC}"
    else
        echo "Config already patched. Skipping."
    fi
else
    echo -e "${RED}Warning: hyprland.conf not found! Did the installer fail?${NC}"
fi

echo -e "${GREEN}=== SETUP COMPLETE ===${NC}"
echo -e "You can now REBOOT your system."
