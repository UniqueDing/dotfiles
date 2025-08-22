FROM debian

USER root
RUN apt-get update -y && apt-get install -y curl xz-utils sudo openssh-server
RUN apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG "en_US.UTF-8"
ENV LC_ALL "en_US.UTF-8"
RUN useradd -m uniqueding
RUN echo " uniqueding      ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

WORKDIR /home/uniqueding

COPY . /home/uniqueding/dotfiles
RUN chown -R uniqueding:uniqueding /home/uniqueding/dotfiles
WORKDIR /home/uniqueding/dotfiles

USER uniqueding
RUN mkdir -p /home/uniqueding/.config /home/uniqueding/.local/share /home/uniqueding/.cache
ENV USER "uniqueding"
ENV PATH "/home/uniqueding/.nix-profile/bin:/home/uniqueding/.local/bin:${PATH}"
RUN bash build-homemanager.sh all docker

RUN echo "export LANG=en_US.UTF-8" >> /home/uniqueding/.profile
RUN echo "export LC_ALL=en_US.UTF-8" >> /home/uniqueding/.profile
RUN echo "build end"

USER root
RUN mkdir -p /run/sshd

CMD ["/usr/sbin/sshd", "-D"]
