
cd ~/confluent-5.2.1; ./bin/kafka-server-start ./etc/kafka/server.properties
cd ~/confluent-5.2.1; ./bin/zookeeper-server-start ./etc/kafka/zookeeper.properties

cd ~/confluent-5.2.1; ./kafka-console-consumer --bootstrap-server localhost:9092 --zookeeper localhost:2181 --topic openolt.ind-10.90.0.122 --from-beginning

consul agent -dev

python voltha/main.py -v --consul=localhost:8500 --rest-port=8880 --grpc-port=50556  --interface=eth1 --backend=consul -v > voltha.log 2>&1

/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092
/opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic openolt.ind-10.90.0.12
