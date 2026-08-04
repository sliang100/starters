#!/usr/bin/env bash


### check for zsh & pip
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  sudo apt update
  sudo apt install -y \
    zsh \
    git-delta \
    python3-pip \
    powerline \
    fonts-powerline \
    wget \
    curl \
    git
elif [[ "$OSTYPE" == "darwin"* ]]; then
  brew update
  brew upgrade
  brew install \
    zsh \
    git-delta \
    powerline-go \
    wget \
    curl
  brew install --cask font-hack-nerd-font || true #in case there are any errors
fi

### Vim setup
# Vundle is a Vim bundle/plugin system, allows for quick and easy installation of new vim plugins
mkdir -p ~/.vim/bundle
if [ ! -d ~/.vim/bundle/Vundle.vim ]; then
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi

# Modify your vimrc as necessary to remove any plugins or add any plugins
cp ./vim/.vimrc ~/
cp -r ./vim/.vim/. ~/.vim/
# Below installs all the vim plugins using Vundle
vim +PluginInstall +qall


mkdir -p ~/.ssh
cp -R ./git/.gitconfig ~/

cp -R ./tmux/.tmux.conf ~/

CUSTOM_MARKER="# --- CUSTOM .bash_profile SECTION ---"

if ! grep -qF "$CUSTOM_MARKER" ~/.bash_profile 2>/dev/null; then
  touch ~/.bash_profile
  printf "\n%s\n" "$CUSTOM_MARKER" >> ~/.bash_profile
  cat ./bash/.bash_profile >> ~/.bash_profile
else
  echo "Custom .bash_profile settings already present, skipping."
fi

# aliases set up
cp ./aliases/.aliases ~/

# Oh My Zsh is a zsh theming library
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  # 'CHSH=no', RUNZSH=no, and updated install script URL (robbyrussell repo is deprecated) to prevent terminal hijacking
  CHSH=no RUNZSH=no keep_zshrc=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install honukai theme
mkdir -p ~/.oh-my-zsh/custom/themes
curl -fsSL 'https://raw.githubusercontent.com/oskarkrawczyk/honukai-iterm-zsh/master/honukai.zsh-theme' \
  -o ~/.oh-my-zsh/custom/themes/honukai.zsh-theme

cp ./zsh/.zshrc ~/.zshrc
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' 's/^ZSH_THEME=.*/ZSH_THEME="honukai"/' ~/.zshrc
  #macOS requires empty string arg
else
  sed -i 's/^ZSH_THEME=.*/ZSH_THEME="honukai"/' ~/.zshrc
fi

ZSH_BIN="$(command -v zsh)"

if [ -n "$ZSH_BIN" ] && [ "$SHELL" != "$ZSH_BIN" ]; then
  # piped true, so password prompt skips gracefully in non-interactive shells
  chsh -s "$ZSH_BIN" || true
fi

# switch to zsh if installed correctly
if [ -t 0 ] && [ -n "$ZSH_BIN" ]; then
  # -l flag to ensure profile environment variables are loaded
  exec "$ZSH_BIN" -l
fi