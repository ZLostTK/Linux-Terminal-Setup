#!/bin/bash

# Colores para la salida
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Iniciando instalación del entorno para Alexander Martínez...${NC}\n"

# Lista de paquetes oficiales (pacman)
# Incluye: Base, Lenguajes, DB, Servidores y Herramientas
packages=(
    "base-devel" "git" "wget" "curl"                # Esenciales
    "python" "python-pip" "python-flask" "pyqt5-common" # Python Stack
    "nodejs" "npm" "typescript"                     # JS/TS Stack
    "php" "php-apache" "apache"                     # PHP Stack
    "mariadb"                                       # SQL (MySQL)
    "bash-completion" "powershell-bin"              # Shells
    "code"                                          # VS Code (OSS version)
    "obs-studio" "yara"                             # Software adicional
    "tailwind-config-viewer"                        # Tailwind utils
)

# Función para verificar e instalar
install_pacman() {
    for pkg in "${packages[@]}"; do
        if pacman -Qi "$pkg" &> /dev/null; then
            echo -e "${GREEN}[✔] $pkg ya está instalado.${NC}"
        else
            echo -e "${BLUE}[+] Instalando $pkg...${NC}"
            sudo pacman -S --noconfirm "$pkg"
        fi
    done
}

# Ejecutar instalación principal
install_pacman

# Verificación de Frameworks vía NPM (Globales)
echo -e "\n${BLUE}Verificando librerías globales de Node.js...${NC}"
node_libs=("react" "bootstrap" "tailwindcss")

for lib in "${node_libs[@]}"; do
    if npm list -g "$lib" &> /dev/null; then
        echo -e "${GREEN}[✔] $lib (npm) ya está presente.${NC}"
    else
        echo -e "${BLUE}[+] Instalando $lib globalmente...${NC}"
        sudo npm install -g "$lib"
    fi
done

# Configuración básica de MariaDB si es nueva
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo -e "${BLUE}[!] Inicializando base de datos MariaDB...${NC}"
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
    sudo systemctl enable --now mariadb
fi

echo -e "\n${GREEN}¡Todo listo! Tu entorno de desarrollo está configurado.${NC}"
