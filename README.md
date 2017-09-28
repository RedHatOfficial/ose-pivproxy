# Containerized x509/PIV/CAC Proxy for Authentication in OpenShift

## Requirements
* SSH access to **at least one** Master node
  * Sudo or root access on that node
* Certificate Material for Authentication Endpoint
  * Private Key (ex: hostname.key)
  * Public Cert (ex: hostname.crt)
  * Certificate Authority chain (ex: ca.crt)
* Certificate Authority chain for verifying the client's smart card token (PIV/CAC)
  * Generally issued by the identification granting agency
  * Must be **all** of the required authorities concatenated into one file
  * Must be the **entire** trust chain as well; all the way to the root

## Variables
Variables in this document are denoted with `<variable>`. These are items that the user/configurer should be careful to note as they may not have defaults. There are two variables that are required to complete the configuration and have _no_ default value.
* **`<public pivproxy url>`** - the publicly accessible URL for the PIV proxy created in this guide. The master console _will redirect_ traffic to this URL when a login is required. This URL must be accessible and routable by clients neededing to authenticate. Typically this would follow the application name, namespace, and cloud DNS base pattern. You could create a custom route for it if your hosting environment can support that.
* **`<public master url>`** - the public URL used by clients to reach the master console. The PIV proxy will need to redirect traffic from itself to this URL to complete the authentication process.

_Be sure to replace any instance of these variables in the below documentation with your own site-specific values._

## Instructions

These instructions are written using examples. You do not need to use the same examples but you can modify them as needed. The default project namespace is named `pivproxy` but any other namespace can be used as long as the appropriate changes are made.

### Identify the Target Namespace
```bash
[]$ oc projects
You have access to the following projects and can switch between them with 'oc project <projectname>':

    default
    kube-public
    kube-system
    myproject - My Project
    openshift
    openshift-infra
  * pivproxy

Using project "default" on server "..."
[]$ oc project pivproxy
Now using project "pivproxy" on server "..."
```

If you need to create the project:
```bash
[]$ oc new-project pivproxy
```

### Create the PIV Proxy Client PKI Secret
In order to create a trusted communication channel between the server and the client there needs to be a set of PKI for the client (in this case the PIV proxy) to contact the target master. The master must also trust this communication and can be configured to allow only communication from this source. This prevents some third party from setting up their own authentication server and, through various forms of manipulation, using it as a fake source of authentication information.

These commands must be performed on any **ONE** master node as root (`sudo -i`).
```bash
[]$ export PIV_SECRET_BASEDIR=/etc/origin/proxy
[]$ mkdir -p $PIV_SECRET_BASEDIR
[]$ oc adm ca create-signer-cert \
    --cert=$PIV_SECRET_BASEDIR/proxyca.crt \
    --key=$PIV_SECRET_BASEDIR/proxyca.key \
    --name='openshift-proxy-signer@`date +%s`' \
    --serial=$PIV_SECRET_BASEDIR/proxyca.serial.txt
[]$ oc adm create-api-client-config \
    --certificate-authority=$PIV_SECRET_BASEDIR/proxyca.crt \
    --client-dir=$PIV_SECRET_BASEDIR \
    --signer-cert=$PIV_SECRET_BASEDIR/proxyca.crt \
    --signer-key=$PIV_SECRET_BASEDIR/proxyca.key \
    --signer-serial=$PIV_SECRET_BASEDIR/proxyca.serial.txt \
    --user='system:proxy'
[]$ cat $PIV_SECRET_BASEDIR/system\:proxy.crt \
      $PIV_SECRET_BASEDIR/system\:proxy.key \
      > $PIV_SECRET_BASEDIR/piv_proxy.pem
```
_Note: these commands can actually be executed **anywhere** but executing them on the first master is considerably easier when it has the `oc` client installed already. In that case you can adjust the paths so that they are in a temporary or local directory like `./proxy`._


Then copy the files from the `/etc/origin/proxy` directory to each other master.
```bash
[]$ scp /etc/origin/proxy master2:/etc/origin/proxy
[]$ scp /etc/origin/proxy master3:/etc/origin/proxy
```
_Note: this is not strictly necessary but keeps the files available in case they need to be reused or client material needs to be regenerated._

Then copy the `piv_proxy.pem` to the node that the following commands will be executed from. These commands can be performed anywhere there is an `oc` client installed or they can be performed right on the master. **Also** copy the master's CA from `/etc/origin/master/ca.crt`.
```bash
[]$ scp master1:/etc/origin/proxy/piv_proxy.pem /local/path/to/piv_proxy.pem
[]$ scp master1:/etc/origin/master/ca.crt /local/path/to/master-ca.crt
[]$ oc secret new ose-pivproxy-client-secrets piv_proxy.pem=/local/path/to/piv_proxy.pem master-ca.crt=/local/path/to/master-ca.crt
```

### Create the Smartcard CA Secret
You will need to copy the issued CA that contains the trust for all of the authorized smart cards to a machine that has the `oc` client installed. Then you will use that material to create the target secret. The trust should be _all_ of the potential certificates that are used to sign the tokens (x509/PIV/CAC) that will be presented by authorized users. These certificates _must_ be concatenated into one file.

```bash
[]$ cat smartcard-issuer-1.crt >> /path/to/smartcard-ca-chain-file.crt
[]$ cat smartcard-issuer-2.crt >> /path/to/smartcard-ca-chain-file.crt
[]$ oc secret new ose-pivproxy-smartcard-ca smartcard-ca.crt=/path/to/smartcard-ca-chain-file.crt
```

### Apply and Use the Build Configuration Template
```bash
[]$ oc apply -f ./ose-pivproxy-build-template.yml
[]$ oc process ose-pivproxy-build | oc apply -f -
[]$ oc start-build ose-pivproxy-bc
```

These commands can (and should) be run any time the build template is changed to reflect any updates.

### Apply and Use the Application Template
```bash
[]$ oc apply -f ./ose-pivproxy-deployment-template.yml
[]$ oc new-app --template=ose-pivproxy -p P_PIVPROXY_PUBLIC_URL=<public pivproxy url> -p P_MASTER_PUBLIC_URL=<public master url>
[]$ oc rollout latest dc/ose-pivproxy
```

These commands can be run any time the deployment template is changed. You can run `oc delete dc/ose-pivproxy svc/ose-pivproxy route/ose-pivproxy` at any time to clean up the deployment so that it can be removed or recreated.

### Use Site-Specific Certificates for HTTPS/TLS
In order to have trusted site-specific certificates you will need to gather three pieces of information for the eventual route to serve the proper TLS connection. The application uses a passthrough route because of the client certificate authorization on the application side. This means that, among other things, the server certificates provided **must** have the proper hostname in **both** the CN **and** the alternative name list. _Failure to have proper TLS certificates will result in a non-working PIV proxy._

There are three pieces of required material:
* The server certificate for the hostname
* The server private key matching the certificate
* The CA chain file that provides the trust chain for the server certificate

**If you do not have server certificates you can create them easily with the `oc` command**. (From a master node.)
```bash
[]$ oc adm ca create-server-cert \
    --cert='/etc/origin/proxy/<public pivproxy url>.crt' \
    --key='/etc/origin/proxy/<public pivproxy url>.key' \
    --hostnames=<public pivproxy url>,ose-pivproxy.svc,ose-pivproxy.pivproxy.svc,ose-pivproxy.pivproxy.svc.default.local \
    --signer-cert=/etc/origin/master/ca.crt \
    --signer-key='/etc/origin/master/ca.key' \
    --signer-serial='/etc/origin/master/ca.serial.txt'
```

You can verify that the server certificate is correct by checking the subject alternate name provided.
```bash
[]$ openssl x509 -in /path/to/<public pivproxy url>.crt -noout -text | grep
  X509v3 Subject Alternative Name:                                    
    DNS:<public pivproxy url>, DNS:<another expected host name>
```

_If the "DNS:" entries are not present or do not match the expected route the certificates will need to be reissued._

Now you can recreate the secret `ose-pivproxy-certs` and override the secrets that were automatically generated when the server was created. These commands will create a new secret in place of the old one. 
```bash
[]$ oc get secret/ose-pivproxy-certs -o yaml > ose-pivproxy-certs.yml.backup
[]$ oc delete secret/ose-pivproxy-certs
[]$ oc secret new ose-pivproxy-certs tls.key=/path/to/hostname.key tls.crt=/path/to/hostname.crt
```

Once the new secret is in place the application should be redeployed.

```bash
[]$ oc rollout latest dc/ose-pivproxy
```

### Configure Master(s) to use PIV Proxy

The following identitiy provider needs to be added to the OCP master configuration. On each of the master nodes edit `/etc/origin/master/master-config.yaml` and add the following yaml to the `identityProviders` block as shown.

```yaml
identityProviders:
  - name: "ocp_pivproxy"
    challenge: true
    login: true
    mappingMethod: add
    provider:
      apiVersion: v1
      kind: RequestHeaderIdentityProvider
      challengeURL: "https://<public pivproxy url>/challenging-proxy/oauth/authorize?${query}"
      loginURL: "https://<public pivproxy url>/login-proxy/oauth/authorize?${query}"
      clientCA: /etc/origin/proxy/proxyca.crt
      clientCommonNames:
       - <public master url>
       - system:proxy
      headers:
      - X-Remote-User
```

Once this is added, restart the master. _If there is more than one master then each master must be editied and restarted._

## Troubleshooting
There is a value, which defaults to `info` that can be set in `dc/ose-pivproxy`. This will allow for changing the Apache log level. You can set it to any of the valid values for Apache but something like `debug` or `trace1` through `trace8` would provide the most detail.

```bash
[]$ oc set env dc/ose-pivproxy PROXY_LOG_LEVEL=debug
```

This will cause the application to redeploy and there will be more information in the logs.