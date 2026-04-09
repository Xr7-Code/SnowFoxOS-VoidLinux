#!/bin/bash
# SnowFoxOS v3 Installer
# Basis: Void Linux (glibc/musl) + runit + i3 + X11
# Autor: Alexander Valentin Ludwig (Xr7-Code)

# KEIN set -e — Fehler werden selbst behandelt, kein stilles Abbrechen

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

banner() {
cat << 'EOF'

  ███████╗███╗   ██╗ ██████╗ ██╗    ██╗███████╗ ██████╗ ██╗  ██╗
  ██╔════╝████╗  ██║██╔═══██╗██║    ██║██╔════╝██╔═══██╗╚██╗██╔╝
  ███████╗██╔██╗ ██║██║   ██║██║ █╗ ██║█████╗  ██║   ██║ ╚███╔╝
  ╚════██║██║╚██╗██║██║   ██║██║███╗██║██╔══╝  ██║   ██║ ██╔██╗
  ███████║██║ ╚████║╚██████╔╝╚███╔███╔╝██║     ╚██████╔╝██╔╝ ██╗
  ╚══════╝╚═╝  ╚═══╝ ╚═════╝  ╚══╝╚══╝ ╚═╝      ╚═════╝ ╚═╝  ╚═╝

       SnowFoxOS v3 — Void Linux + runit + i3 + X11
       Your computer belongs to you.

EOF
}

# ─────────────────────────────────────────────
# Prüfungen

check_root() {
    [[ $EUID -ne 0 ]] && error "Bitte als root ausführen: sudo ./install.sh"
    success "Root-Rechte vorhanden."
}

check_void() {
    command -v xbps-install >/dev/null 2>&1 || error "Kein Void (xbps fehlt)"
    success "Void Linux erkannt."
}

check_user() {
    # SUDO_USER Fallback auf ersten User in /home
    if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        REALUSER="$SUDO_USER"
    else
        REALUSER=$(ls /home 2>/dev/null | head -1)
        [[ -z "$REALUSER" ]] && error "Kein Nutzer in /home gefunden. Bitte erst einen User anlegen:\n  useradd -m -G wheel,audio,video,input deinname\n  passwd deinname"
        warn "SUDO_USER nicht gesetzt — verwende: $REALUSER"
    fi
    HOMEDIR="/home/$REALUSER"
    [[ ! -d "$HOMEDIR" ]] && error "Home-Verzeichnis nicht gefunden: $HOMEDIR"
    success "Nutzer: $REALUSER ($HOMEDIR)"
}

detect_gpu() {
    info "GPU wird erkannt..."
    if lspci 2>/dev/null | grep -qi "nvidia"; then
        GPU="nvidia"
        EXTRA_PACKAGES=(nvidia)
        success "NVIDIA GPU erkannt."
    elif lspci 2>/dev/null | grep -qi "amd\|radeon"; then
        GPU="amd"
        EXTRA_PACKAGES=(mesa mesa-dri vulkan-loader mesa-vulkan-radeon)
        success "AMD GPU erkannt."
    elif lspci 2>/dev/null | grep -qi "intel"; then
        GPU="intel"
        EXTRA_PACKAGES=(mesa mesa-dri vulkan-loader mesa-vulkan-intel)
        success "Intel GPU erkannt."
    else
        GPU="generic"
        EXTRA_PACKAGES=(mesa mesa-dri)
        warn "GPU nicht erkannt — generische Treiber."
    fi
}

# ─────────────────────────────────────────────
# Pakete

PACKAGES=(
    # X11 Basis
    xorg-minimal
    xorg-input-drivers
    xorg-video-drivers
    xinit
    xrandr
    xset
    xsetroot
    xclip
    xprop

    # i3 + Desktop
    i3
    i3lock
    polybar
    rofi
    feh
    dunst
    libnotify
    picom

    # Terminal + Dateimanager
    kitty
    lf

    # Audio
    pipewire
    pipewire-pulse
    wireplumber
    alsa-utils
    alsa-pipewire

    # Netzwerk
    NetworkManager
    network-manager-applet

    # Fonts
    noto-fonts-ttf
    font-awesome6

    # Tools
    btop
    curl
    wget
    git
    unzip
    zip
    maim
    scrot
    pciutils

    # Media
    mpv
    yt-dlp

    # Akku + Blaulicht
    tlp
    redshift

    # Theming
    gtk+3
    adwaita-icon-theme
    lxappearance

    # System
    dbus
    elogind
    polkit
    udisks2
    brightnessctl

    # Passwort
    gnupg
    pass
)

# ─────────────────────────────────────────────
# LibreWolf — separates Repo nötig

install_librewolf() {
    info "LibreWolf wird installiert..."

    # Prüfen ob xbps-src oder Flatpak verfügbar
    if xbps-query librewolf &>/dev/null; then
        xbps-install -S --yes librewolf
        success "LibreWolf installiert."
    elif command -v flatpak &>/dev/null; then
        flatpak install -y flathub io.gitlab.librewolf-community.librewolf 2>/dev/null
        success "LibreWolf via Flatpak installiert."
    else
        # Flatpak als Fallback installieren
        xbps-install -S --yes flatpak
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        flatpak install -y flathub io.gitlab.librewolf-community.librewolf 2>/dev/null
        success "LibreWolf via Flatpak installiert."
    fi
}

# ─────────────────────────────────────────────
# Installation

update_system() {
    info "System wird aktualisiert..."
    xbps-install -Syu --yes
    success "System aktuell."
}

install_packages() {
    info "Pakete werden installiert (das kann etwas dauern)..."

    # Pakete einzeln installieren damit ein Fehler nicht alles stoppt
    local failed=()
    for pkg in "${PACKAGES[@]}" "${EXTRA_PACKAGES[@]}"; do
        if xbps-install -S --yes "$pkg" 2>/dev/null; then
            success "Installiert: $pkg"
        else
            warn "Nicht verfügbar: $pkg (übersprungen)"
            failed+=("$pkg")
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        warn "Folgende Pakete konnten nicht installiert werden: ${failed[*]}"
    fi

    success "Paket-Installation abgeschlossen."
}

# ─────────────────────────────────────────────
# Services (runit)

enable_services() {
    info "Dienste werden aktiviert (runit)..."
    local services=(dbus elogind NetworkManager tlp pipewire wireplumber)
    for svc in "${services[@]}"; do
        if [[ -d /etc/sv/$svc ]]; then
            ln -sf /etc/sv/$svc /var/service/$svc 2>/dev/null || true
            success "Service aktiviert: $svc"
        else
            warn "Service nicht gefunden: $svc (übersprungen)"
        fi
    done
}

disable_services() {
    local disable=(wpa_supplicant acpid)
    for svc in "${disable[@]}"; do
        if [[ -L /var/service/$svc ]]; then
            rm -f /var/service/$svc
            success "Service deaktiviert: $svc"
        fi
    done
}

# ─────────────────────────────────────────────
# User-Gruppen setzen

setup_user_groups() {
    info "Nutzer-Gruppen werden eingerichtet..."
    local groups=(wheel audio video input network storage)
    for grp in "${groups[@]}"; do
        if getent group "$grp" &>/dev/null; then
            usermod -aG "$grp" "$REALUSER" 2>/dev/null && success "Gruppe hinzugefügt: $grp" || true
        fi
    done
}

# ─────────────────────────────────────────────
# Configs installieren

install_configs() {
    info "Konfigurationsdateien werden installiert..."
    local cfg
    cfg="$(dirname "$(realpath "$0")")/configs"

    if [[ ! -d "$cfg" ]]; then
        error "configs/ Ordner nicht gefunden. Bitte sicherstellen dass du im SnowFoxOS-v3 Verzeichnis bist."
    fi

    mkdir -p "$HOMEDIR/.config"

    for dir in i3 polybar rofi kitty dunst redshift; do
        if [[ -d "$cfg/$dir" ]]; then
            cp -r "$cfg/$dir" "$HOMEDIR/.config/"
            success "Config installiert: $dir"
        else
            warn "Config nicht gefunden: $dir"
        fi
    done

    chmod +x "$HOMEDIR/.config/polybar/launch.sh" 2>/dev/null || true

    if [[ -f "$cfg/i3lock/lock.sh" ]]; then
        cp "$cfg/i3lock/lock.sh" /usr/local/bin/snowfox-lock
        chmod +x /usr/local/bin/snowfox-lock
        success "Lock-Screen installiert."
    fi

    chown -R "$REALUSER:$REALUSER" "$HOMEDIR/.config"
}

# ─────────────────────────────────────────────
# X11 Autostart

setup_autostart() {
    info "X11 Autostart wird eingerichtet..."

    cat > "$HOMEDIR/.xinitrc" << 'XINITRC'
#!/bin/sh
# SnowFoxOS v3 — .xinitrc
eval $(dbus-launch --sh-syntax)
export GTK_THEME=Adwaita:dark
xsetroot -cursor_name left_ptr
setxkbmap de
exec i3
XINITRC

    cat > "$HOMEDIR/.bash_profile" << 'BASHPROFILE'
# SnowFoxOS v3 — X11 startet automatisch auf TTY1
if [[ -z $DISPLAY && $XDG_VTNR -eq 1 ]]; then
    exec startx
fi
BASHPROFILE

    chmod +x "$HOMEDIR/.xinitrc"
    chown "$REALUSER:$REALUSER" "$HOMEDIR/.xinitrc" "$HOMEDIR/.bash_profile"
    success "Autostart eingerichtet (startx auf TTY1)."
}

# ─────────────────────────────────────────────
# snowfox CLI

install_snowfox_cli() {
    info "snowfox CLI wird installiert..."
    local script_dir
    script_dir="$(dirname "$(realpath "$0")")"

    if [[ -f "$script_dir/snowfox" ]]; then
        cp "$script_dir/snowfox" /usr/local/bin/snowfox
        chmod +x /usr/local/bin/snowfox
        success "snowfox CLI installiert."
    else
        warn "snowfox Script nicht gefunden — übersprungen."
    fi
}

# ─────────────────────────────────────────────
# Performance-Tuning

tune_system() {
    info "System wird optimiert..."

    cat > /etc/sysctl.d/99-snowfox.conf << 'SYSCTL'
vm.swappiness=10
vm.vfs_cache_pressure=50
kernel.nmi_watchdog=0
net.core.netdev_max_backlog=16384
SYSCTL

    sysctl -p /etc/sysctl.d/99-snowfox.conf 2>/dev/null || true

    mkdir -p "$HOMEDIR/Pictures/Wallpapers"
    local script_dir
    script_dir="$(dirname "$(realpath "$0")")"

    if ls "$script_dir/wallpapers/"* &>/dev/null; then
        cp "$script_dir/wallpapers/"* "$HOMEDIR/Pictures/Wallpapers/"
        success "Wallpapers kopiert."
    else
        warn "Keine Wallpapers gefunden in wallpapers/ — bitte manuell hinzufügen."
    fi

    chown -R "$REALUSER:$REALUSER" "$HOMEDIR/Pictures"
    success "System optimiert."
}

# ─────────────────────────────────────────────
# Greeting

install_greeting() {
    info "Greeting wird installiert..."
    local script_dir
    script_dir="$(dirname "$(realpath "$0")")"

    if [[ -f "$script_dir/snowfox-greeting.sh" ]]; then
        cp "$script_dir/snowfox-greeting.sh" /usr/local/bin/snowfox-greeting
        chmod +x /usr/local/bin/snowfox-greeting

        if ! grep -q "snowfox-greeting" "$HOMEDIR/.bashrc" 2>/dev/null; then
            printf '\n# SnowFoxOS Greeting\n[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting\n' >> "$HOMEDIR/.bashrc"
        fi
        chown "$REALUSER:$REALUSER" "$HOMEDIR/.bashrc" 2>/dev/null || true
        success "Greeting installiert."
    fi
}

# ─────────────────────────────────────────────
# Hauptprogramm

main() {
    clear
    banner

    info "Starte Prüfungen..."
    check_root
    check_void
    check_user
    detect_gpu

    echo ""
    echo -e "${BOLD}  Bereit zur Installation${NC}"
    echo -e "  Nutzer:  ${CYAN}$REALUSER${NC}"
    echo -e "  Basis:   ${CYAN}Void Linux ($LIBC) + runit + i3 + X11${NC}"
    echo -e "  GPU:     ${CYAN}$GPU${NC}"
    echo ""
    read -rp "  Fortfahren? [j/N] " confirm
    [[ "$confirm" =~ ^[jJ]$ ]] || { echo "Abgebrochen."; exit 0; }
    echo ""

    update_system
    install_packages
    install_librewolf
    enable_services
    disable_services
    setup_user_groups
    install_configs
    setup_autostart
    install_snowfox_cli
    tune_system
    install_greeting

    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   SnowFoxOS v3 erfolgreich installiert!  ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Starte neu und logge dich auf ${BOLD}TTY1${NC} ein."
    echo -e "  X11 + i3 starten automatisch."
    echo ""
    read -rp "  Jetzt neu starten? [j/N] " reboot_now
    [[ "$reboot_now" =~ ^[jJ]$ ]] && reboot
}

main "$@"
