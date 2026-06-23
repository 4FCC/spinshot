#!/usr/bin/env bash
# =============================================================================
# install_godot.sh — Instala Godot 4.6 (headless) para validar el proyecto
# =============================================================================
# Descarga el binario oficial de Godot 4.6 desde GitHub y lo deja en
# ~/.local/bin/godot. Es idempotente: si ya está instalado, no hace nada.
#
# Uso:
#   bash tools/install_godot.sh
#   godot --version
#
# Validar el proyecto después de instalar:
#   godot --headless --path . --import        # importa recursos
#   godot --headless --path . --quit-after 240 # corre el juego unos frames
set -euo pipefail

GODOT_VERSION="4.6-stable"
ZIP_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${ZIP_NAME}.zip"
DEST_DIR="${HOME}/.local/bin"
DEST="${DEST_DIR}/godot"

if [ -x "${DEST}" ] && "${DEST}" --version 2>/dev/null | grep -q "4.6"; then
	echo "Godot ya instalado: $(${DEST} --version)"
	exit 0
fi

mkdir -p "${DEST_DIR}"
tmp="$(mktemp -d)"
echo "Descargando Godot ${GODOT_VERSION}..."
curl -fsSL -o "${tmp}/godot.zip" "${URL}"
echo "Extrayendo..."
unzip -oq "${tmp}/godot.zip" -d "${tmp}"
mv "${tmp}/${ZIP_NAME}" "${DEST}"
chmod +x "${DEST}"
rm -rf "${tmp}"

echo "Instalado: $(${DEST} --version)"
case ":${PATH}:" in
	*":${DEST_DIR}:"*) ;;
	*) echo "Nota: añade ${DEST_DIR} al PATH  ->  export PATH=\"${DEST_DIR}:\$PATH\"" ;;
esac
