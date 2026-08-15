#!/usr/bin/env bash

set -euo pipefail

log_info() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

ensure_starters_directory(){
  # get script directory
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # check parent directory name
  if [[ "$(basename "$script_dir")" != "starters" ]]; then
    log_error "This script must reside inside the original cloned directory named 'starters'."
    return 1
  fi

  cd "$script_dir"
}

install_sys_packages() {
  log_info "Installing system packages..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # force non-interactive for updating
    sudo apt-get update -o Dpkg::Use-Pty=0
    sudo apt-get install -y -o Dpkg::Use-Pty=0 \
      zsh \
      git-delta \
      python3 \
      python-is-python3 \
      python3-pip \
      python3-venv \
      powerline \
      fonts-powerline \
      wget \
      curl \
      git \
      rsync \
      xclip
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew update
    brew install \
      pyenv \
      python \
      uv \
      pipx \
      zsh \
      git-delta \
      powerline-go \
      wget \
      curl
    brew install --cask font-hack-nerd-font || true #in case there are any errors
  fi
}

setup_timezone() {
  log_info "Determining and setting system timezone via public IP..."
  local timezone
  timezone="$(curl -fsSL --max-time 5 https://ipapi.co/timezone 2>/dev/null || true)"

  if [[ -z "$timezone" ]]; then
    log_error "Could not auto-determine timezone via IP, skipping.."
    return 0;
  fi

  log_info "Timezone: ${timezone}"

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # prevents errors on minimal Linux installations (i.e. docker and WSL)
    if command -v timedatectl >/dev/null 2>&1; then
      sudo timedatectl set-timezone "$timezone" 2>/dev/null || log_error "Failed to update timezone via timedatectl"
    else
      log_error "timedatectl not found, skipping Linux timezone update"
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    sudo systemsetup -settimezone "$timezone" >/dev/null 2>&1 || true
  fi
}

setup_vim() {
  log_info "Setting up .vimrc and vim plugins..."
  
  # Vundle is a Vim bundle/plugin system, allows for quick and easy installation of new vim plugins
  mkdir -p ~/.vim/bundle
  if [[ ! -d ~/.vim/bundle/Vundle.vim ]]; then
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
  fi

  # Modify your vimrc as necessary to remove any plugins or add any plugins
  rsync -a ./vim/.vimrc ~/.vimrc
  rsync -a ./vim/.vim/ ~/.vim/
  # headless vim plugin installation
  vim -es -u ~/.vimrc +PluginInstall +qall < /dev/null || true
}

setup_touch_id() {
  # only macOS has touchID
  if [[ "$OSTYPE" != "darwin"* ]]; then
    return 0
  fi

  log_info "Setting up macOS Touch ID for sudo..."

  # macOS 14+ provides a dedicated local config file
  if [[ -f /etc/pam.d/sudo_local.template ]]; then
    if ! grep -qF "pam_tid.so" /etc/pam.d/sudo_local 2>/dev/null; then
      log_info "Enabling Touch ID via /etc/pam.d/sudo_local..."
      sudo sed -e 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local > /dev/null
      sudo chmod 444 /etc/pam.d/sudo_local
    else
      log_info "Touch ID already enabled in /etc/pam.d/sudo_local, skipping."
    fi
  else
    # legacy macOS fallback
    if ! grep -qF "pam_tid.so" /etc/pam.d/sudo 2>/dev/null; then
      log_info "Enabling Touch ID in /etc/pam.d/sudo..."
      sudo sed -i '' '1s/^/auth       sufficient     pam_tid.so\n/' /etc/pam.d/sudo
    else
      log_info "Touch ID already enabled in /etc/pam.d/sudo, skipping."
    fi
  fi
}

idempotent_copy() {
  if [[ "$#" -ne 2 ]]; then
    log_error "Incorrect num arguments for idempotent_copy helper function"
    log_info "Usage: idempotent_copy [source path] [destination path]"
    return 1
  fi

  local source_path="$1"
  local source_file="$(basename "$source_path")"
  local destination_path="$2"
  local custom_marker="# --- CUSTOM ${source_file} SECTION ---"

  # make sure destination path exists
  mkdir -p "$(dirname "$destination_path")"
  touch "$destination_path"

  if ! grep -qF "$custom_marker" "$destination_path" 2>/dev/null; then    # macOS needs file already present; linux doesn't care
    printf "\n%s\n" "$custom_marker" >> "$destination_path"
    cat "$source_path" >> "$destination_path"
  else
    log_info "Custom ${source_file} settings already present, skipping."
  fi
}

copy_dotfiles() {
  log_info "Copying dotfiles (.gitconfig, .tmux.config, .bash_profile, .aliases, )..."

  mkdir -p ~/.ssh
  rsync -a ./tmux/ ~/

  idempotent_copy ./git/.gitconfig ~/.gitconfig
  idempotent_copy ./bash/.bash_profile ~/.bash_profile
  idempotent_copy ./aliases/.aliases ~/.aliases

}

setup_zsh() {
  # Oh My Zsh is a zsh theming library
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    # install without switching
    CHSH=no RUNZSH=no keep_zshrc=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi

  # install honukai theme
  mkdir -p ~/.oh-my-zsh/custom/themes
  curl -fsSL 'https://raw.githubusercontent.com/oskarkrawczyk/honukai-iterm-zsh/master/honukai.zsh-theme' \
    -o ~/.oh-my-zsh/custom/themes/honukai.zsh-theme

  rsync -a ./zsh/.zshrc ~/.zshrc
  perl -pi -e 's/^ZSH_THEME=.*/ZSH_THEME="honukai"/' ~/.zshrc
}

set_default_shell_to_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"

  if [[ -n "$zsh_path" ]] && [[ "${SHELL:-}" != "$zsh_path" ]]; then
    # try passwordless sudo, if available
    # piped true, so password prompt skips gracefully in non-interactive shells
    if sudo -n true 2>/dev/null; then
      sudo chsh -s "$zsh_path" "$USER" || true
    elif [[ -t 0 ]]; then
      chsh -s "$zsh_path" < /dev/null 2>/dev/null || \
      log_error "Could not change default shell automatically. You can switch manually by running: chsh -s $zsh_path"
    else
      log_info "Non-interactive shell, skipping chsh password prompt..."
    fi
  fi
}

main() {
  ensure_starters_directory
  install_sys_packages
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    setup_timezone
  fi
  setup_vim
  setup_touch_id
  copy_dotfiles
  setup_zsh
  set_default_shell_to_zsh

  # switch to zsh if installed correctly
  local zsh_path
  zsh_path="$(command -v zsh || true)"

  if [[ -t 0 ]] && [[ -n "$zsh_path" ]]; then
    # -l flag to ensure profile environment variables are loaded
    exec "$zsh_path" -l
  fi
}

main "$@"