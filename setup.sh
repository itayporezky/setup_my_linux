#!/usr/bin/env bash

set -uo pipefail

GO_VERSION="1.24.3"

ERRORS=()

log_step() { echo; echo "===> $*"; }
log_info()  { echo "     $*"; }
log_ok()    { echo "     [OK] $1"; }
log_fail()  { echo "     [FAIL] $1" >&2; }

record_error() {
    ERRORS+=("$1")
    log_fail "$1"
}

run_step() {
    local name="$1"
    shift
    log_step "$name"
    if "$@"; then
        log_ok "$name"
    else
        record_error "$name"
    fi
}

# ── Guard: must not run as root ──────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Run this script as a regular user, not root." >&2
    exit 1
fi

# ── curl + git ───────────────────────────────────────────────────────────────
install_curl_git() {
    sudo apt-get update -qq
    sudo apt-get install -y curl git
}
run_step "Install curl and git" install_curl_git

# ── Docker ───────────────────────────────────────────────────────────────────
install_docker() {
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
    sudo usermod -aG docker "$USER"
    log_info "Docker installed. Re-login (or run 'newgrp docker') for group to take effect."
}
run_step "Install Docker" install_docker

# ── NVM ──────────────────────────────────────────────────────────────────────
install_nvm() {
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
}
run_step "Install NVM" install_nvm

# ── Node.js 24 via NVM ───────────────────────────────────────────────────────
install_node() {
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if ! command -v nvm &>/dev/null; then
        echo "nvm not found after install — cannot install Node" >&2
        return 1
    fi
    nvm install 24
}
run_step "Install Node.js 24 (via NVM)" install_node

# ── Go ───────────────────────────────────────────────────────────────────────
install_go() {
    local tarball="go${GO_VERSION}.linux-amd64.tar.gz"
    local url="https://go.dev/dl/${tarball}"

    curl -fsSL "$url" -o "/tmp/${tarball}"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "/tmp/${tarball}"
    rm -f "/tmp/${tarball}"

    # Add to PATH for this session
    export PATH="$PATH:/usr/local/go/bin"

    # Persist to .profile (skip if already present)
    if ! grep -qF '/usr/local/go/bin' "$HOME/.profile" 2>/dev/null; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.profile"
    fi

    go version
}
run_step "Install Go ${GO_VERSION}" install_go

# ── uv ───────────────────────────────────────────────────────────────────────
install_uv() {
    curl -LsSf https://astral.sh/uv/install.sh | sh
}
run_step "Install uv" install_uv

# ── Spotify ──────────────────────────────────────────────────────────────────
install_spotify() {
    sudo snap install spotify
}
run_step "Install Spotify (snap)" install_spotify

# ── Claude Code ──────────────────────────────────────────────────────────────
install_claude() {
    curl -fsSL https://claude.ai/install.sh | bash
}
run_step "Install Claude Code" install_claude

# ── Summary ─────────────────────────────────────────────────────────────────
echo
echo "════════════════════════════════════════"
if [ "${#ERRORS[@]}" -eq 0 ]; then
    echo "  All steps completed successfully!"
else
    echo "  Completed with ${#ERRORS[@]} error(s):"
    for err in "${ERRORS[@]}"; do
        echo "    - $err"
    done
    echo
    echo "  Fix the errors above and re-run the failed steps."
    exit 1
fi
echo "════════════════════════════════════════"
echo
echo "Next steps:"
echo "  • Run 'newgrp docker' or log out/in to use Docker without sudo"
echo "  • Run 'source ~/.profile' or open a new terminal for Go in PATH"
