#!/bin/sh
JAVA_OPTS="-Xms2048M -Xmx4096M -XX:MetaspaceSize=256M -XX:MaxMetaspaceSize=512M -XX:ReservedCodeCacheSize=512M"
JAVA_OPTS="$JAVA_OPTS -Djava.net.preferIPv4Stack=true"
JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"
JAVA_OPTS="$JAVA_OPTS -Djava.awt.headless=true -XX:CompressedClassSpaceSize=256M -Djboss.threads.eqe.statistics.active-count=true"

BUNDLE_HOME=$(dirname $0)
PEC_HOME=$(readlink -e $BUNDLE_HOME/..)
JAVA_HOME=$PEC_HOME/jre/current

CERTMGR_HOME=$BUNDLE_HOME/certmgr
CERTMGR_CONFIG_FILE=$CERTMGR_HOME/config/ssl.properties
if [ -f "$CERTMGR_CONFIG_FILE" ]; then
    export SPRING_CONFIG_ADDITIONAL_LOCATION=$CERTMGR_CONFIG_FILE
    cd $CERTMGR_HOME
    $JAVA_HOME/bin/java -jar $CERTMGR_HOME/certmgr.jar --renew
fi

cd $BUNDLE_HOME
$JAVA_HOME/bin/java -jar $JAVA_OPTS $BUNDLE_HOME/pec-bundle.jar