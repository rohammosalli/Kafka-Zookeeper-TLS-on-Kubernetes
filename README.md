#### Kafka and Zookeeper deployments with TLS on Kubernetes 

###### Self Hosted Cluster
I used this link High Available Kubernetes Cluster Setup using Kubespray to deploy my cluster on Scaleway

1 - One node Worker/Master

Best Practice is 3 Master Node and 3 Worker Node at minimum

Note :

1 - If you experience highly load traffic in your cluster you should take care of out of-resource handling in Kubelet, you have to reserve some memory and CPU for nodes because if you don't, the nodes in under pressure kernel will kill the process, so this means you will lose your node or even the cluster.

2 - If you use Master Node alos as worker Please don't do it.

###### Setting up Helm


Helm initialized to work with clusters

```bash
kubectl delete --namespace kube-system svc tiller-deploy
kubectl delete --namespace kube-system deploy tiller-deploy
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
helm init --service-account tiller --upgrade

```

###### Secret CA (self-generated Certificate Authority key and certificate)

I used this domain kafka-0.kafka-headless.default.svc.roham.pinsvc.net for generating certificate thus URL accessible inside the cluster 

```bash
chmod +x tls.sh 

./ tls

after this script run, it will generate jks files and some pem file  in SSL folder that application can use for authenticating to Kafka I also generated Kafka clients jks for sure 

mv kafka.server.truststore.jks kafka.truststore.jks
mv kafka.server.keystore.jks kafka-0.keystore.jks

```
NOTE: 

How make tls.sh automated with helm charts 

To make this happen we can use initContainers inside statefulset and one image ```that has access to the cluster ``` to deploy secret file 

```yaml
 spec:
   initContainers:
   - name: gangway-certs
     image: yourimage:tag
     imagePullPolicy: Always
     command:
     - sh
     - -c
     - ./tls.sh
     - mv kafka.server.truststore.jks kafka.truststore.jks
     - mv kafka.server.keystore.jks kafka-0.keystore.jks
     - kubectl create secret generic kafka-ssl --from-file=./kafka.server.truststore.jks --from-file=./kafka.server.keystore.jks --from-file=./ca-cert --from-file=ca-key
    volumeMounts:
    - mountPath: /certs/
      name: hatch-ca
```

###### NOTE 
I also Included ca to the hatch-ca so that's mean if you have the plan to generate a certificate for other services base on this ca you can make an issuer like this

We can now create an Issuer referencing the Secret resource we just created


```yaml
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
  name: ca-issuer
  namespace: default
spec:
  ca:
    secretName: hatch-ca  
```    


###### create secret file on kubernetes 

```bash
kubectl create secret generic hhatch-ca --from-file=trust/
```

###### NOTE: 

for customizing your deployment you can change anything you want on the helm charts in values file, to deploy Kafka and zookeeper you need to just run this command 


####### NOTE 
  1 - I didn't use any storage for Kafka and zookeeper because of my environment but to have Kafka in Kubernetes base on best practice  you need o good and stable storage 
```bash
helm install --name kafka -f  values.yaml .
```

###### config values for tls auth for kafka 


1 - you need config cluster domain in values for me is roham.pinsvc.net

2 - you have to enable tls in auth 

```yaml
auth:
  clientProtocol: tls
  interBrokerProtocol: tls
  jksSecret: hatch-ca
  ## Password to access the JKS files when they are password-protected.
  jksPassword: qwerrewq 
  tlsEndpointIdentificationAlgorithm: https
```
###### config values for tls auth for zookeper base on same certificate 

```yaml
service:
  type: ClusterIP
  port: 2181
  followerPort: 2888
  electionPort: 3888
  publishNotReadyAddresses: true
  tls:
    client_enable: true
    client_port: 3181
    client_keystore_path: /certs/truststore/kafka-0.keystore.jks
    client_keystore_password: "qwerrewq"
    client_truststore_path: /certs/truststore/kafka.truststore.jks
    client_truststore_password: "qwerrewq"

  extraVolumes:
  - name: zookeeper-truststore
    secret:
      defaultMode: 288
      secretName: hatch-ca
  extraVolumeMounts:
   - name: zookeeper-truststore
     mountPath: /certs/truststore
     readOnly: true
```

###### Test our kafka 

after Kafka deployed we can test it with SSL authenticate 


```bash
kubectl exec -it kafka-0 bash 

cd  /opt/bitnami/kafka/bin

cat > client-ssl.properties <<EOL   
bootstrap.servers=kafka-0.kafka-headless.default.svc.roham.pinsvc.net
security.protocol=SSL
ssl.truststore.location=/certs/kafka.truststore.jks
ssl.truststore.password=qwerrewq
ssl.keystore.location=/certs/kafka-0.keystore.jks
ssl.keystore.password=qwerrewq
ssl.key.password=qwerrewq
EOL


./kafka-console-producer.sh --broker-list kafka-0.kafka-headless.default.svc.roham.pinsvc.net:9093 --topic test --producer.config client-ssl.properties 


./kafka-console-consumer.sh --bootstrap-server kafka-0.kafka-headless.default.svc.roham.pinsvc.net:9093 --topic test --from-beginning --consumer.config client-ssl.properties

```


### explain security concerns and solution

1 - it's good for us if we use vault for certificates and secrets to manage 
2 - to have an end to end encryption between services we can use Service mesh like Istio 
