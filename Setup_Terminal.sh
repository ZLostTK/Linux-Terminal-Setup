#!/usr/bin/env bash
# set -e ELIMINADO — el script continúa aunque un paso falle

# Colores para mensajes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

echo "==== Terminal Customization Script ===="

########################################
# Detectar gestor de paquetes
########################################
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
    fail "Unsupported package manager. Exit."
    exit 1
fi

echo "Detected package manager: $PKG"
$UPDATE || warn "Package list update failed, continuing anyway..."

########################################
# 1. Instalar utilidades básicas
########################################
echo ""
echo ">>> [1/7] Installing base tools (curl, wget, unzip, git)..."
$INSTALL curl wget unzip git && ok "Base tools installed." || fail "Some base tools failed to install."

########################################
# 2. Instalar fuentes Nerd Fonts
########################################
echo ""
echo ">>> [2/7] Installing Nerd Fonts..."
FONT_DIR="$HOME/.local/share/fonts/nerd-fonts"
mkdir -p "$FONT_DIR"

NERD_FONTS=(
  "JetBrainsMono"
  "FiraCode"
  "CaskaydiaCove"
)

for font in "${NERD_FONTS[@]}"; do
    URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/${font}.zip"
    TMPZIP="/tmp/${font}.zip"
    echo "  Downloading $font Nerd Font..."
    if wget -q --tries=3 --timeout=30 -O "$TMPZIP" "$URL"; then
        # unzip puede retornar código 1 en warnings; || true evita que pare el script
        unzip -oq "$TMPZIP" -d "$FONT_DIR" || true
        rm -f "$TMPZIP"
        ok "$font downloaded and extracted."
    else
        fail "Failed to download $font. Skipping."
        rm -f "$TMPZIP"
    fi
done

echo "Rebuilding font cache..."
fc-cache -f -v >/dev/null 2>&1 && ok "Font cache rebuilt." || warn "fc-cache failed."

########################################
# 3. Instalar ZSH + plugins
########################################
echo ""
echo ">>> [3/7] Installing ZSH + plugins..."
$INSTALL zsh && ok "ZSH installed." || fail "ZSH install failed."

case "$PKG" in
    apt)
        $INSTALL zsh-autosuggestions zsh-syntax-highlighting \
            && ok "ZSH plugins installed." || warn "ZSH plugins install failed."
        ;;
    pacman)
        $INSTALL zsh-autosuggestions zsh-syntax-highlighting \
            && ok "ZSH plugins installed." || warn "ZSH plugins install failed."
        ;;
    dnf|zypper)
        $INSTALL zsh-autosuggestions zsh-syntax-highlighting \
            && ok "ZSH plugins installed." || warn "ZSH plugins not available in repos, skipping."
        ;;
esac

# zsh-autocomplete (clonar si no existe ya)
if [ ! -d "$HOME/.zsh-autocomplete" ]; then
    git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git ~/.zsh-autocomplete \
        && ok "zsh-autocomplete cloned." || warn "zsh-autocomplete clone failed."
else
    ok "zsh-autocomplete already present, skipping clone."
fi

# Configuración ~/.zshrc
touch ~/.zshrc

grep -qxF 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' ~/.zshrc \
    || echo 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> ~/.zshrc

grep -qxF 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' ~/.zshrc \
    || echo 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> ~/.zshrc

grep -qxF 'source ~/.zsh-autocomplete/zsh-autocomplete.plugin.zsh' ~/.zshrc \
    || echo 'source ~/.zsh-autocomplete/zsh-autocomplete.plugin.zsh' >> ~/.zshrc

ok ".zshrc updated with ZSH plugin sources."

########################################
# 4. Instalar Starship
########################################
echo ""
echo ">>> [4/7] Installing Starship prompt..."
if curl -sS https://starship.rs/install.sh | sh -s -- --yes; then
    ok "Starship installed."
else
    warn "Starship installation failed, skipping."
fi

grep -qxF 'eval "$(starship init zsh)"' ~/.zshrc \
    || echo 'eval "$(starship init zsh)"' >> ~/.zshrc

########################################
# 5. Instalar Atuin
########################################
echo ""
echo ">>> [5/7] Installing Atuin (shell history)..."
if curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --yes; then
    ok "Atuin installed."
else
    warn "Atuin installation failed, skipping."
fi

grep -qxF 'eval "$(atuin init zsh)"' ~/.zshrc \
    || echo 'eval "$(atuin init zsh)"' >> ~/.zshrc

########################################
# 6. Instalar Kitty Terminal
########################################
echo ""
echo ">>> [6/7] Installing Kitty terminal emulator..."
$INSTALL kitty && ok "Kitty installed." || warn "Kitty install failed."

KITTY_CONF="$HOME/.config/kitty/kitty.conf"
mkdir -p "$(dirname "$KITTY_CONF")"

# Obtener ruta de zsh de forma segura
ZSH_PATH="$(command -v zsh 2>/dev/null || echo /bin/zsh)"

cat > "$KITTY_CONF" << EOF
font_family      JetBrainsMono Nerd Font
font_size        14.0
cursor_trail     100
hide_window_decorations yes
tab_bar_style    powerline
shell            $ZSH_PATH
EOF

ok "Kitty config written to $KITTY_CONF"

########################################
# 7. Instalar y configurar Fastfetch
########################################
echo ""
echo ">>> [7/7] Installing Fastfetch..."

case "$PKG" in
    apt)    sudo apt install -y fastfetch ;;
    pacman) sudo pacman -S --noconfirm fastfetch ;;
    dnf)    sudo dnf install -y fastfetch ;;
    zypper) sudo zypper install -y fastfetch ;;
esac && ok "Fastfetch installed." || warn "Fastfetch install failed."

FASTFETCH_DIR="$HOME/.config/fastfetch"
ASSETS_DIR="$FASTFETCH_DIR/assets"
mkdir -p "$ASSETS_DIR"

echo "Downloading Fastfetch config..."
curl -fsSL \
    "https://raw.githubusercontent.com/itsfoss/text-script-files/refs/heads/master/config/fastfetch/sample_2.jsonc" \
    -o "$FASTFETCH_DIR/sample_2.jsonc" \
    && ok "Fastfetch config downloaded." || warn "Fastfetch config download failed."

echo "Downloading Fastfetch image..."
curl -fsSL \
    "https://raw.githubusercontent.com/itsfoss/text-script-files/refs/heads/master/config/fastfetch/assets/jedi.png" \
    -o "$ASSETS_DIR/jedi.png" \
    && ok "Fastfetch image downloaded." || warn "Fastfetch image download failed."

grep -qF "fastfetch -c ~/.config/fastfetch/sample_2.jsonc" "$HOME/.zshrc" \
    || echo 'fastfetch -c ~/.config/fastfetch/sample_2.jsonc' >> "$HOME/.zshrc"

ok "Fastfetch configured."

########################################
# Final
########################################
echo ""
echo "========================================"
echo "          ==== Setup Completed ===="
echo "========================================"
echo ""
echo "Pasos finales:"
echo "  1) Cambia tu shell por defecto:"
echo "     chsh -s $(command -v zsh 2>/dev/null || echo /bin/zsh)"
echo "  2) Cierra y vuelve a abrir la terminal."
echo ""
echo "Abre una nueva terminal para ver todos los cambios."
