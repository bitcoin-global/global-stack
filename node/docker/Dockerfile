FROM debian:stretch-slim

# Configure users
RUN groupadd -r bitglob && useradd -r -m -g bitglob bitglob

# Add packages
RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu dnsutils gpg git wget \
	&& rm -rf /var/lib/apt/lists/*

# Copy and move
WORKDIR /opt
COPY ../install-node.sh ./install-node.sh
COPY ./docker-entrypoint.sh /entrypoint.sh

# Configs
ARG BITCOIN_VERSION="0.19.2"
ENV PATH="/bitcoin-global/src:/opt/bin:${PATH}"

# Install Bitcoin Global
RUN ./install-node.sh \
	-v $BITCOIN_VERSION \
	-r v$BITCOIN_VERSION \
	-d /bitcoin-global \
	-t /opt

# Expose
ENV BITGLOB_DATA=/bitcoin-global
VOLUME ["/bitcoin-global"]
EXPOSE 8333 8332 8222 18333 18332 18222

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bitglobd"]