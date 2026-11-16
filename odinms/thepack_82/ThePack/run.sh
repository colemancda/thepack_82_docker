#!/usr/bin/env bash

THIS_IP=`grep $HOSTNAME /etc/hosts | awk '{print $1}'`

# --- Regenerate the SSL keystore used for inter-server RMI ---
# The shipped filename.keystore has no SubjectAlternativeName, CN=a, SHA1, and
# expired in 2009; modern JDK 8u enforces SAN hostname identity on RMI-over-SSL,
# which crashed Login/Channel. Regenerate with SAN=127.0.0.1 (all servers share
# this container and talk over localhost) and SHA256.
rm -f filename.keystore
keytool -genkeypair -noprompt -alias odinms -keyalg RSA -keysize 2048 -sigalg SHA256withRSA \
  -dname "CN=localhost, OU=odinms, O=odinms, L=local, ST=local, C=US" \
  -ext "san=ip:127.0.0.1,dns:localhost" \
  -validity 3650 -keystore filename.keystore -storepass passwd -keypass passwd

# Point MySQL at the DB container; point all inter-server RMI + the client-facing
# channel interface at 127.0.0.1 so they match the keystore SAN.
sed -i "s/ODINMS_MYSQL_CONTAINER_IP_ADDRESS/$ODINMS_MYSQL_CONTAINER_IP_ADDRESS/" db.properties
sed -i "s/THIS_IP/127.0.0.1/" world.properties
sed -i "s/THIS_IP/127.0.0.1/" login.properties
sed -i "s/THIS_IP/127.0.0.1/" channel.properties

RMI="-Djava.rmi.server.hostname=127.0.0.1"
SSL="-Djavax.net.ssl.keyStore=filename.keystore -Djavax.net.ssl.keyStorePassword=passwd -Djavax.net.ssl.trustStore=filename.keystore -Djavax.net.ssl.trustStorePassword=passwd"
OPS="-Dnet.sf.odinms.recvops=recvops.properties -Dnet.sf.odinms.sendops=sendops.properties -Dnet.sf.odinms.wzpath=wz"
HEAP="-Xms64m -Xmx256m"

java -cp '.:dist/*' $HEAP $OPS $RMI $SSL net.sf.odinms.net.world.WorldServer &
sleep 10
java -cp '.:dist/*' $HEAP $OPS $RMI -Dnet.sf.odinms.login.config=login.properties $SSL net.sf.odinms.net.login.LoginServer &
sleep 10
java -cp '.:dist/*' $HEAP $OPS $RMI -Dnet.sf.odinms.channel.config=channel.properties $SSL net.sf.odinms.net.channel.ChannelServer &
