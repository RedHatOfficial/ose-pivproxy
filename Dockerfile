# built from centos
FROM centos:7
MAINTAINER Chris Ruffalo <cruffalo@redhat.com>

LABEL io.k8s.description="HTTPD Proxy configured to support PIV authentication with OCP" \
  io.k8s.display-name="HTTPD PIV Proxy" \
  io.openshift.expose-services="80:tcp,443:tcp \
  io.openshift.tags="x509,certificates,proxy,PIV,CAC" \
  name="ose-pivproxy" \
  architecture=x86_64

# expose 80 for healthcheck and redirect, 443 for ssl
EXPOSE 8080 8443

# yum update/install
RUN yum update -y && \
	  yum install -y epel-release && \
    yum install -y --setopt=tsflags=nodocs \
                   httpd \
                   mod_ssl \
                   mod_session \
                   apr-util-openssl \
                   gettext \
                   hostname \
                   iproute \
                   curl \
                   nss_wrapper && \
    yum clean all && \
    rm -rf /var/cache/yum/* && \
    rm -rf /var/lib/yum/*

# change apache ports and remove files
RUN sed -i 's/Listen 80/Listen 8080/g' /etc/httpd/conf/httpd.conf && \
    rm -f /etc/httpd/conf.d/ssl.conf && \
    rm -f /etc/httpd/conf.d/autoindex.conf && \
    rm -f /etc/httpd/conf.d/userdir.conf && \
    rm -f /etc/httpd/conf.d/README && \
    rm -f /etc/httpd/conf.d/welcome.conf

# set environment variables
ENV MASTER_PUBLIC_URL=ocp.master.com

# create supporting folders, permissions, etc
RUN mkdir /apache && \
    mkdir /buildinfo && \
    mkdir /secrets

# copy in supporting files
COPY passwd.template start.sh /apache/
COPY healthz.html /var/www/html/
COPY Dockerfile /buildinfo/
COPY pivproxy.conf /etc/httpd/conf.d/00-pivproxy.conf

# set file permissions
RUN chgrp -R 0 /apache && \
    chmod u+x,g+x /apache/start.sh && \
    chgrp -R 0 /secrets && \
    chgrp -R 0 /run/httpd && \
    chgrp -R 0 /etc/httpd && \
    chmod -R g+wx /run/httpd && \
    chmod -R g+wx /etc/httpd/run && \
    chmod -R g+wx /etc/httpd/logs && \
    chmod -R g+rwx /var/log/httpd

# set working dir
WORKDIR /apache

# set mount points / volumes
VOLUME ["/secrets"]

# start httpd as the entry point
#ENTRYPOINT /apache/start.sh