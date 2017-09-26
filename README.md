# A Containerized x509/PIV/CAC Proxy for Authentication in OpenShift

## Prerequisites
* Certificate Material for Authentication Endpoint
  * Private Key (ex: hostname.key)
  * Public Cert (ex: hostname.crt)
  * Certificate Authority chain (ex: ca.crt)
* Certificate Authority chain for verifying the client's smart card token (PIV/CAC)
  * Generally issued by the identification granting agency
  * Must be _all_ of the required authorities concatenated into one file

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

### Create the Client Secret

### Create the Smartcard CA Secret
You will need to copy the issued CA that contains the trust for all of the authorized smart cards to a machine that has the `oc` client installed. Then you will use that material to create the target secret. 

```bash
[]$ oc secret new ose-pivproxy-smartcard-ca smartcard-ca.crt=/path/to/smartcard-ca-chain-file.crt
```

### Create the PKI Secret for TLS

### Apply and Use the Build Configuration Template
```bash
[]$ oc apply -f ./ose-pivproxy-build-template.yml
[]$ oc process ose-pivproxy-build | oc apply -f -
[]$ oc start-build ose-pivproxy-bc
```

These commands can be run any time the build template is changed.

### Apply and Use the Application Template
```bash
[]$ oc apply -f ./ose-pivproxy-deployment-template.yml
[]$ oc new-app --template=ose-pivproxy -p P_PIVPROXY_PUBLIC_URL=<public pivproxy url> -p P_MASTER_PUBLIC_URL=<public master url>
[]$ oc rollout latest dc/ose-pivproxy
```

These commands can be run any time the deployment template is changed. You can run `oc delete dc/ose-pivproxy svc/ose-pivproxy route/ose-pivproxy` at any time to clean up the deployment so that it can be removed or recreated.