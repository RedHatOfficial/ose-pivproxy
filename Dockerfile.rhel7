# built from rhel7
FROM rhel7
MAINTAINER Chris Ruffalo <cruffalo@redhat.com>

LABEL io.k8s.description="HTTPD Proxy configured to support PIV authentication with OCP" \
  io.k8s.display-name="HTTPD PIV Proxy" \
  io.openshift.expose-services="8080:tcp,8443:tcp" \
  io.openshift.tags="x509,certificates,proxy,PIV,CAC" \
  name="ose-pivproxy" \
  architecture=x86_64

# expose 80 for healthcheck and redirect, 443 for ssl
EXPOSE 8080 8443

# use shared steps to build
COPY shared-build.sh /tmp/shared-build.sh
RUN chmod +x /tmp/shared-build.sh && \
    /tmp/shared-build.sh && \
    rm -f /tmp/shared-build.sh

# set environment variables
ENV MASTER_PUBLIC_URL=ocp.master.com \
    PIVPROXY_PUBLIC_URL=pivproxy.master.com \
    BASE_NAME=ose-pivproxy \
    PROXY_LOG_LEVEL=info \
    MAX_KEEP_ALIVE_REQUESTS=100

# create supporting folders, permissions, etc
RUN mkdir /apache && \
    mkdir /buildinfo

# copy in supporting files
COPY passwd.template start.sh /apache/
COPY shared-setup.sh /tmp/
COPY index.html healthz.html /var/www/html/
COPY Dockerfile.rhel7 /buildinfo/Dockerfile
COPY pivproxy.conf /apache/default-pivproxy.conf
COPY apache-global.conf /etc/httpd/conf.d/00-global.conf

# run, and then remove, shared setup steps
RUN chmod +x /tmp/shared-setup.sh && \
    /tmp/shared-setup.sh && \
    rm -f /tmp/shared-setup.sh

# set working dir
WORKDIR /apache

# start httpd as the entry point
ENTRYPOINT /apache/start.sh
