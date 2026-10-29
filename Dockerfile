ARG BASE_IMAGE=debian:trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4

### Tool installer: versions and checksums live in mise.toml / mise.lock ###
FROM ${BASE_IMAGE} AS mise
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN apt-get update && \
	apt-get install -y --no-install-recommends ca-certificates curl git libatomic1 xz-utils && \
	rm -rf /var/lib/apt/lists/*
COPY --from=jdxcode/mise:2026.10.22@sha256:efd2ddb8c93c9c5c10d723ac41757910e29a6d4bfaf4e8c444f99b802997e48c /usr/local/bin/mise /usr/local/bin/mise
ENV MISE_DATA_DIR=/opt/mise \
	MISE_CACHE_DIR=/tmp/mise-cache \
	MISE_YES=1
WORKDIR /opt/tools
COPY mise.toml mise.lock ./
RUN mise trust

### Release binaries ###
FROM mise AS bins
RUN mise install --locked && \
	mkdir -p /out/bin /out/opt && \
	for bin in kubectl flux kustomize helm just stern talosctl gh jq yq rg fd sofka thurm thurmd thurm-tailnet; do \
		install -m 0755 "$(mise which "${bin}")" /out/bin/; \
	done && \
	# pi ships addons beside its executable, and npm needs node's lib/: keep both trees whole.
	for tool in node pi; do \
		cp -a "$(mise where "${tool}")" "/out/opt/${tool}"; \
	done && \
	ln -s "/opt/pi/$(realpath --relative-to "$(mise where pi)" "$(mise which pi)")" /out/bin/pi

FROM ${BASE_IMAGE}
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		bash ca-certificates catatonit curl fish gawk git gzip less libatomic1 mosh ncurses-term \
		openssh-server openssh-sftp-server procps tar tmux tzdata && \
	rm -rf /var/lib/apt/lists/* && \
	# Debian's config turns on PAM, which a non-root sshd cannot use; the entrypoint passes the rest.
	echo "UsePAM no" >/etc/ssh/sshd_config && \
	rm -f /etc/ssh/ssh_host_* && \
	mkdir -p /run/sshd /config && \
	useradd --uid 1000 --user-group --home-dir /config --no-create-home --shell /usr/bin/fish me && \
	chown 1000:1000 /config

COPY --from=bins /out/opt/ /opt/
COPY --from=bins /out/bin/ /usr/local/bin/
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/bastion-entrypoint
COPY --chmod=0755 scripts/pi-channel.sh /usr/local/bin/pi-channel
COPY --chmod=0755 scripts/mosh-server.sh /usr/local/bin/mosh-server
# npm and npx are relative links into node's lib/, so node's bin/ goes on PATH as is.
ENV PATH=/usr/local/bin:/opt/node/bin:/usr/bin:/bin

RUN kubectl version --client && \
	flux version --client && \
	kustomize version && \
	helm version && \
	just --version && \
	stern --version && \
	talosctl version --client && \
	gh --version && \
	jq --version && \
	yq --version && \
	rg --version && \
	fd --version && \
	node --version && \
	npm --version && \
	pi --version && \
	sofka --version && \
	thurm --version && \
	test -x /usr/local/bin/thurm-tailnet

USER 1000:1000
WORKDIR /config
ENV HOME=/config \
	USER=me \
	USER_NAME=me \
	PORT=2222 \
	LANG=C.UTF-8 \
	SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
	NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
	GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt \
	PI_CODING_AGENT_DIR=/config/.pi/agent \
	PI_SKIP_VERSION_CHECK=1 \
	LITELLM_BASE_URL=http://litellm.ai.svc.cluster.local:4000 \
	MERIDIAN_BASE_URL=http://meridian.ai.svc.cluster.local:3456 \
	MOSH_PORT_RANGE=60001:60005 \
	THURM_TAILNET=/usr/local/bin/thurm-tailnet
EXPOSE 2222/tcp 60001/udp 60002/udp 60003/udp 60004/udp 60005/udp
VOLUME /config
ENTRYPOINT ["/usr/bin/catatonit", "--", "/usr/local/bin/bastion-entrypoint"]
