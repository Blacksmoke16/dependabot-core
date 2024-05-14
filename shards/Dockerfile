FROM ghcr.io/dependabot/dependabot-updater-core

# ARG CRYSTAL_VERSION=1.12.1
#
# RUN curl -fsSL https://crystal-lang.org/install.sh | sudo bash

USER dependabot

# Sanity check
# RUN shards --version

COPY --chown=dependabot:dependabot shards $DEPENDABOT_HOME/shards
COPY --chown=dependabot:dependabot common $DEPENDABOT_HOME/common
COPY --chown=dependabot:dependabot updater $DEPENDABOT_HOME/dependabot-updater
