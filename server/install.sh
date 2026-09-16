#!/usr/bin/env bash
# Installation des dependances Python sur DirectAdmin, sans terminal interactif.
#
# A executer via une tache cron ponctuelle (panneau DirectAdmin > Cron Jobs)
# ou depuis le champ de commande du gestionnaire de fichiers :
#
#   bash /chemin/vers/server/install.sh
#
# Le script trouve seul le virtualenv cree par "Setup Python App" (il n'a pas
# besoin d'etre pre-active), met pip/setuptools/wheel a jour, puis installe
# requirements.txt en privilegiant les paquets binaires (--prefer-binary) pour
# eviter les echecs de compilation native (Rust/gcc absents sur l'hebergement
# mutualise). Tout est journalise dans install.log, lisible depuis le
# gestionnaire de fichiers DirectAdmin meme si le terminal est indisponible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/install.log"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$LOG_FILE"
}

: > "$LOG_FILE"
log "== Installation MajiChrono API =="
log "Repertoire : $SCRIPT_DIR"

# 1. Localiser le Python du virtualenv de l'application.
#    - VENV_PYTHON permet de forcer le chemin si l'auto-detection echoue.
#    - $VIRTUAL_ENV est defini si le script est lance apres `source .../activate`.
#    - Sinon on cherche le virtualenv que DirectAdmin cree sous
#      ~/virtualenv/<app>/<version>/bin/python (ou site-packages/../bin/python).
PYTHON_BIN="${VENV_PYTHON:-}"

if [ -z "$PYTHON_BIN" ] && [ -n "${VIRTUAL_ENV:-}" ] && [ -x "$VIRTUAL_ENV/bin/python" ]; then
    PYTHON_BIN="$VIRTUAL_ENV/bin/python"
fi

if [ -z "$PYTHON_BIN" ]; then
    CANDIDATE="$(find "$HOME/virtualenv" -maxdepth 4 -type f -name python 2>/dev/null | head -n 1)"
    if [ -n "$CANDIDATE" ]; then
        PYTHON_BIN="$CANDIDATE"
    fi
fi

if [ -z "$PYTHON_BIN" ] || [ ! -x "$PYTHON_BIN" ]; then
    log "ERREUR : impossible de localiser le Python du virtualenv DirectAdmin."
    log "Definissez VENV_PYTHON=/chemin/vers/bin/python avant d'appeler ce script,"
    log "ou activez le virtualenv puis relancez : source <venv>/bin/activate && bash install.sh"
    exit 1
fi

log "Python utilise : $PYTHON_BIN ($("$PYTHON_BIN" --version 2>&1))"

# 2. Repertoire de cache pip inscriptible (le HOME par defaut peut etre en
#    lecture seule ou trop restreint sur certains hebergements mutualises).
export PIP_CACHE_DIR="$SCRIPT_DIR/.pip-cache"
mkdir -p "$PIP_CACHE_DIR"

PIP=("$PYTHON_BIN" -m pip)

run_step() {
    local description="$1"
    shift
    log "-> $description"
    if ! "$@" >>"$LOG_FILE" 2>&1; then
        log "ERREUR pendant : $description (voir $LOG_FILE)"
        exit 1
    fi
}

# 3. pip/setuptools/wheel obsoletes sont la cause la plus frequente d'echecs
#    de resolution ou de compilation de roues sur ces hebergements.
run_step "Mise a jour de pip/setuptools/wheel" \
    "${PIP[@]}" install --upgrade pip setuptools wheel

# 4. Installation des dependances de production. --prefer-binary evite de
#    tenter une compilation source quand une roue precompilee existe deja
#    pour une version proche ; --no-input empeche tout blocage en attente
#    d'une saisie interactive absente en cron.
run_step "Installation de requirements.txt" \
    "${PIP[@]}" install --no-input --prefer-binary -r "$SCRIPT_DIR/requirements.txt"

log "OK : installation terminee sans erreur."
log "Redemarrez l'application Passenger depuis le panneau DirectAdmin."
