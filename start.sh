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

# collect information
export CURRENT_NAMESPACE=`cat /var/run/secrets/kubernetes.io/serviceaccount/namespace`

# create client certificate bundle
cat /secrets/tls.crt > /tmp/proxy_client.pem
cat /secrets/tls.key >> /tmp/proxy_client.pem

# start apache
/usr/sbin/httpd -DFOREGROUND