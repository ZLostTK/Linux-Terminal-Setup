#!/usr/bin/env bash
set -e

echo "==== Terminal Customization Script ===="

# Detectar gestor de paquetes
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
    echo "Unsupported package manager. Exit."
    exit 1
fi

echo "Detected package manager: $PKG"
$UPDATE

########################################
# 1. Instalar utilidades básicas
########################################
echo "Installing base tools (curl, wget, unzip, git)..."
$INSTALL curl wget unzip git

########################################
# 2. Instalar fuentes Nerd Fonts
########################################
echo "Installing Nerd Fonts..."
FONT_DIR="$HOME/.local/share/fonts/nerd-fonts"
mkdir -p "$FONT_DIR"

# Lista de fuentes comunes; ajusta según preferencia
NERD_FONTS=(
  "JetBrainsMono"
  "FiraCode"
  "CaskaydiaCove"
)

for font in "${NERD_FONTS[@]}"; do
    URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/${font}.zip"
    TMPZIP="/tmp/${font}.zip"
    echo "Downloading $font Nerd Font..."
    wget -q -O "$TMPZIP" "$URL"
    unzip -o "$TMPZIP" -d "$FONT_DIR"
    rm -f "$TMPZIP"
done

echo "Rebuilding font cache..."
fc-cache -f -v

########################################
# 3. Instalar ZSH + plugins
########################################
echo "Installing ZSH + plugins..."
$INSTALL zsh

# Plugins
case "$PKG" in
    apt)
        $INSTALL zsh-autosuggestions zsh-syntax-highlighting
        ;;
    pacman)
        $INSTALL zsh-plugins-autosuggestions zsh-plugins-syntax-highlighting
        ;;
    dnf|zypper)
        $INSTALL zsh-autosuggestions zsh-syntax-highlighting || true
        ;;
esac

# zsh-autocomplete
git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git ~/.zsh-autocomplete

# Configuración de ~/.zshrc
touch ~/.zshrc

# Asegurar que las fuentes de plugins se carguen
grep -qxF 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' ~/.zshrc \
    || echo 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> ~/.zshrc

grep -qxF 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' ~/.zshrc \
    || echo 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> ~/.zshrc

grep -qxF 'source ~/.zsh-autocomplete/zsh-autocomplete.plugin.zsh' ~/.zshrc \
    || echo 'source ~/.zsh-autocomplete/zsh-autocomplete.plugin.zsh' >> ~/.zshrc

########################################
# 4. Instalar Starship (prompt moderno) ⭐
########################################
echo "Installing Starship prompt..."
curl -sS https://starship.rs/install.sh | sh -s -- --yes
# Integrar Starship en ZSH
grep -qxF 'eval "$(starship init zsh)"' ~/.zshrc || echo 'eval "$(starship init zsh)"' >> ~/.zshrc

########################################
# 5. Instalar Atuin (historial mejorado)
########################################
echo "Installing Atuin..."
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --yes
grep -qxF 'eval "$(atuin init zsh)"' ~/.zshrc || echo 'eval "$(atuin init zsh)"' >> ~/.zshrc

########################################
# 6. Instalar Kitty Terminal
########################################
echo "Installing Kitty terminal emulator..."
case "$PKG" in
    apt|dnf|zypper)
        $INSTALL kitty
        ;;
    pacman)
        $INSTALL kitty
        ;;
esac

# Crear configuración base para Kitty
KITTY_CONF="$HOME/.config/kitty/kitty.conf"
mkdir -p "$(dirname "$KITTY_CONF")"
cat > "$KITTY_CONF" << EOF
font_family      JetBrainsMono Nerd Font
font_size        14.0
cursor_trail     100
hide_window_decorations yes
tab_bar_style    powerline
shell            $(which zsh)
EOF

########################################
# 7. Instalar y configurar Fastfetch
########################################
echo "Installing Fastfetch..."

case "$PKG" in
    apt)
        sudo apt install -y fastfetch
        ;;
    pacman)
        sudo pacman -S --noconfirm fastfetch
        ;;
    dnf)
        sudo dnf install -y fastfetch
        ;;
    zypper)
        sudo zypper install -y fastfetch
        ;;
esac

echo "Configuring Fastfetch..."

FASTFETCH_DIR="$HOME/.config/fastfetch"
ASSETS_DIR="$FASTFETCH_DIR/assets"

mkdir -p "$ASSETS_DIR"

# Descargar configuración
curl -fsSL \
https://raw.githubusercontent.com/itsfoss/text-script-files/refs/heads/master/config/fastfetch/sample_2.jsonc \
-o "$FASTFETCH_DIR/sample_2.jsonc"

# Descargar imagen
curl -fsSL \
https://raw.githubusercontent.com/itsfoss/text-script-files/refs/heads/master/config/fastfetch/assets/jedi.png \
-o "$ASSETS_DIR/jedi.png"

echo "Fastfetch config and image downloaded."

# Añadir ejecución personalizada al .zshrc (evitar duplicados)
if ! grep -q "fastfetch -c ~/.config/fastfetch/sample_2.jsonc" "$HOME/.zshrc"; then
    echo 'fastfetch -c ~/.config/fastfetch/sample_2.jsonc' >> "$HOME/.zshrc"
fi

echo "Fastfetch configured successfully."

########################################
# 8. Final
########################################
echo "==== Setup Completed ===="
echo "Before you start a new terminal session:"
echo "  1) Change your default shell: chsh -s $(which zsh)"
echo "  2) Restart terminal"
echo ""
echo "Reopen the terminal to see changes in effect."
