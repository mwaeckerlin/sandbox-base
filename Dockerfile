# Shared base for the interactive SSH sandboxes (hermes, openclaw): the
# complete tool set, the hardened SSH daemon and the docker client are
# built ONCE here — derived images only add their skills and entrypoint.
ARG PACKAGES="openssh-server docker.io docker-compose-v2"
ARG CONFIGURATION_COMMANDS=" \
  sed -i \
  -e 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' \
  -e 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' \
  -e 's/^#*UsePAM.*/UsePAM yes/' \
  -e 's/^#*PermitRootLogin.*/PermitRootLogin no/' \
  /etc/ssh/sshd_config \
  && sed -i '/[Pp]ubkey[Aa]uthentication/d' /etc/ssh/sshd_config \
  && echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config \
  && mkdir -p /run/sshd \
  && adduser \${RUN_USER} docker \
  && install -m 700 -o \${RUN_USER} -g \${RUN_GROUP} /dev/null /etc/environment \
  "

# one stage only: the ONBUILD steps of mwaeckerlin/ubuntu-base, which install
# PACKAGES and run CONFIGURATION_COMMANDS, took effect in the first of two
# stages built on it and not in the second, the one that is published
FROM mwaeckerlin/ubuntu-base
ARG TARGETARCH
ENV CONTAINERNAME="sandbox"
# OpenCode, the coding agent, runs in the sandbox on the checkout and the
# toolset of the agent; it never updates itself and downloads nothing, because
# a sandbox reaches no internet
ENV OPENCODE_DISABLE_AUTOUPDATE="true" \
    OPENCODE_DISABLE_MODELS_FETCH="true" \
    OPENCODE_DISABLE_LSP_DOWNLOAD="true" \
    OPENCODE_DISABLE_CLAUDE_CODE="true"
ENV PACKAGES_DEV=" \
  lsb-release bash coreutils findutils grep sed gawk diffutils patch file tree \
  git git-lfs gh \
  build-essential make cmake ninja-build \
  autoconf automake autotools-dev libtool pkg-config \
  gcc g++ gdb valgrind clang clang-format shellcheck \
  "
ENV PACKAGES_LANG=" \
  python-is-python3 python3 python3-pip python3-venv python3-dev black pylint \
  php-cli php-mbstring php-xml php-curl php-zip composer \
  nodejs npm ruby ruby-dev golang rustc cargo \
  pipx python3-poetry \
  "
ENV PACKAGES_MEDIA=" \
  graphviz plantuml pandoc \
  ffmpeg imagemagick sox lame opus-tools \
  gimp optipng jpegoptim webp potrace \
  libimage-exiftool-perl mediainfo gnuplot \
  inkscape librsvg2-bin libreoffice-core \
  poppler-utils ghostscript qpdf \
  tesseract-ocr tesseract-ocr-deu tesseract-ocr-eng \
  "
ENV PACKAGES_LATEX=" \
  texlive-latex-base texlive-fonts-recommended texlive-latex-extra texlive-xetex latexmk \
  "
ENV PACKAGES_UTILS=" \
  curl wget nmap iputils-ping iproute2 netcat-openbsd dnsutils \
  openssh-client rsync jq yq ripgrep fd-find bat fzf just htop \
  zip unzip xz-utils bzip2 procps ca-certificates gnupg apt-transport-https \
  locales pwgen chromium-browser xdg-utils w3m \
  "
ENV PACKAGES_DB=" \
  postgresql-client redis-tools default-mysql-client sqlite3 \
  "
USER root
RUN $PKG_INSTALL ${PACKAGES_DEV}
RUN $PKG_INSTALL ${PACKAGES_LANG}
RUN $PKG_INSTALL ${PACKAGES_MEDIA}
RUN $PKG_INSTALL ${PACKAGES_LATEX}
RUN $PKG_INSTALL ${PACKAGES_UTILS}
RUN $PKG_INSTALL ${PACKAGES_DB}
# quoted bash -c: the cleanup value contains shell operators — an unquoted
# RUN ${PKG_CLEANUP} passes them as literal arguments to apt-get
RUN bash -c "${PKG_CLEANUP}"
RUN ( \
  echo "# PACKAGES_DEV"; \
  echo ${PACKAGES_DEV} | tr ' ' '\n'; \
  echo; \
  echo "# PACKAGES_LANG"; \
  echo ${PACKAGES_LANG} | tr ' ' '\n'; \
  echo; \
  echo "# PACKAGES_MEDIA"; \
  echo ${PACKAGES_MEDIA} | tr ' ' '\n'; \
  echo; \
  echo "# PACKAGES_LATEX"; \
  echo ${PACKAGES_LATEX} | tr ' ' '\n'; \
  echo; \
  echo "# PACKAGES_UTILS"; \
  echo ${PACKAGES_UTILS} | tr ' ' '\n'; \
  echo; \
  echo "# PACKAGES_DB"; \
  echo ${PACKAGES_DB} | tr ' ' '\n' \
  ) > /etc/installed-ubuntu-packages
RUN install -d -m 700 -o ${RUN_USER} -g ${RUN_GROUP} ${RUN_HOME}/.ssh
# the newest release of OpenCode, for the architecture of the build, behind the
# command that writes its configuration from the environment
RUN case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
      amd64) ARCH=x64 ;; \
      arm64) ARCH=arm64 ;; \
      *) echo "unsupported architecture ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && install -d /usr/local/lib/opencode \
    && curl -fsSL "https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-${ARCH}.tar.gz" \
       | tar -xz -C /usr/local/lib/opencode opencode \
    && /usr/local/lib/opencode/opencode --version
COPY --chmod=0755 files/opencode /usr/local/bin/opencode
EXPOSE 22
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=60 \
  CMD nc -z localhost 22 || exit 1
