#!/bin/bash

export WMSAPP_HOME="$( readlink /usr/local/WowzaStreamingEngine )"
export WSE_MGR_P12=${WMSAPP_HOME}/manager/conf/keystore.p12
export WSE_MGR_JKS=${WMSAPP_HOME}/manager/conf/keystore.jks
export WSE_MGR_KS_PASSWORD=${WMSAPP_HOME}/manager/conf/keystore.passwd

if [ "x${WSE_MGR_TLS_CERT}" = "x" ]; then
    echo "No variable setting: WSE_MGR_TLS_CERT".
    exit 1
fi

if [ ! -f ${WSE_MGR_KS_PASSWORD} ]; then
    openssl rand -base64 15 > ${WSE_MGR_KS_PASSWORD}
fi
export PASS=`cat ${WSE_MGR_KS_PASSWORD}`

# Enable SSL for Wowza Streaming Engine Manager
if [ -d ${WSE_MGR_TLS_CERT} ]; then

    if [ -f ${WSE_MGR_TLS_CERT}/tls.crt -a -f ${WSE_MGR_TLS_CERT}/tls.key ]; then

        rm -f ${WSE_MGR_P12} ${WSE_MGR_JKS}
        openssl pkcs12 -export -legacy -in ${WSE_MGR_TLS_CERT}/tls.crt -inkey ${WSE_MGR_TLS_CERT}/tls.key -out ${WSE_MGR_P12} -password pass:${PASS}
        ${WMSAPP_HOME}/java/bin/keytool -importkeystore \
            -destkeystore ${WSE_MGR_JKS} -deststoretype jks -deststorepass ${PASS} \
            -srckeystore ${WSE_MGR_P12} -srcstoretype pkcs12 -srcstorepass ${PASS}

        cat > ${WMSAPP_HOME}/manager/conf/tomcat.properties <<EOF
httpsPort=8090
httpsKeyStore=conf/keystore.jks
httpsKeyStorePassword=${PASS}
EOF

    fi
fi
