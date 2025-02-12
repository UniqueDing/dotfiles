FROM debian

USER root
RUN apt-get update -y && apt-get install -y curl xz-utils sudo openssh-server
RUN apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8
RUN useradd -m uniqueding
RUN echo " uniqueding      ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

WORKDIR /home/uniqueding

COPY . /home/uniqueding/dotfiles
RUN chown -R uniqueding:uniqueding /home/uniqueding/dotfiles
WORKDIR /home/uniqueding/dotfiles
COPY nix.conf /etc/nix/

USER uniqueding

RUN mkdir -p /home/uniqueding/.config /home/uniqueding/.local/share /home/uniqueding/.cache
ENV USER "uniqueding"
ENV PATH "/home/uniqueding/.nix-profile/bin:/home/uniqueding/.local/bin:${PATH}"
RUN curl https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install | sh
RUN nix-env -iA nixpkgs.home-manager
RUN home-manager switch -f home/home-light.nix


ENV TMUX_PLUGIN_MANAGER_PATH /home/uniqueding/.tmux/plugins/tpm
RUN git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
RUN ~/.tmux/plugins/tpm/bin/install_plugins
RUN ya pack -u
RUN fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher && fisher update"
RUN nvim --headless -c 'Lazy! sync' -c 'qa'
RUN echo "build end"

USER root
RUN mkdir -p /run/sshd

CMD ["/usr/sbin/sshd", "-D"] 
