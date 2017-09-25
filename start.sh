#!/bin/bash

# set up user id into passwd wrapper
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
cat /apache/passwd.template | envsubst > /tmp/passwd
export LD_PRELOAD=/usr/lib64/libnss_wrapper.so
export NSS_WRAPPER_PASSWD=/tmp/passwd
export NSS_WRAPPER_GROUP=/etc/group
USER_NAME=$(id -un)

# show that alternate user IDs are being honored
echo "Running with user ${USER_NAME} (${USER_ID}) and group ${GROUP_ID}"

# handle pre-startup configuration

# create client certificate bundle
cat /etc/pki/tls/private/tls.crt > /tmp/proxy_client.pem
cat /etc/pki/tls/private/tls.key >> /tmp/proxy_client.pem

# start apache
/usr/sbin/httpd -DFOREGROUND