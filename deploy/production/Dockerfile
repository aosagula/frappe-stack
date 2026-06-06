FROM frappe/bench:latest

USER root

RUN apt-get update \
	&& apt-get install -y --no-install-recommends nginx gettext-base \
	&& rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /run/nginx /var/log/nginx

USER frappe

WORKDIR /home/frappe

COPY --chown=frappe:frappe apps/frappe     /home/frappe/src/apps/frappe
COPY --chown=frappe:frappe apps/erpnext    /home/frappe/src/apps/erpnext
COPY --chown=frappe:frappe apps/crm        /home/frappe/src/apps/crm
COPY --chown=frappe:frappe apps/telephony  /home/frappe/src/apps/telephony
COPY --chown=frappe:frappe apps/helpdesk   /home/frappe/src/apps/helpdesk
COPY --chown=frappe:frappe deploy/production/scripts/build-image-bench.sh /home/frappe/build-image-bench.sh

RUN bash /home/frappe/build-image-bench.sh

USER root

COPY deploy/production/nginx.conf.template /etc/nginx/templates/frappe.conf.template
COPY deploy/production/scripts/init-site.sh /usr/local/bin/init-site
COPY deploy/production/scripts/start-nginx.sh /usr/local/bin/start-nginx

RUN chmod +x /usr/local/bin/init-site /usr/local/bin/start-nginx

WORKDIR /home/frappe/frappe-bench

USER frappe
