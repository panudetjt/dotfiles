FROM --platform=amd64 amazonlinux:2

## Install needed package and setup non-root user. Use a separate RUN statement to add your own dependencies.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN yum -y update \
    # add group and user
    && yum -y install \
        openssl \
        git \
        tar \
        zsh \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd -s /bin/zsh --uid ${USER_UID} --gid ${USERNAME} -m ${USERNAME} \
    # && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
    # && chmod 0440 /etc/sudoers.d/${USERNAME} \
    # && if ! cat /etc/group | grep -e "^vscode:" > /dev/null 2>&1; then groupadd -r vscode; fi \
    # && usermod -a -G vscode ${USERNAME} \
    && umask 0002 \
    # clean up
    && yum clean all \
    && rm -rf /var/cache/yum

## Install volta
RUN su vscode -c "curl https://get.volta.sh | bash"

# Install pyenv
RUN su vscode -c "git clone https://github.com/pyenv/pyenv.git ~/.pyenv"

# Install my dotfiles
RUN su vscode -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && su vscode -c "git clone https://github.com/panudetjt/dotfiles.git ~/.dotfiles" \
    && su vscode -c "ln -sf ~/.dotfiles/.zshrc ~/.zshrc" \
    && su vscode -c "git clone https://github.com/spaceship-prompt/spaceship-prompt.git ~/.oh-my-zsh/custom/themes/spaceship-prompt --depth=1" \
    && su vscode -c "ln -s ~/.oh-my-zsh/custom/themes/spaceship-prompt/spaceship.zsh-theme ~/.oh-my-zsh/custom/themes/spaceship.zsh-theme" \
    && su vscode -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" \
    && su vscode -c "git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

