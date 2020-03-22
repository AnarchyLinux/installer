FROM archlinux/base:latest

LABEL maintainer="remisa.yousefvand@gmail.com"

COPY ./docker/setup.sh /usr/bin
RUN chmod +x /usr/bin/setup.sh
COPY ./docker/add-aur.sh /usr/bin
RUN chmod +x /usr/bin/add-aur.sh

# COPY ./docker/docker-compile.sh /usr/bin
# RUN chmod +x /usr/bin/docker-compile.sh

RUN pacman -Syu --needed --noconfirm arch-install-scripts

# Add non root user (builder). Needed for AURs compile & install
RUN bash /usr/bin/add-aur.sh builder
# Make packages available offline
RUN bash /usr/bin/setup.sh builder

# Clean up
# RUN pacman -Scc --noconfirm

# Not embedding 'docker-compile.sh' into docker image
# makes instant changes to compile process easy.
# Compile ISO using project script outside container
CMD [ "bash", "/project/docker/docker-compile.sh" ]

# ENTRYPOINT ["/usr/bin/docker-compile.sh"]
# WORKDIR /project

