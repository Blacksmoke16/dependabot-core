FROM ghcr.io/dependabot/dependabot-updater-core

ARG CRYSTAL_VERSION=1.12

RUN curl -fsSL https://crystal-lang.org/install.sh | bash -s -- --version=$CRYSTAL_VERSION

USER dependabot

# Sanity check
RUN shards --version

COPY --chown=dependabot:dependabot shards $DEPENDABOT_HOME/shards
COPY --chown=dependabot:dependabot common $DEPENDABOT_HOME/common
COPY --chown=dependabot:dependabot updater $DEPENDABOT_HOME/dependabot-updater
