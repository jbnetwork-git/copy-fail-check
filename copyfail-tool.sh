#!/usr/bin/env bash
set -Eeuo pipefail

TOOL_NAME="Novanet - CopyFail Herramienta Rápida"
TOOL_VERSION="0.2.0"
MITIGATION_FILE="/etc/modprobe.d/disable-algif.conf"
MITIGATION_LINE='install algif_aead /bin/false'
PATCH_COMMIT="a664bf3d603d"

ASCII_LOGO=$(cat <<'EOF'
					  ████                                
                                          ███████████                     
                                              ███████████                 
                                                     ███████               
                                          ███████        █████            
                                          ████████████     █████          
                                                  ███████    ████         
                                          █████      █████     ███        
                                            ██████     █████    ███       
                                                ████     ████    ███       
                 ███████████████████████████      ████    ████    ███      
             ███████████████████████████████████    ███    ████             
           ███████████████████████████████████████   ███                   
          █████████████████████████████████████████                        
          ██████████                     ██████████                         
         ██████████                       ██████████                        
         █████████                         █████████                       
         █████████                         █████████                       
         █████████                         █████████                       
         █████████                         █████████                       
         █████████                         █████████                       
         █████████                         █████████                       
         █████████                         █████████                       
         █████████                         █████████                       
         █████████                         █████████                       
         █████████                         █████████
EOF
)

red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }
blue() { printf '\033[34m%s\033[0m\n' "$1"; }
bold() { printf '\033[1m%s\033[0m\n' "$1"; }
brand() { printf '\033[38;2;31;79;143m%s\033[0m\n' "$1"; }

print_header() {
  clear 2>/dev/null || true
  if [[ -n "$ASCII_LOGO" ]]; then
    while IFS= read -r line; do
      brand "$line"
    done <<< "$ASCII_LOGO"
    printf '\n'
  fi
  printf '\033[38;2;31;79;143m\033[1m%s\033[0m\n' "$TOOL_NAME v$TOOL_VERSION"
  printf '[32;1mDev: Joan Bou - JB Network[0m\n"'
  printf 'CVE-2026-31431 helper de revisión rápida y mitigación opcional\n\n'
}

require_linux() {
  if [[ "${OSTYPE:-}" != linux* ]]; then
    red "Esta herramienta está pensada solo para hosts Linux."
    exit 1
  fi
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    red "Esta acción requiere root. Ejecútala con sudo."
    return 1
  fi
}

os_summary() {
  local pretty="Linux desconocido"
  if [[ -r /etc/os-release ]]; then
    pretty=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
  fi
  printf '%s\n' "$pretty"
}

os_family() {
  local id_like=""
  local id=""
  if [[ -r /etc/os-release ]]; then
    id=$(grep '^ID=' /etc/os-release | cut -d= -f2- | tr -d '"')
    id_like=$(grep '^ID_LIKE=' /etc/os-release | cut -d= -f2- | tr -d '"')
  fi

  case " $id $id_like " in
    *" debian "*|*" ubuntu "*) printf 'debian-family\n' ;;
    *" rhel "*|*" fedora "*|*" centos "*|*" rocky "*|*" alma "*|*" almalinux "*) printf 'rhel-family\n' ;;
    *) printf 'generic-linux\n' ;;
  esac
}

package_manager_hint() {
  case "$(os_family)" in
    debian-family)
      printf 'Sugerencia de parcheo: apt update && apt upgrade\n'
      ;;
    rhel-family)
      printf 'Sugerencia de parcheo: dnf upgrade --refresh\n'
      ;;
    *)
      printf 'Sugerencia de parcheo: usa el gestor de paquetes de tu distro para aplicar actualizaciones de kernel\n'
      ;;
  esac
}

kernel_summary() {
  uname -r
}

module_loaded() {
  lsmod | awk '{print $1}' | grep -qx 'algif_aead'
}

module_available() {
  if command -v modinfo >/dev/null 2>&1; then
    modinfo algif_aead >/dev/null 2>&1
  else
    return 1
  fi
}

mitigation_configured() {
  [[ -f "$MITIGATION_FILE" ]] && grep -Fxq "$MITIGATION_LINE" "$MITIGATION_FILE"
}

seccomp_hint() {
  printf '%s\n' "Para contenedores o sandboxes no confiables, considera también bloquear el AF_ALG vía seccomp."
}

status_report() {
  print_header
  bold "Sistema"
  printf 'SO: %s\n' "$(os_summary)"
  printf 'Familia: %s\n' "$(os_family)"
  printf 'Kernel: %s\n' "$(kernel_summary)"
  printf 'Referencia de parche: %s\n\n' "$PATCH_COMMIT"

  bold "Estado de mitigación"
  if module_available; then
    green "El módulo algif_aead está presente en este sistema."
  else
    yellow "No se encontró el módulo algif_aead con modinfo. Puede estar integrado o ausente."
  fi

  if module_loaded; then
    red "algif_aead está cargado actualmente."
  else
    green "algif_aead no está cargado actualmente."
  fi

  if mitigation_configured; then
    green "Archivo de mitigación presente: $MITIGATION_FILE"
  else
    yellow "El archivo de mitigación no está presente."
  fi

  printf '\n'
  bold "Evaluación"
  yellow "Esta herramienta no puede confirmar al 100% si el sistema está parchado o vulnerable solo por versión, porque muchas distros hacen backports."
  if module_loaded || module_available; then
    yellow "Si este host todavía no está parchado a nivel kernel, vale la pena considerar la mitigación temporal."
  else
    green "La exposición parece menor si algif_aead realmente no está disponible, pero igual importa parchear."
  fi

  printf '\n'
  bold "Sugerencia de parcheo"
  package_manager_hint
  printf '\n'
  seccomp_hint
  printf '\nPresiona Enter para volver al menú... '
  read -r _
}

apply_mitigation() {
  print_header
  bold "Aplicar mitigación temporal"
  printf 'Esto hará:\n'
  printf ' - escribir %s\n' "$MITIGATION_FILE"
  printf ' - agregar: %s\n' "$MITIGATION_LINE"
  printf ' - intentar: rmmod algif_aead\n\n'

  require_root || { printf '\nPresiona Enter para volver al menú... '; read -r _; return; }

  read -r -p '¿Continuar? [y/N]: ' answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    yellow "Cancelado."
    printf '\nPresiona Enter para volver al menú... '
    read -r _
    return
  fi

  mkdir -p /etc/modprobe.d
  printf '%s\n' "$MITIGATION_LINE" > "$MITIGATION_FILE"
  chmod 0644 "$MITIGATION_FILE"

  if module_loaded; then
    if rmmod algif_aead 2>/tmp/copyfail-rmmod.err; then
      green "algif_aead se descargó correctamente."
    else
      yellow "No se pudo descargar algif_aead en este momento. Puede estar en uso."
      printf 'Salida de rmmod: %s\n' "$(tr '\n' ' ' </tmp/copyfail-rmmod.err)"
      yellow "Puede requerirse reinicio después de crear el archivo de bloqueo."
    fi
    rm -f /tmp/copyfail-rmmod.err
  else
    green "algif_aead no estaba cargado. Se creó el archivo de bloqueo."
  fi

  printf '\n'
  green "Mitigación temporal aplicada."
  yellow "Aun así hay que parchear el kernel. Esto solo es una contención temporal."
  printf '\nPresiona Enter para volver al menú... '
  read -r _
}

remove_mitigation() {
  print_header
  bold "Quitar mitigación temporal"
  printf 'Esto quitará %s si está presente.\n\n' "$MITIGATION_FILE"

  require_root || { printf '\nPresiona Enter para volver al menú... '; read -r _; return; }

  read -r -p '¿Continuar? [y/N]: ' answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    yellow "Cancelado."
    printf '\nPresiona Enter para volver al menú... '
    read -r _
    return
  fi

  if [[ -f "$MITIGATION_FILE" ]]; then
    rm -f "$MITIGATION_FILE"
    green "Se eliminó el archivo de mitigación."
  else
    yellow "El archivo de mitigación no estaba presente."
  fi

  yellow "Si quieres volver a tener el módulo disponible de inmediato, puede que debas cargarlo manualmente o reiniciar."
  printf '\nPresiona Enter para volver al menú... '
  read -r _
}

show_about() {
  print_header
  bold "Acerca de"
  printf '\n'
  printf '[32;1m "Desarrollado por: Joan Bou - JB Network - Novanet[0m"'
  printf '\n'
  printf 'Este helper sirve para una revisión rápida de Copy Fail (CVE-2026-31431).\n'
  printf 'Se enfoca en la mitigación temporal alrededor de algif_aead y no reemplaza el parcheo del kernel.\n\n'
  printf 'Familias objetivo actuales:\n'
  printf ' - Debian / Ubuntu\n'
  printf ' - AlmaLinux / Rocky / RHEL-like\n\n'
  printf 'Uso sugerido:\n'
  printf ' 1. Ejecutar revisión de estado\n'
  printf ' 2. Aplicar mitigación temporal si hace falta\n'
  printf ' 3. Parchear kernel con las actualizaciones de la distro\n\n'
  printf 'Presiona Enter para volver al menú... '
  read -r _
}

main_menu() {
  require_linux
  while true; do
    print_header
    printf '1) Revisar estado\n'
    printf '2) Aplicar mitigación temporal\n'
    printf '3) Quitar mitigación temporal\n'
    printf '4) Acerca de\n'
    printf '5) Salir\n\n'
    read -r -p 'Selecciona una opción: ' choice
    case "$choice" in
      1) status_report ;;
      2) apply_mitigation ;;
      3) remove_mitigation ;;
      4) show_about ;;
      5) exit 0 ;;
      *) yellow "Opción no válida."; sleep 1 ;;
    esac
  done
}

main_menu
