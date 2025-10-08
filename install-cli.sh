#!/usr/bin/env bash
set -euo pipefail

# HDP Cairo CLI installer
# - Checks for Rust and uv (prompts with installation instructions if missing)
# - Clones or updates the repo at $HOME/.local/share/hdp
# - Initializes submodules, sets up Python env with uv, activates venv
# - Builds the hdp-cli binary and symlinks it into $HOME/.local/bin

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Icons
CHECK="✓"
CROSS="✗"
ARROW="➤"
INFO="ℹ"
WARNING="⚠"
ERROR="✗"
SUCCESS="✓"

REPO_URL="https://github.com/HerodotusDev/hdp-cairo"
REPO_DIR="$HOME/.local/share/hdp"
BIN_NAME="hdp-cli"
TARGET_BIN="$REPO_DIR/target/release/$BIN_NAME"
LOCAL_BIN_DIR="$HOME/.local/bin"
SYMLINK_PATH="$LOCAL_BIN_DIR/$BIN_NAME"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

prompt_install() {
  local name="$1"
  local install_hint="$2"
  echo
  echo -e "${RED}${ERROR}${NC} ${BOLD}$name${NC} is not installed."
  echo
  echo -e "${YELLOW}${ARROW}${NC} To install ${BOLD}$name${NC}, please run:"
  echo -e "  ${CYAN}$install_hint${NC}"
  echo
  echo -e "${YELLOW}${ARROW}${NC} After installation, please restart your terminal or run:"
  echo -e "  ${CYAN}source ~/.bashrc${NC}  # or ~/.zshrc depending on your shell"
  echo
  echo -e "${YELLOW}${ARROW}${NC} Then run this installer again."
  echo
  exit 1
}

ensure_rust() {
  if command_exists rustc || command_exists cargo || command_exists rustup; then
    return 0
  fi
  prompt_install "Rust" "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
}

ensure_uv() {
  if command_exists uv; then
    return 0
  fi
  prompt_install "uv" "curl -LsSf https://astral.sh/uv/install.sh | sh"
}

ensure_path_bootstrap() {
  # Ensure current shell can see freshly installed tools without requiring restart
  if [ -d "$HOME/.cargo/bin" ] && ! echo ":$PATH:" | grep -q ":$HOME/.cargo/bin:"; then
    export PATH="$HOME/.cargo/bin:$PATH"
  fi
  if [ -d "$LOCAL_BIN_DIR" ] && ! echo ":$PATH:" | grep -q ":$LOCAL_BIN_DIR:"; then
    export PATH="$LOCAL_BIN_DIR:$PATH"
  fi
}

check_old_installation() {
  if [ -d "$REPO_DIR" ] && [ ! -d "$REPO_DIR/.git" ]; then
    echo -e "${YELLOW}${WARNING}${NC} Old installation detected at ${CYAN}$REPO_DIR${NC} (no git repository found)"
    return 0
  fi
  return 1
}

cleanup_old_installation() {
  echo
  echo -e "${YELLOW}${WARNING}${NC} An old installation of HDP CLI was found that needs to be removed."
  echo -e "${YELLOW}${WARNING}${NC} This will delete the following:"
  if [ -d "$REPO_DIR" ]; then
    echo -e "  ${CYAN}•${NC} Directory: ${CYAN}$REPO_DIR${NC}"
  fi
  if [ -e "$SYMLINK_PATH" ]; then
    echo -e "  ${CYAN}•${NC} Binary/symlink: ${CYAN}$SYMLINK_PATH${NC}"
  fi
  echo
  echo -e "${YELLOW}${ARROW}${NC} Do you want to remove the old installation and proceed with a fresh install? (y/N)"
  read -r response
  
  case "$response" in
    [yY]|[yY][eE][sS])
      echo -e "${BLUE}${INFO}${NC} Cleaning up old installation..."
      
      # Remove the old hdp directory
      if [ -d "$REPO_DIR" ]; then
        echo -e "${BLUE}${INFO}${NC} Removing old directory: ${CYAN}$REPO_DIR${NC}"
        rm -rf "$REPO_DIR"
      fi
      
      # Remove the old symlink or binary
      if [ -e "$SYMLINK_PATH" ]; then
        echo -e "${BLUE}${INFO}${NC} Removing old symlink/binary: ${CYAN}$SYMLINK_PATH${NC}"
        rm -f "$SYMLINK_PATH"
      fi
      
      echo -e "${GREEN}${SUCCESS}${NC} Old installation cleaned up successfully"
      ;;
    *)
      echo -e "${RED}${ERROR}${NC} Installation cancelled. Please remove the old installation manually and run this script again."
      exit 1
      ;;
  esac
}

clone_or_update_repo() {
  if [ -d "$REPO_DIR/.git" ]; then
    echo -e "${BLUE}${INFO}${NC} Repository already exists at ${CYAN}$REPO_DIR${NC}. Updating ${BOLD}$BIN_NAME${NC}..."
    git -C "$REPO_DIR" fetch --all --tags
    # Prefer fast-forward; if not possible, fallback to rebase
    if ! git -C "$REPO_DIR" pull --ff-only; then
      git -C "$REPO_DIR" pull --rebase --autostash || true
    fi
  else
    mkdir -p "$(dirname "$REPO_DIR")"
    echo -e "${BLUE}${INFO}${NC} Cloning ${CYAN}$REPO_URL${NC} into ${CYAN}$REPO_DIR${NC}..."
    git clone "$REPO_URL" "$REPO_DIR"
  fi
}

init_submodules() {
  echo -e "${BLUE}${INFO}${NC} Initializing submodules..."
  git -C "$REPO_DIR" submodule update --init
}

setup_python_env() {
  echo -e "${BLUE}${INFO}${NC} Setting up Python environment with ${BOLD}uv${NC}..."
  (cd "$REPO_DIR" && uv sync)
  # Activate the virtual environment in a subshell for any tooling that expects it
  if [ -f "$REPO_DIR/.venv/bin/activate" ]; then
    # shellcheck disable=SC1091
    . "$REPO_DIR/.venv/bin/activate"
  fi
}

build_cli() {
  echo -e "${BLUE}${INFO}${NC} Building ${BOLD}$BIN_NAME${NC} (release)..."
  (cd "$REPO_DIR" && cargo build --release --bin "$BIN_NAME")
}

ensure_symlink() {
  mkdir -p "$LOCAL_BIN_DIR"
  if [ -L "$SYMLINK_PATH" ]; then
    echo -e "${GREEN}${SUCCESS}${NC} Symlink already exists: ${CYAN}$SYMLINK_PATH${NC}"
    return 0
  fi
  if [ -e "$SYMLINK_PATH" ] && [ ! -L "$SYMLINK_PATH" ]; then
    echo -e "${YELLOW}${WARNING}${NC} A non-symlink file already exists at ${CYAN}$SYMLINK_PATH${NC}. Skipping symlink creation."
    return 0
  fi
  if [ ! -f "$TARGET_BIN" ]; then
    echo -e "${RED}${ERROR}${NC} Expected binary not found at ${CYAN}$TARGET_BIN${NC}"
    exit 1
  fi
  echo -e "${BLUE}${INFO}${NC} Creating symlink ${CYAN}$SYMLINK_PATH${NC} -> ${CYAN}$TARGET_BIN${NC}"
  ln -s "$TARGET_BIN" "$SYMLINK_PATH"
}

print_path_hint() {
  if ! echo ":$PATH:" | grep -q ":$LOCAL_BIN_DIR:"; then
    echo
    echo -e "${YELLOW}${WARNING}${NC} Note: ${CYAN}$LOCAL_BIN_DIR${NC} is not in your PATH. Consider adding this to your shell profile:"
    echo -e "  ${CYAN}export PATH=\"$LOCAL_BIN_DIR:\$PATH\"${NC}"
  fi
}

main() {
  echo -e "${PURPLE}${BOLD}╔══════════════════════════════════════╗${NC}"
  echo -e "${PURPLE}${BOLD}║        HDP Cairo CLI Installer        ║${NC}"
  echo -e "${PURPLE}${BOLD}╚══════════════════════════════════════╝${NC}"
  echo

  # Basic prerequisites
  for dep in git curl; do
    if ! command_exists "$dep"; then
      echo -e "${RED}${ERROR}${NC} Required dependency ${BOLD}'$dep'${NC} is not installed. Please install it and rerun."
      exit 1
    fi
  done

  ensure_rust
  ensure_uv
  ensure_path_bootstrap

  # Check for old installation and clean up if necessary
  if check_old_installation; then
    cleanup_old_installation
  fi

  clone_or_update_repo
  init_submodules
  setup_python_env
  build_cli
  ensure_symlink
  print_path_hint

  echo
  echo -e "${GREEN}${SUCCESS}${NC} ${BOLD}Installation/update complete!${NC} You can run ${BOLD}'$BIN_NAME'${NC} if $LOCAL_BIN_DIR is in PATH."
  echo
  echo -e "${GRAY}${BOLD}╔══════════════════════════════════════╗${NC}"
  echo -e "${GRAY}${BOLD}║           Developer Info             ║${NC}"
  echo -e "${GRAY}${BOLD}╚══════════════════════════════════════╝${NC}"
  echo
  echo -e "${BLUE}${INFO}${NC} You can work on HDP, debug, or make changes in the HDP folder:"
  echo -e "  ${CYAN}$REPO_DIR${NC}"
  echo
  echo -e "${YELLOW}${ARROW}${NC} Once you run ${BOLD}cargo build --release${NC}, the symlink will automatically make your version available everywhere using ${BOLD}hdp-cli${NC}"
  echo -e "${YELLOW}${ARROW}${NC} You can change branches, update the repo, add prints, or modify code as you please"
  echo -e "${YELLOW}${ARROW}${NC} The symlink always points to your latest built version"
  echo -e "${YELLOW}${ARROW}${NC} You can also symlink this repo into your project for easier access to debugging"
  echo -e "${YELLOW}${ARROW}${NC} To do this, run ${CYAN}hdp-cli link${NC} in your Scarb project directory, and import directly from there"
  echo
  echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════╗${NC}"
  echo -e "${YELLOW}${BOLD}║              IMPORTANT               ║${NC}"
  echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════╝${NC}"
  "$SYMLINK_PATH" env-info
}

main "$@"

