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

# if the customizable configuration exists use it
if [ -f /config/pivproxy.conf ]; then
  cp /config/pivproxy.conf /etc/httpd/conf.d/00-pivproxy.conf
else # otherwise use the default	
  cp /apache/default-pivproxy.conf /etc/httpd/conf.d/00-pivproxy.conf
fi

# start apache in the foreground
/usr/sbin/httpd -DFOREGROUND