## 1. Create certificate authority (CA)
openssl req -new -x509 -keyout ca-key -out ca-cert -days 365 -passin pass:qwerrewq -passout pass:qwerrewq -subj "/CN=kafka-0.kafka-headless.default.svc.roham.pinsvc.net/OU=DevOps/O=snapp/L=FA/ST=Tehran/C=IR"

## 2. Create client keystore
keytool -noprompt -keystore kafka.client.keystore.jks -genkey -alias localhost -dname "CN=kafka-0.kafka-headless.default.svc.roham.pinsvc.net, OU=DevOps, O=snapp, L=FA, ST=Tehran, C=Iran" -storepass qwerrewq -keypass qwerrewq

## 3. Sign client certificate
keytool -noprompt -keystore kafka.client.keystore.jks -alias localhost -certreq -file cert-unsigned -storepass qwerrewq
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-unsigned -out cert-signed -days 365 -CAcreateserial -passin pass:qwerrewq

## 4. Import CA and signed client certificate into client keystore
keytool -noprompt -keystore kafka.client.keystore.jks -alias CARoot -import -file ca-cert -storepass qwerrewq
keytool -noprompt -keystore kafka.client.keystore.jks -alias localhost -import -file cert-signed -storepass qwerrewq

## 5. Import CA into client truststore (only for debugging with producer / consumer utilities)
keytool -noprompt -keystore kafka.client.truststore.jks -alias CARoot -import -file ca-cert -storepass qwerrewq

## 6. Import CA into server truststore
keytool -noprompt -keystore kafka.server.truststore.jks -alias CARoot -import -file ca-cert -storepass qwerrewq

## 7. Create PEM files for app clients
mkdir -p ssl

## 8. Create server keystore
keytool -noprompt -keystore kafka.server.keystore.jks -genkey -alias kafka-0.kafka-headless.default.svc.roham.pinsvc.net -dname "CN=kafka-0.kafka-headless.default.svc.roham.pinsvc.net, OU=DevOps, O=snapp, L=FA, ST=Tehran, C=Iran" -storepass qwerrewq -keypass qwerrewq

## 9. Sign server certificate
keytool -noprompt -keystore kafka.server.keystore.jks -alias kafka-0.kafka-headless.default.svc.roham.pinsvc.net -certreq -file cert-unsigned -storepass qwerrewq
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-unsigned -out cert-signed -days 365 -CAcreateserial -passin pass:qwerrewq

## 10. Import CA and signed server certificate into server keystore
keytool -noprompt -keystore kafka.server.keystore.jks -alias CARoot -import -file ca-cert -storepass qwerrewq
keytool -noprompt -keystore kafka.server.keystore.jks -alias kafka-0.kafka-headless.default.svc.roham.pinsvc.net -import -file cert-signed -storepass qwerrewq

### Extract signed client certificate
keytool -noprompt -keystore kafka.client.keystore.jks -exportcert -alias localhost -rfc -storepass qwerrewq -file ssl/client_cert.pem

### Extract client key
keytool -noprompt -srckeystore kafka.client.keystore.jks -importkeystore -srcalias localhost -destkeystore cert_and_key.p12 -deststoretype PKCS12 -srcstorepass qwerrewq -storepass qwerrewq
openssl pkcs12 -in cert_and_key.p12 -nocerts -nodes -passin pass:qwerrewq -out ssl/client_key.pem

### Extract CA certificate
keytool -noprompt -keystore kafka.client.keystore.jks -exportcert -alias CARoot -rfc -file ssl/ca_cert.pem -storepass qwerrewq


cp  kafka.server.truststore.jks kafka.truststore.jks

cp kafka.server.keystore.jks kafka-0.keystore.jks


kubectl create secret generic hatch-ca --from-file=./kafka.server.truststore.jks --from-file=./kafka.server.keystore.jks --from-file=./ca-cert --from-file=ca-key  --dry-run=true -o yaml | kubectl apply -f -

helm install --name kafka -f  kafka/values.yaml kafka/