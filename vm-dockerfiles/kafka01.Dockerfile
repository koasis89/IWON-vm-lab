# Source priority: helm_bak_20260318/dev-vm-FINAL-TOTAL-BACKUP.yaml
FROM quay.io/strimzi/kafka:0.50.0-kafka-4.1.1

EXPOSE 9092
CMD ["/opt/kafka/kafka_run.sh"]
