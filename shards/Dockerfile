FROM ghcr.io/dependabot/dependabot-updater-core

ARG CRYSTAL_VERSION=1.17.0-475

# TODO: Maybe just install shards itself
RUN curl -s https://packagecloud.io/install/repositories/84codes/crystal/script.deb.sh | bash \
  && apt-get install -y crystal=${CRYSTAL_VERSION}

USER dependabot

# Sanity check
RUN shards --version

COPY --chown=dependabot:dependabot shards $DEPENDABOT_HOME/shards
COPY --chown=dependabot:dependabot common $DEPENDABOT_HOME/common
COPY --chown=dependabot:dependabot updater $DEPENDABOT_HOME/dependabot-updater
