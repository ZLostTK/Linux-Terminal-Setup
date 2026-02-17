# Personalización de Terminal Linux

Este repositorio contiene un script que automatiza la instalación y configuración de una terminal personalizada en Linux, con:

- Fuentes *Nerd Fonts*
- ZSH + Plugins
- Prompt **Starship**
- Gestor de historial **Atuin**
- Terminal **Kitty**
- Sistema de información **Fastfetch**

El script detecta automáticamente la distribución y utiliza el gestor de paquetes adecuado (apt, dnf, pacman, zypper).

---

## Instalación

Puedes ejecutar este script de dos formas:

---

### Opción 1 — Ejecutar directamente con `curl` + `bash`

> Descarga y ejecuta el script en un solo comando:

```bash
curl -fsSL https://raw.githubusercontent.com/ZLostTK/Linux-Terminal-Setup/refs/heads/main/Setup_Terminal.sh | bash
````

---

### Opción 2 — Descargar y luego ejecutar

Si prefieres descargar primero el archivo y revisarlo antes de ejecutarlo:

```bash
curl -fsSL https://raw.githubusercontent.com/ZLostTK/Linux-Terminal-Setup/refs/heads/main/Setup_Terminal.sh -o setup_terminal.sh
chmod +x setup_terminal.sh
./setup_terminal.sh
```

---

## ¿Qué hace este script?

1. **Detecta la distribución Linux** y el gestor de paquetes (apt, dnf, pacman, zypper).
2. **Instala utilidades básicas**: `curl`, `wget`, `unzip`, `git`.
3. **Descarga e instala fuentes Nerd Fonts** para mejorar apariencia del prompt.
4. **Instala y configura ZSH** junto con plugins útiles (autocompletado, resalte de sintaxis).
5. **Instala Starship Prompt** para una experiencia moderna y personalizable.
6. **Instala Atuin** para un historial inteligente de comandos.
7. **Instala Kitty Terminal** y crea una configuración base.
8. **Instala Fastfetch** para mostrar información del sistema al iniciar la terminal.

---

## Cambiar el Shell por defecto

Después de ejecutar el script, para que ZSH se convierta en tu shell predeterminado:

```bash
chsh -s "$(which zsh)"
```

Luego cierra y vuelve a abrir tu terminal.

---

## Requisitos

* Conexión a Internet
* Permisos para instalar paquetes (`sudo`)
* Sistema Linux con alguno de estos gestores: `apt`, `dnf`, `pacman` o `zypper`


## Licencia

Este proyecto está bajo la licencia MIT — siéntete libre de usarlo, modificarlo o adaptarlo.

---

## Contribuciones

¡Las contribuciones son bienvenidas!
Puedes abrir issues o pull requests para mejorar compatibilidad, añadir nuevas opciones o corregir errores.

---

Gracias por usar este script 
<img width="936" height="396" alt="image" src="https://github.com/user-attachments/assets/fe21be10-8e4b-4cdd-93b2-bab88aa941aa" />
