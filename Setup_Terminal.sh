#!/usr/bin/env bash
# El script continúa aunque un paso falle (sin set -e)

# ── Colores ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()      { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()    { echo -e "${RED}[FAIL]${NC} $1"; }
section() { echo -e "\n${CYAN}>>> $1${NC}"; }

echo "==== Terminal Customization Script ===="

# ── Detectar gestor de paquetes ────────────────────────────────────────────────
if command -v apt >/dev/null 2>&1; then
    PKG="apt"
    UPDATE="sudo apt update -y"
    INSTALL="sudo apt install -y"
elif command -v dnf >/dev/null 2>&1; then
    PKG="dnf"
    UPDATE="sudo dnf makecache -y"
    INSTALL="sudo dnf install -y"
elif command -v pacman >/dev/null 2>&1; then
    PKG="pacman"
    UPDATE="sudo pacman -Sy"
    INSTALL="sudo pacman -S --noconfirm"
elif command -v zypper >/dev/null 2>&1; then
    PKG="zypper"
    UPDATE="sudo zypper refresh"
    INSTALL="sudo zypper install -y"
else
    fail "Gestor de paquetes no soportado. Saliendo."
    exit 1
fi

# Detectar entorno de escritorio
DE="${XDG_CURRENT_DESKTOP:-unknown}"
echo "Detected package manager      : $PKG"
echo "Detected desktop environment  : $DE"

$UPDATE || warn "Fallo al actualizar lista de paquetes, continuando..."

########################################
# 1. Herramientas base
########################################
section "[1/7] Installing base tools (curl, wget, unzip, git, fontconfig)..."
$INSTALL curl wget unzip git fontconfig \
    && ok "Base tools installed." \
    || fail "Algunos base tools fallaron."

########################################
# 2. Nerd Fonts
########################################
section "[2/7] Installing Nerd Fonts..."
FONT_DIR="$HOME/.local/share/fonts/nerd-fonts"
mkdir -p "$FONT_DIR"

NERD_FONTS=("JetBrainsMono" "FiraCode" "CaskaydiaCove")

for font in "${NERD_FONTS[@]}"; do
    URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/${font}.zip"
    TMPZIP="/tmp/${font}.zip"
    echo "  Downloading $font..."
    if wget -q --tries=3 --timeout=60 -O "$TMPZIP" "$URL"; then
        unzip -oq "$TMPZIP" -d "$FONT_DIR" || true
        rm -f "$TMPZIP"
        ok "$font extracted."
    else
        fail "No se pudo descargar $font. Saltando."
        rm -f "$TMPZIP"
    fi
done

fc-cache -f >/dev/null 2>&1 && ok "Font cache rebuilt." || warn "fc-cache falló."

########################################
# 3. ZSH + plugins  (ZSH = shell que corre DENTRO de Kitty)
########################################
section "[3/7] Installing ZSH + plugins..."
$INSTALL zsh && ok "ZSH installed." || fail "ZSH install failed."

case "$PKG" in
    apt|dnf|zypper)
        $INSTALL zsh-autosuggestions zsh-syntax-highlighting \
            && ok "ZSH plugins installed." \
            || warn "ZSH plugins no disponibles en repos."
        ;;
    pacman)
        $INSTALL zsh-autosuggestions zsh-syntax-highlighting \
            && ok "ZSH plugins installed." \
            || warn "ZSH plugins install failed."
        ;;
esac

# zsh-autocomplete
if [ ! -d "$HOME/.zsh-autocomplete" ]; then
    git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git \
        ~/.zsh-autocomplete \
        && ok "zsh-autocomplete cloned." \
        || warn "zsh-autocomplete clone failed."
else
    ok "zsh-autocomplete ya existe, saltando clone."
fi

touch ~/.zshrc

grep -qxF 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' ~/.zshrc \
    || echo 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> ~/.zshrc

grep -qxF 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' ~/.zshrc \
    || echo 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> ~/.zshrc

grep -qxF 'source ~/.zsh-autocomplete/zsh-autocomplete.plugin.zsh' ~/.zshrc \
    || echo 'source ~/.zsh-autocomplete/zsh-autocomplete.plugin.zsh' >> ~/.zshrc

ok ".zshrc updated with ZSH plugin sources."

########################################
# 4. Starship prompt
########################################
section "[4/7] Installing Starship prompt..."
if curl -sS https://starship.rs/install.sh | sh -s -- --yes; then
    ok "Starship installed."
else
    warn "Starship installation failed."
fi

grep -qxF 'eval "$(starship init zsh)"' ~/.zshrc \
    || echo 'eval "$(starship init zsh)"' >> ~/.zshrc

########################################
# 5. Atuin
########################################
section "[5/7] Installing Atuin (shell history)..."
if curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --yes; then
    ok "Atuin installed."
else
    warn "Atuin installation failed."
fi

grep -qxF 'eval "$(atuin init zsh)"' ~/.zshrc \
    || echo 'eval "$(atuin init zsh)"' >> ~/.zshrc

########################################
# 6. Kitty Terminal + configurarla como terminal predeterminada
########################################
section "[6/7] Installing Kitty terminal emulator..."

# ── Instalador oficial (fallback universal) ──────────────────────────────────
install_kitty_official() {
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin \
        && ok "Kitty installed via official kovidgoyal installer." \
        || { fail "Kitty installation failed completely."; return 1; }
}

# --- Instalar Kitty (repo primero, official installer como fallback) ---
case "$PKG" in
    apt)
        $INSTALL kitty && ok "Kitty installed via apt." \
            || { warn "apt install kitty falló, intentando instalador oficial..."; install_kitty_official; }
        ;;
    pacman)
        $INSTALL kitty && ok "Kitty installed via pacman." \
            || { warn "pacman install kitty falló, intentando instalador oficial..."; install_kitty_official; }
        ;;
    dnf)
        $INSTALL kitty && ok "Kitty installed via dnf." \
            || { warn "dnf install kitty falló, intentando instalador oficial..."; install_kitty_official; }
        ;;
    zypper)
        $INSTALL kitty && ok "Kitty installed via zypper." \
            || { warn "zypper install kitty falló, intentando instalador oficial..."; install_kitty_official; }
        ;;
esac

# Resolver ruta del binario (PATH o instalador oficial en ~/.local)
KITTY_BIN="$(command -v kitty 2>/dev/null)"
if [ -z "$KITTY_BIN" ] && [ -f "$HOME/.local/kitty.app/bin/kitty" ]; then
    KITTY_BIN="$HOME/.local/kitty.app/bin/kitty"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$KITTY_BIN" "$HOME/.local/bin/kitty" 2>/dev/null || true
fi

ZSH_PATH="$(command -v zsh 2>/dev/null || echo /bin/zsh)"

# --- Configuración de Kitty ---
KITTY_CONF="$HOME/.config/kitty/kitty.conf"
mkdir -p "$(dirname "$KITTY_CONF")"

cat > "$KITTY_CONF" << EOF
# ── Fuente ──────────────────────────────────────────────
font_family      JetBrainsMono Nerd Font
font_size        14.0

# ── Cursor ──────────────────────────────────────────────
cursor_trail     3
cursor_shape     beam

# ── Ventana ─────────────────────────────────────────────
hide_window_decorations yes
remember_window_size    yes

# ── Tabs ────────────────────────────────────────────────
tab_bar_style    powerline
tab_powerline_style slanted

# ── Shell que corre dentro de Kitty ─────────────────────
shell            $ZSH_PATH
EOF

ok "Kitty config written to $KITTY_CONF"

# ── .desktop file (universal — requerido por xdg-mime, GNOME, KDE, etc.) ────
DESKTOP_DIR="$HOME/.local/share/applications"
SYSTEM_DESKTOP_DIR="/usr/share/applications"
mkdir -p "$DESKTOP_DIR"

cat > "$DESKTOP_DIR/kitty.desktop" << EOF
[Desktop Entry]
Name=Kitty
Comment=Fast, feature-rich, GPU-based terminal emulator
Exec=${KITTY_BIN:-kitty} %u
Icon=kitty
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
StartupNotify=true
MimeType=x-scheme-handler/terminal;
EOF

update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
ok "kitty.desktop created at $DESKTOP_DIR/kitty.desktop"

# ── Variable de entorno $TERMINAL (universal) ────────────────────────────────
PROFILE_LINE='export TERMINAL=kitty'
grep -qxF "$PROFILE_LINE" ~/.profile 2>/dev/null \
    || echo "$PROFILE_LINE" >> ~/.profile
grep -qxF "$PROFILE_LINE" ~/.zshrc 2>/dev/null \
    || echo "$PROFILE_LINE" >> ~/.zshrc
grep -qxF "alias term='kitty'" ~/.zshrc 2>/dev/null \
    || echo "alias term='kitty'" >> ~/.zshrc
ok "TERMINAL=kitty set in ~/.profile and ~/.zshrc"

# ── Capas universales de integración (se aplican siempre, en todas las distros)
# Estas tres capas cubren la mayoría de los DEs y lanzadores:
#   1. xdg-mime   → registra Kitty como handler del scheme "terminal://"
#   2. update-alternatives → enlaza /usr/bin/x-terminal-emulator a Kitty
#   3. $TERMINAL  → variable que leen muchos DEs / scripts como fallback

echo "  Aplicando capas universales de integración..."

# Capa 1 — xdg-mime (funciona en GNOME, KDE, XFCE, MATE, LXQt, etc.)
if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default kitty.desktop x-scheme-handler/terminal 2>/dev/null \
        && ok "xdg-mime: x-scheme-handler/terminal → kitty.desktop" \
        || warn "xdg-mime falló (¿sesión gráfica activa?)."
else
    warn "xdg-mime no encontrado; saltando."
fi

# Capa 2 — update-alternatives (Debian/Ubuntu/Fedora/openSUSE lo soportan)
if command -v update-alternatives >/dev/null 2>&1 && [ -n "$KITTY_BIN" ] && [ -f "$KITTY_BIN" ]; then
    sudo update-alternatives --install /usr/bin/x-terminal-emulator \
        x-terminal-emulator "$KITTY_BIN" 50 2>/dev/null \
    && sudo update-alternatives --set x-terminal-emulator "$KITTY_BIN" 2>/dev/null \
    && ok "update-alternatives: x-terminal-emulator → Kitty." \
    || warn "update-alternatives falló (puede requerir sudo manual)."
else
    warn "update-alternatives no disponible en este sistema; saltando."
fi

# ── Configuración específica por DE (aditiva — no se excluyen entre sí) ──────
echo "  Aplicando configuración específica para DE: $DE"

# ── GNOME / Ubuntu / Unity ───────────────────────────────────────────────────
if echo "$DE" | grep -qi "gnome\|ubuntu\|unity"; then
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.default-applications.terminal exec "${KITTY_BIN:-kitty}" 2>/dev/null \
            && gsettings set org.gnome.desktop.default-applications.terminal exec-arg "" 2>/dev/null \
            && ok "GNOME: terminal predeterminada → Kitty." \
            || warn "gsettings GNOME falló (¿sesión gráfica activa?)."
    else
        warn "gsettings no encontrado."
    fi
fi

# ── KDE Plasma ───────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "kde\|plasma"; then
    KDE_CONF="$HOME/.config/kdeglobals"
    mkdir -p "$(dirname "$KDE_CONF")"
    if grep -q "^\[General\]" "$KDE_CONF" 2>/dev/null; then
        # Insertar o reemplazar Terminal= dentro de [General]
        sed -i '/^\[General\]/,/^\[/ { s|^Terminal=.*|Terminal=${KITTY_BIN:-kitty}|; }' "$KDE_CONF" 2>/dev/null || true
        grep -q "^Terminal=" "$KDE_CONF" 2>/dev/null \
            || sed -i '/^\[General\]/a Terminal='"${KITTY_BIN:-kitty}" "$KDE_CONF" 2>/dev/null || true
    else
        printf '\n[General]\nTerminal=%s\n' "${KITTY_BIN:-kitty}" >> "$KDE_CONF"
    fi
    # konsolerc para que "Open terminal" en Dolphin también use Kitty
    KONSOLE_RC="$HOME/.config/konsolerc"
    mkdir -p "$(dirname "$KONSOLE_RC")"
    grep -q "^\[Desktop Entry\]" "$KONSOLE_RC" 2>/dev/null \
        || printf '[Desktop Entry]\nDefaultProfile=\n' >> "$KONSOLE_RC"
    # kwalletrc / kio: algunos lanzadores de KDE leen TerminalApplication
    KDE_APP_RC="$HOME/.config/kdedefaults/kdeglobals"
    mkdir -p "$(dirname "$KDE_APP_RC")"
    grep -q "^TerminalApplication=" "$KDE_APP_RC" 2>/dev/null \
        && sed -i "s|^TerminalApplication=.*|TerminalApplication=${KITTY_BIN:-kitty}|" "$KDE_APP_RC" \
        || echo "TerminalApplication=${KITTY_BIN:-kitty}" >> "$KDE_APP_RC"
    ok "KDE: terminal predeterminada → Kitty (kdeglobals + kdedefaults)."
fi

# ── XFCE ─────────────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "xfce"; then
    if command -v xfconf-query >/dev/null 2>&1; then
        # Terminal emulator preferida para "Abrir terminal aquí"
        xfconf-query -c xfce4-session -p /sessions/Failsafe/Client0_Command \
            -t string -s "${KITTY_BIN:-kitty}" --create 2>/dev/null \
            && ok "XFCE: sesión Failsafe → Kitty." \
            || warn "xfconf-query sesión falló."
        xfconf-query -c xfce4-keyboard-shortcuts \
            -p "/commands/custom/<Primary><Alt>t" \
            -t string -s "${KITTY_BIN:-kitty}" --create 2>/dev/null || true
        xfconf-query -c xfce4-file-manager -p /misc-folder-open-on-dnd \
            -t string -s "${KITTY_BIN:-kitty}" --create 2>/dev/null || true
        ok "XFCE: terminal predeterminada → Kitty."
    else
        warn "xfconf-query no encontrado."
    fi
    # helpers.rc para Thunar y otros programas XFCE
    XFCE_HELPERS="$HOME/.config/xfce4/helpers.rc"
    mkdir -p "$(dirname "$XFCE_HELPERS")"
    if grep -q "^TerminalEmulator=" "$XFCE_HELPERS" 2>/dev/null; then
        sed -i "s|^TerminalEmulator=.*|TerminalEmulator=kitty|" "$XFCE_HELPERS"
    else
        echo "TerminalEmulator=kitty" >> "$XFCE_HELPERS"
    fi
    ok "XFCE: helpers.rc actualizado → TerminalEmulator=kitty."
fi

# ── MATE ──────────────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "mate"; then
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.mate.applications.terminal exec "${KITTY_BIN:-kitty}" 2>/dev/null \
            && gsettings set org.mate.applications.terminal exec-arg "" 2>/dev/null \
            && ok "MATE: terminal predeterminada → Kitty." \
            || warn "gsettings MATE falló."
    else
        warn "gsettings no encontrado."
    fi
fi

# ── LXDE ─────────────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "lxde"; then
    LXDE_CONF="$HOME/.config/lxterminal/lxterminal.conf"
    if [ -f "$LXDE_CONF" ]; then
        grep -q "^ExecTerminal=" "$LXDE_CONF" 2>/dev/null \
            && sed -i "s|^ExecTerminal=.*|ExecTerminal=${KITTY_BIN:-kitty}|" "$LXDE_CONF" \
            || echo "ExecTerminal=${KITTY_BIN:-kitty}" >> "$LXDE_CONF"
    fi
    # openbox / LXDE usa ~/.config/libfm/libfm.conf para "Abrir terminal aquí"
    LIBFM_CONF="$HOME/.config/libfm/libfm.conf"
    if [ -f "$LIBFM_CONF" ]; then
        grep -q "^terminal=" "$LIBFM_CONF" 2>/dev/null \
            && sed -i "s|^terminal=.*|terminal=${KITTY_BIN:-kitty}|" "$LIBFM_CONF" \
            || sed -i '/^\[config\]/a terminal='"${KITTY_BIN:-kitty}" "$LIBFM_CONF" 2>/dev/null || true
    fi
    ok "LXDE: terminal predeterminada → Kitty."
fi

# ── LXQt ─────────────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "lxqt"; then
    LXQT_CONF="$HOME/.config/lxqt/lxqt.conf"
    mkdir -p "$(dirname "$LXQT_CONF")"
    if grep -q "^terminal=" "$LXQT_CONF" 2>/dev/null; then
        sed -i "s|^terminal=.*|terminal=${KITTY_BIN:-kitty}|" "$LXQT_CONF"
    else
        # Asegurarse de que la sección [General] exista
        grep -q "^\[General\]" "$LXQT_CONF" 2>/dev/null \
            || echo "[General]" >> "$LXQT_CONF"
        sed -i '/^\[General\]/a terminal='"${KITTY_BIN:-kitty}" "$LXQT_CONF" 2>/dev/null || true
    fi
    ok "LXQt: terminal predeterminada → Kitty."
fi

# ── Cinnamon ─────────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "cinnamon\|x-cinnamon"; then
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.cinnamon.desktop.default-applications.terminal exec "${KITTY_BIN:-kitty}" 2>/dev/null \
            && gsettings set org.cinnamon.desktop.default-applications.terminal exec-arg "" 2>/dev/null \
            && ok "Cinnamon: terminal predeterminada → Kitty." \
            || warn "gsettings Cinnamon falló."
    fi
fi

# ── Deepin / DDE ─────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "deepin\|dde"; then
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set com.deepin.desktop.default-applications.terminal exec "${KITTY_BIN:-kitty}" 2>/dev/null \
            && ok "Deepin: terminal predeterminada → Kitty." \
            || warn "gsettings Deepin falló."
    fi
fi

# ── Fallback: si el DE no fue reconocido por ninguna rama ─────────────────────
_de_known=0
for _pat in gnome ubuntu unity kde plasma xfce mate lxde lxqt cinnamon x-cinnamon deepin dde; do
    echo "$DE" | grep -qi "$_pat" && { _de_known=1; break; }
done
[ "$_de_known" -eq 0 ] && warn "DE '$DE' no reconocido; solo se aplicaron las capas universales (xdg-mime, \$TERMINAL, update-alternatives)."

########################################
# 7. Fastfetch
########################################
section "[7/7] Installing Fastfetch..."

install_fastfetch() {
    case "$PKG" in
        apt)    sudo apt install -y fastfetch ;;
        pacman) sudo pacman -S --noconfirm fastfetch ;;
        dnf)    sudo dnf install -y fastfetch ;;
        zypper) sudo zypper install -y fastfetch ;;
    esac
}

if install_fastfetch; then
    ok "Fastfetch installed via package manager."
elif [ "$PKG" = "apt" ]; then
    warn "apt install fastfetch falló. Intentando PPA..."
    if sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch \
       && sudo apt update -y \
       && sudo apt install -y fastfetch; then
        ok "Fastfetch installed via PPA."
    else
        warn "PPA falló. Intentando .deb desde GitHub..."
        ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
        DEB_URL=$(curl -fsSL "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" \
                  | grep "fastfetch-linux-${ARCH}\.deb" \
                  | cut -d '"' -f 4 | head -1)
        if [ -n "$DEB_URL" ] \
           && wget -q "$DEB_URL" -O /tmp/fastfetch.deb \
           && sudo dpkg -i /tmp/fastfetch.deb \
           && sudo apt --fix-broken install -y; then
            ok "Fastfetch installed from GitHub .deb."
        else
            fail "Fastfetch no pudo instalarse por ningún método."
        fi
    fi
fi

FASTFETCH_DIR="$HOME/.config/fastfetch"
ASSETS_DIR="$FASTFETCH_DIR/assets"
mkdir -p "$ASSETS_DIR"

curl -fsSL \
    "https://raw.githubusercontent.com/itsfoss/text-script-files/refs/heads/master/config/fastfetch/sample_2.jsonc" \
    -o "$FASTFETCH_DIR/sample_2.jsonc" \
    && ok "Fastfetch config downloaded." \
    || warn "Fastfetch config download failed."

curl -fsSL \
    "https://raw.githubusercontent.com/itsfoss/text-script-files/refs/heads/master/config/fastfetch/assets/jedi.png" \
    -o "$ASSETS_DIR/jedi.png" \
    && ok "Fastfetch image downloaded." \
    || warn "Fastfetch image download failed."

grep -qF "fastfetch -c ~/.config/fastfetch/sample_2.jsonc" "$HOME/.zshrc" \
    || echo 'fastfetch -c ~/.config/fastfetch/sample_2.jsonc' >> "$HOME/.zshrc"

ok "Fastfetch configured."

########################################
# Final
########################################
echo ""
echo "======================================================="
echo "           ==== Setup Completed ===="
echo "======================================================="
echo ""
echo "Pasos finales:"
echo ""
echo "  1) Cambia tu shell de LOGIN a ZSH (shell ≠ terminal):"
echo "       chsh -s $(command -v zsh 2>/dev/null || echo /bin/zsh)"
echo ""
echo "  2) Kitty ya fue configurada como terminal predeterminada."
echo "     Si el cambio no se refleja, cierra sesión y vuelve a entrar."
echo ""
echo "  3) Abre Kitty y verás ZSH + Starship + Atuin + Fastfetch."
echo ""
echo "  RECUERDA:"
echo "    · Kitty  = emulador de terminal (la ventana gráfica)"
echo "    · ZSH    = shell (el intérprete de comandos dentro de Kitty)"
echo "    · chsh cambia el shell, no la terminal gráfica."
echo "======================================================="
