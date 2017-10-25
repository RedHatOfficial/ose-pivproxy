#!/bin/bash

# get release version
RELEASE=$(cat /etc/redhat-release)
YUM_ARGS=""

# if the release is a red hat version then we need to set additional arguments for yum repositories
if [[ "${RELEASE}" =~ '^Red Hat.*$' ]]; then
  YUM_ARGS='--disablerepo=\* --enablerepo=rhel-7-server-rpms --enablerepo=rhel-server-rhscl-7-rpms --enablerepo=rhel-7-server-optional-rpms'
fi

# ensure latest versions
yum update -y

# enable epel when on CentOS
if [[ "${RELEASE}" =~ '^CentOS.*$' ]]; then
  yum install -y epel-release
fi

# install required packages
yum install -y --setopt=tsflags=nodocs $YUM_ARGS \
        httpd \
        mod_ssl \
        mod_session \
        apr-util-openssl \
        gettext \
        nss_wrapper

# clean up yum to make sure image isn't larger because of installations/updates
yum clean all
rm -rf /var/cache/yum/*
rm -rf /var/lib/yum/*
