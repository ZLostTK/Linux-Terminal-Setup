#!/usr/bin/env bash
# El script continúa aunque un paso falle (sin set -e)

# ── Colores ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()      { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()    { echo -e "${RED}[FAIL]${NC} $1"; }
section() { echo -e "\n${CYAN}>>> $1${NC}"; }
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }

# ── Confirmación de usuario ────────────────────────────────────────────────────
# Uso: confirm "¿Instalar X?" && do_something
# Lee siempre desde /dev/tty para funcionar correctamente con curl | bash
confirm() {
    local prompt="${1:-¿Continuar?}" response
    echo -e "${YELLOW}[?]${NC} ${prompt} [s/N] \c"
    # Cuando el script llega via pipe (curl | bash), stdin es el pipe y no el
    # teclado; leer de /dev/tty garantiza interactividad en ambos casos.
    if [ -t 0 ]; then
        read -r response
    else
        read -r response </dev/tty
    fi
    case "$response" in
        [sS][iI]|[sS]) return 0 ;;
        *) info "Paso omitido por el usuario."; return 1 ;;
    esac
}

# ── Verificar si un comando/paquete ya está instalado ─────────────────────────
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# Verifica instalación vía gestor de paquetes (nombre de paquete puede diferir del binario)
pkg_installed() {
    local pkg="$1"
    case "$PKG" in
        apt)    dpkg -s "$pkg" >/dev/null 2>&1 ;;
        dnf)    rpm -q "$pkg" >/dev/null 2>&1 ;;
        pacman) pacman -Q "$pkg" >/dev/null 2>&1 ;;
        zypper) rpm -q "$pkg" >/dev/null 2>&1 ;;
        *)      return 1 ;;
    esac
}

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
echo ""
echo "Este script instalará y configurará:"
echo "  1) Herramientas base (curl, wget, unzip, git, fontconfig)"
echo "  2) Nerd Fonts (JetBrainsMono, FiraCode, CaskaydiaCove)"
echo "  3) ZSH + plugins (autosuggestions, syntax-highlighting, autocomplete)"
echo "  4) Starship prompt"
echo "  5) Atuin (historial de shell)"
echo "  6) Kitty terminal emulator"
echo "  7) Fastfetch"
echo ""
confirm "¿Deseas continuar con la configuración?" || { echo "Instalación cancelada."; exit 0; }

confirm "¿Actualizar la lista de paquetes del sistema ahora?" && {
    $UPDATE || warn "Fallo al actualizar lista de paquetes, continuando..."
}

########################################
# 1. Herramientas base
########################################
section "[1/7] Base tools (curl, wget, unzip, git, fontconfig)"

BASE_TOOLS=(curl wget unzip git fontconfig)
MISSING_TOOLS=()

for tool in "${BASE_TOOLS[@]}"; do
    if is_installed "$tool" || pkg_installed "$tool"; then
        info "$tool ya está instalado. Saltando."
    else
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    ok "Todas las herramientas base ya están instaladas."
else
    echo "  Herramientas faltantes: ${MISSING_TOOLS[*]}"
    confirm "¿Instalar herramientas base faltantes (${MISSING_TOOLS[*]})?" && {
        $INSTALL "${MISSING_TOOLS[@]}" \
            && ok "Base tools instaladas." \
            || fail "Algunos base tools fallaron."
    }
fi

########################################
# 2. Nerd Fonts
########################################
section "[2/7] Nerd Fonts"

FONT_DIR="$HOME/.local/share/fonts/nerd-fonts"
NERD_FONTS=("JetBrainsMono" "FiraCode" "CaskaydiaCove")

confirm "¿Instalar/actualizar Nerd Fonts (${NERD_FONTS[*]})?" && {
    mkdir -p "$FONT_DIR"
    _any_font=0

    for font in "${NERD_FONTS[@]}"; do
        # Verificar si la fuente ya está instalada buscando archivos en el dir
        if ls "$FONT_DIR"/${font}* >/dev/null 2>&1; then
            info "Fuente $font ya encontrada en $FONT_DIR. Saltando."
            continue
        fi
        # También verificar con fc-list
        if fc-list 2>/dev/null | grep -qi "$font"; then
            info "Fuente $font ya registrada en el sistema. Saltando."
            continue
        fi

        URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/${font}.zip"
        TMPZIP="/tmp/${font}.zip"
        echo "  Downloading $font..."
        if wget -q --tries=3 --timeout=60 -O "$TMPZIP" "$URL"; then
            unzip -oq "$TMPZIP" -d "$FONT_DIR" || true
            rm -f "$TMPZIP"
            ok "$font extraída."
            _any_font=1
        else
            fail "No se pudo descargar $font. Saltando."
            rm -f "$TMPZIP"
        fi
    done

    if [ "$_any_font" -eq 1 ]; then
        fc-cache -f >/dev/null 2>&1 && ok "Font cache reconstruida." || warn "fc-cache falló."
    else
        ok "No se instalaron fuentes nuevas (ya estaban presentes o fallaron)."
    fi
}

########################################
# 3. ZSH + plugins
########################################
section "[3/7] ZSH + plugins"

if is_installed zsh; then
    info "ZSH ya está instalado ($(zsh --version 2>/dev/null | head -1)). Saltando instalación."
else
    confirm "¿Instalar ZSH?" && {
        $INSTALL zsh && ok "ZSH instalado." || fail "ZSH install failed."
    }
fi

# Plugins vía gestor de paquetes
_zsh_plugins_needed=0
for _pkg in zsh-autosuggestions zsh-syntax-highlighting; do
    pkg_installed "$_pkg" || { _zsh_plugins_needed=1; break; }
done

if [ "$_zsh_plugins_needed" -eq 0 ]; then
    info "Plugins ZSH (autosuggestions, syntax-highlighting) ya instalados."
else
    confirm "¿Instalar plugins ZSH (zsh-autosuggestions, zsh-syntax-highlighting) vía gestor de paquetes?" && {
        case "$PKG" in
            apt|dnf|zypper|pacman)
                $INSTALL zsh-autosuggestions zsh-syntax-highlighting \
                    && ok "ZSH plugins instalados." \
                    || warn "ZSH plugins no disponibles en repos."
                ;;
        esac
    }
fi

# zsh-autocomplete
if [ -d "$HOME/.zsh-autocomplete" ]; then
    info "zsh-autocomplete ya existe en ~/.zsh-autocomplete. Saltando clone."
else
    confirm "¿Clonar zsh-autocomplete desde GitHub?" && {
        git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git \
            ~/.zsh-autocomplete \
            && ok "zsh-autocomplete clonado." \
            || warn "zsh-autocomplete clone falló."
    }
fi

# Actualizar .zshrc con sources de plugins
confirm "¿Actualizar ~/.zshrc con los sources de los plugins ZSH?" && {
    touch ~/.zshrc

    grep -qxF 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' ~/.zshrc \
        || echo 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> ~/.zshrc

    grep -qxF 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' ~/.zshrc \
        || echo 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> ~/.zshrc

    grep -qxF 'source ~/.zsh-autocomplete/zsh-autocomplete.plugin.zsh' ~/.zshrc \
        || echo 'source ~/.zsh-autocomplete/zsh-autocomplete.plugin.zsh' >> ~/.zshrc

    ok ".zshrc actualizado con sources de plugins ZSH."
}

########################################
# 4. Starship prompt
########################################
section "[4/7] Starship prompt"

if is_installed starship; then
    info "Starship ya está instalado ($(starship --version 2>/dev/null)). Saltando instalación."
else
    confirm "¿Instalar Starship prompt?" && {
        if curl -sS https://starship.rs/install.sh | sh -s -- --yes; then
            ok "Starship instalado."
        else
            warn "Starship installation failed."
        fi
    }
fi

confirm "¿Agregar 'eval \"\$(starship init zsh)\"' al ~/.zshrc?" && {
    grep -qxF 'eval "$(starship init zsh)"' ~/.zshrc \
        || echo 'eval "$(starship init zsh)"' >> ~/.zshrc
    ok ".zshrc actualizado con init de Starship."
}

########################################
# 5. Atuin
########################################
section "[5/7] Atuin (shell history)"

if is_installed atuin; then
    info "Atuin ya está instalado ($(atuin --version 2>/dev/null)). Saltando instalación."
else
    confirm "¿Instalar Atuin (historial de shell mejorado)?" && {
        if curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --yes; then
            ok "Atuin instalado."
        else
            warn "Atuin installation failed."
        fi
    }
fi

confirm "¿Agregar 'eval \"\$(atuin init zsh)\"' al ~/.zshrc?" && {
    grep -qxF 'eval "$(atuin init zsh)"' ~/.zshrc \
        || echo 'eval "$(atuin init zsh)"' >> ~/.zshrc
    ok ".zshrc actualizado con init de Atuin."
}

########################################
# 6. Kitty Terminal
########################################
section "[6/7] Kitty terminal emulator"

# ── Instalador oficial (fallback universal) ──────────────────────────────────
install_kitty_official() {
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin \
        && ok "Kitty instalado vía instalador oficial de kovidgoyal." \
        || { fail "Kitty installation failed completely."; return 1; }
}

if is_installed kitty || [ -f "$HOME/.local/kitty.app/bin/kitty" ]; then
    info "Kitty ya está instalado. Saltando instalación."
else
    confirm "¿Instalar Kitty terminal emulator?" && {
        case "$PKG" in
            apt)
                $INSTALL kitty && ok "Kitty instalado vía apt." \
                    || { warn "apt install kitty falló, intentando instalador oficial..."; install_kitty_official; }
                ;;
            pacman)
                $INSTALL kitty && ok "Kitty instalado vía pacman." \
                    || { warn "pacman install kitty falló, intentando instalador oficial..."; install_kitty_official; }
                ;;
            dnf)
                $INSTALL kitty && ok "Kitty instalado vía dnf." \
                    || { warn "dnf install kitty falló, intentando instalador oficial..."; install_kitty_official; }
                ;;
            zypper)
                $INSTALL kitty && ok "Kitty instalado vía zypper." \
                    || { warn "zypper install kitty falló, intentando instalador oficial..."; install_kitty_official; }
                ;;
        esac
    }
fi

# Resolver ruta del binario
KITTY_BIN="$(command -v kitty 2>/dev/null)"
if [ -z "$KITTY_BIN" ] && [ -f "$HOME/.local/kitty.app/bin/kitty" ]; then
    KITTY_BIN="$HOME/.local/kitty.app/bin/kitty"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$KITTY_BIN" "$HOME/.local/bin/kitty" 2>/dev/null || true
fi

ZSH_PATH="$(command -v zsh 2>/dev/null || echo /bin/zsh)"

# Configuración de Kitty
KITTY_CONF="$HOME/.config/kitty/kitty.conf"
if [ -f "$KITTY_CONF" ]; then
    info "Ya existe una configuración de Kitty en $KITTY_CONF."
    confirm "¿Sobreescribir $KITTY_CONF con la configuración nueva?" && _write_kitty_conf=1 || _write_kitty_conf=0
else
    confirm "¿Crear configuración de Kitty en $KITTY_CONF?" && _write_kitty_conf=1 || _write_kitty_conf=0
fi

if [ "$_write_kitty_conf" -eq 1 ]; then
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
    ok "Kitty config escrita en $KITTY_CONF"
fi

# .desktop file
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/kitty.desktop"

if [ -f "$DESKTOP_FILE" ]; then
    info "Ya existe $DESKTOP_FILE."
    confirm "¿Sobreescribir el .desktop file de Kitty?" && _write_desktop=1 || _write_desktop=0
else
    confirm "¿Crear kitty.desktop en $DESKTOP_DIR?" && _write_desktop=1 || _write_desktop=0
fi

if [ "$_write_desktop" -eq 1 ]; then
    mkdir -p "$DESKTOP_DIR"
    cat > "$DESKTOP_FILE" << EOF
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
    ok "kitty.desktop creado en $DESKTOP_FILE"
fi

# Variable de entorno $TERMINAL
confirm "¿Exportar TERMINAL=kitty en ~/.profile y ~/.zshrc, y crear alias 'term'?" && {
    PROFILE_LINE='export TERMINAL=kitty'
    grep -qxF "$PROFILE_LINE" ~/.profile 2>/dev/null \
        || echo "$PROFILE_LINE" >> ~/.profile
    grep -qxF "$PROFILE_LINE" ~/.zshrc 2>/dev/null \
        || echo "$PROFILE_LINE" >> ~/.zshrc
    grep -qxF "alias term='kitty'" ~/.zshrc 2>/dev/null \
        || echo "alias term='kitty'" >> ~/.zshrc
    ok "TERMINAL=kitty configurado en ~/.profile y ~/.zshrc"
}

# ── Capas universales de integración ─────────────────────────────────────────
confirm "¿Aplicar capas universales de integración (xdg-mime, update-alternatives)?" && {
    echo "  Aplicando capas universales de integración..."

    # Capa 1 — xdg-mime
    if command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default kitty.desktop x-scheme-handler/terminal 2>/dev/null \
            && ok "xdg-mime: x-scheme-handler/terminal → kitty.desktop" \
            || warn "xdg-mime falló (¿sesión gráfica activa?)."
    else
        warn "xdg-mime no encontrado; saltando."
    fi

    # Capa 2 — update-alternatives
    if command -v update-alternatives >/dev/null 2>&1 && [ -n "$KITTY_BIN" ] && [ -f "$KITTY_BIN" ]; then
        sudo update-alternatives --install /usr/bin/x-terminal-emulator \
            x-terminal-emulator "$KITTY_BIN" 50 2>/dev/null \
        && sudo update-alternatives --set x-terminal-emulator "$KITTY_BIN" 2>/dev/null \
        && ok "update-alternatives: x-terminal-emulator → Kitty." \
        || warn "update-alternatives falló (puede requerir sudo manual)."
    else
        warn "update-alternatives no disponible en este sistema; saltando."
    fi
}

# ── Configuración específica por DE ──────────────────────────────────────────
echo "  Configuración específica para DE: $DE"

# ── GNOME / Ubuntu / Unity ───────────────────────────────────────────────────
if echo "$DE" | grep -qi "gnome\|ubuntu\|unity"; then
    confirm "¿Configurar Kitty como terminal predeterminada en GNOME?" && {
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set org.gnome.desktop.default-applications.terminal exec "${KITTY_BIN:-kitty}" 2>/dev/null \
                && gsettings set org.gnome.desktop.default-applications.terminal exec-arg "" 2>/dev/null \
                && ok "GNOME: terminal predeterminada → Kitty." \
                || warn "gsettings GNOME falló (¿sesión gráfica activa?)."
        else
            warn "gsettings no encontrado."
        fi
    }
fi

# ── KDE Plasma ───────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "kde\|plasma"; then
    confirm "¿Configurar Kitty como terminal predeterminada en KDE Plasma?" && {
        KDE_CONF="$HOME/.config/kdeglobals"
        mkdir -p "$(dirname "$KDE_CONF")"
        if grep -q "^\[General\]" "$KDE_CONF" 2>/dev/null; then
            sed -i '/^\[General\]/,/^\[/ { s|^Terminal=.*|Terminal=${KITTY_BIN:-kitty}|; }' "$KDE_CONF" 2>/dev/null || true
            grep -q "^Terminal=" "$KDE_CONF" 2>/dev/null \
                || sed -i '/^\[General\]/a Terminal='"${KITTY_BIN:-kitty}" "$KDE_CONF" 2>/dev/null || true
        else
            printf '\n[General]\nTerminal=%s\n' "${KITTY_BIN:-kitty}" >> "$KDE_CONF"
        fi
        KONSOLE_RC="$HOME/.config/konsolerc"
        mkdir -p "$(dirname "$KONSOLE_RC")"
        grep -q "^\[Desktop Entry\]" "$KONSOLE_RC" 2>/dev/null \
            || printf '[Desktop Entry]\nDefaultProfile=\n' >> "$KONSOLE_RC"
        KDE_APP_RC="$HOME/.config/kdedefaults/kdeglobals"
        mkdir -p "$(dirname "$KDE_APP_RC")"
        grep -q "^TerminalApplication=" "$KDE_APP_RC" 2>/dev/null \
            && sed -i "s|^TerminalApplication=.*|TerminalApplication=${KITTY_BIN:-kitty}|" "$KDE_APP_RC" \
            || echo "TerminalApplication=${KITTY_BIN:-kitty}" >> "$KDE_APP_RC"
        ok "KDE: terminal predeterminada → Kitty (kdeglobals + kdedefaults)."
    }
fi

# ── XFCE ─────────────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "xfce"; then
    confirm "¿Configurar Kitty como terminal predeterminada en XFCE?" && {
        if command -v xfconf-query >/dev/null 2>&1; then
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
        XFCE_HELPERS="$HOME/.config/xfce4/helpers.rc"
        mkdir -p "$(dirname "$XFCE_HELPERS")"
        if grep -q "^TerminalEmulator=" "$XFCE_HELPERS" 2>/dev/null; then
            sed -i "s|^TerminalEmulator=.*|TerminalEmulator=kitty|" "$XFCE_HELPERS"
        else
            echo "TerminalEmulator=kitty" >> "$XFCE_HELPERS"
        fi
        ok "XFCE: helpers.rc actualizado → TerminalEmulator=kitty."
    }
fi

# ── MATE ──────────────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "mate"; then
    confirm "¿Configurar Kitty como terminal predeterminada en MATE?" && {
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set org.mate.applications.terminal exec "${KITTY_BIN:-kitty}" 2>/dev/null \
                && gsettings set org.mate.applications.terminal exec-arg "" 2>/dev/null \
                && ok "MATE: terminal predeterminada → Kitty." \
                || warn "gsettings MATE falló."
        else
            warn "gsettings no encontrado."
        fi
    }
fi

# ── LXDE ─────────────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "lxde"; then
    confirm "¿Configurar Kitty como terminal predeterminada en LXDE?" && {
        LXDE_CONF="$HOME/.config/lxterminal/lxterminal.conf"
        if [ -f "$LXDE_CONF" ]; then
            grep -q "^ExecTerminal=" "$LXDE_CONF" 2>/dev/null \
                && sed -i "s|^ExecTerminal=.*|ExecTerminal=${KITTY_BIN:-kitty}|" "$LXDE_CONF" \
                || echo "ExecTerminal=${KITTY_BIN:-kitty}" >> "$LXDE_CONF"
        fi
        LIBFM_CONF="$HOME/.config/libfm/libfm.conf"
        if [ -f "$LIBFM_CONF" ]; then
            grep -q "^terminal=" "$LIBFM_CONF" 2>/dev/null \
                && sed -i "s|^terminal=.*|terminal=${KITTY_BIN:-kitty}|" "$LIBFM_CONF" \
                || sed -i '/^\[config\]/a terminal='"${KITTY_BIN:-kitty}" "$LIBFM_CONF" 2>/dev/null || true
        fi
        ok "LXDE: terminal predeterminada → Kitty."
    }
fi

# ── LXQt ─────────────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "lxqt"; then
    confirm "¿Configurar Kitty como terminal predeterminada en LXQt?" && {
        LXQT_CONF="$HOME/.config/lxqt/lxqt.conf"
        mkdir -p "$(dirname "$LXQT_CONF")"
        if grep -q "^terminal=" "$LXQT_CONF" 2>/dev/null; then
            sed -i "s|^terminal=.*|terminal=${KITTY_BIN:-kitty}|" "$LXQT_CONF"
        else
            grep -q "^\[General\]" "$LXQT_CONF" 2>/dev/null \
                || echo "[General]" >> "$LXQT_CONF"
            sed -i '/^\[General\]/a terminal='"${KITTY_BIN:-kitty}" "$LXQT_CONF" 2>/dev/null || true
        fi
        ok "LXQt: terminal predeterminada → Kitty."
    }
fi

# ── Cinnamon ─────────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "cinnamon\|x-cinnamon"; then
    confirm "¿Configurar Kitty como terminal predeterminada en Cinnamon?" && {
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set org.cinnamon.desktop.default-applications.terminal exec "${KITTY_BIN:-kitty}" 2>/dev/null \
                && gsettings set org.cinnamon.desktop.default-applications.terminal exec-arg "" 2>/dev/null \
                && ok "Cinnamon: terminal predeterminada → Kitty." \
                || warn "gsettings Cinnamon falló."
        fi
    }
fi

# ── Deepin / DDE ─────────────────────────────────────────────────────────────
if echo "$DE" | grep -qi "deepin\|dde"; then
    confirm "¿Configurar Kitty como terminal predeterminada en Deepin?" && {
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set com.deepin.desktop.default-applications.terminal exec "${KITTY_BIN:-kitty}" 2>/dev/null \
                && ok "Deepin: terminal predeterminada → Kitty." \
                || warn "gsettings Deepin falló."
        fi
    }
fi

# ── Fallback: DE no reconocido ────────────────────────────────────────────────
_de_known=0
for _pat in gnome ubuntu unity kde plasma xfce mate lxde lxqt cinnamon x-cinnamon deepin dde; do
    echo "$DE" | grep -qi "$_pat" && { _de_known=1; break; }
done
[ "$_de_known" -eq 0 ] && warn "DE '$DE' no reconocido; solo se aplicaron las capas universales (xdg-mime, \$TERMINAL, update-alternatives)."

########################################
# 7. Fastfetch
########################################
section "[7/7] Fastfetch"

install_fastfetch_pkg() {
    case "$PKG" in
        apt)    sudo apt install -y fastfetch ;;
        pacman) sudo pacman -S --noconfirm fastfetch ;;
        dnf)    sudo dnf install -y fastfetch ;;
        zypper) sudo zypper install -y fastfetch ;;
    esac
}

if is_installed fastfetch; then
    info "Fastfetch ya está instalado ($(fastfetch --version 2>/dev/null | head -1)). Saltando instalación."
else
    confirm "¿Instalar Fastfetch?" && {
        if install_fastfetch_pkg; then
            ok "Fastfetch instalado vía gestor de paquetes."
        elif [ "$PKG" = "apt" ]; then
            warn "apt install fastfetch falló. Intentando PPA..."
            if sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch \
               && sudo apt update -y \
               && sudo apt install -y fastfetch; then
                ok "Fastfetch instalado vía PPA."
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
                    ok "Fastfetch instalado desde GitHub .deb."
                else
                    fail "Fastfetch no pudo instalarse por ningún método."
                fi
            fi
        fi
    }
fi

# Configuración de Fastfetch
FASTFETCH_DIR="$HOME/.config/fastfetch"
ASSETS_DIR="$FASTFETCH_DIR/assets"

confirm "¿Descargar config y assets de Fastfetch (~/.config/fastfetch/)?" && {
    mkdir -p "$ASSETS_DIR"

    if [ -f "$FASTFETCH_DIR/sample_2.jsonc" ]; then
        info "Fastfetch config ya existe en $FASTFETCH_DIR/sample_2.jsonc."
        confirm "¿Sobreescribir la config de Fastfetch?" && _dl_ff_conf=1 || _dl_ff_conf=0
    else
        _dl_ff_conf=1
    fi

    if [ "$_dl_ff_conf" -eq 1 ]; then
        curl -fsSL \
            "https://raw.githubusercontent.com/itsfoss/text-script-files/refs/heads/master/config/fastfetch/sample_2.jsonc" \
            -o "$FASTFETCH_DIR/sample_2.jsonc" \
            && ok "Fastfetch config descargada." \
            || warn "Fastfetch config download failed."

        curl -fsSL \
            "https://raw.githubusercontent.com/itsfoss/text-script-files/refs/heads/master/config/fastfetch/assets/jedi.png" \
            -o "$ASSETS_DIR/jedi.png" \
            && ok "Fastfetch image descargada." \
            || warn "Fastfetch image download failed."
    fi
}

confirm "¿Agregar fastfetch al inicio del ~/.zshrc?" && {
    grep -qF "fastfetch -c ~/.config/fastfetch/sample_2.jsonc" "$HOME/.zshrc" \
        || echo 'fastfetch -c ~/.config/fastfetch/sample_2.jsonc' >> "$HOME/.zshrc"
    ok "Fastfetch configurado en .zshrc."
}

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
