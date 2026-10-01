# Imagen de produccion por cliente.
# Arma el bench con el mismo script que usa el CI (scripts/build-bench.sh), asi lo que se testea es lo que se despliega.
#
#   docker build -f deploy/production/Dockerfile --build-arg CLIENT=demo -t frappe-demo .

ARG PYTHON_VERSION=3.14
ARG NODE_VERSION=24
ARG DEBIAN=trixie

FROM node:${NODE_VERSION}-${DEBIAN}-slim AS node

FROM python:${PYTHON_VERSION}-slim-${DEBIAN} AS base
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
	&& ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
	&& ln -s /usr/local/lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack \
	&& corepack enable \
	&& corepack prepare yarn@1.22.22 --activate
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		git curl ca-certificates mariadb-client libmariadb3 redis-tools \
		fonts-noto-core xfonts-75dpi xfonts-base \
	&& rm -rf /var/lib/apt/lists/* \
	&& pip install --no-cache-dir frappe-bench \
	&& useradd -m -s /bin/bash frappe

FROM base AS builder
ARG CLIENT
RUN apt-get update \
	&& apt-get install -y --no-install-recommends build-essential pkg-config libmariadb-dev libffi-dev \
	&& rm -rf /var/lib/apt/lists/*
USER frappe
WORKDIR /home/frappe/platform
COPY --chown=frappe:frappe stack.json ./
COPY --chown=frappe:frappe scripts ./scripts
COPY --chown=frappe:frappe apps ./apps
COPY --chown=frappe:frappe clients/${CLIENT} ./clients/${CLIENT}
RUN test -n "${CLIENT}" \
	&& PYTHON=python3 SRC_DIR=/home/frappe/src bash scripts/build-bench.sh "${CLIENT}" /home/frappe/frappe-bench \
	&& python3 scripts/stack.py apps "${CLIENT}" | tr ' ' '\n' > /home/frappe/client-apps.txt \
	&& mkdir -p /home/frappe/prebuilt-assets \
	&& cp -a /home/frappe/frappe-bench/sites/assets/. /home/frappe/prebuilt-assets/ \
	&& rm -rf /home/frappe/src /home/frappe/.cache \
	&& find /home/frappe/frappe-bench/apps -name node_modules -type d -prune -exec rm -rf {} +

FROM base AS runtime
ARG CLIENT
ARG RELEASE=dev
LABEL org.opencontainers.image.source="https://github.com/aosagula/frappe-stack" \
	agentic4biz.client="${CLIENT}" \
	agentic4biz.release="${RELEASE}"
RUN apt-get update \
	&& apt-get install -y --no-install-recommends nginx gettext-base \
	&& rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /run/nginx /var/log/nginx
COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench /home/frappe/frappe-bench
COPY --from=builder --chown=frappe:frappe /home/frappe/prebuilt-assets /home/frappe/prebuilt-assets
COPY --from=builder --chown=frappe:frappe /home/frappe/client-apps.txt /home/frappe/client-apps.txt
COPY deploy/production/nginx.conf.template /etc/nginx/templates/frappe.conf.template
COPY deploy/production/scripts/init-site.sh /usr/local/bin/init-site
COPY deploy/production/scripts/start-nginx.sh /usr/local/bin/start-nginx
RUN chmod +x /usr/local/bin/init-site /usr/local/bin/start-nginx \
	&& echo "${RELEASE}" > /home/frappe/release.txt
WORKDIR /home/frappe/frappe-bench
USER frappe
