# Source priority: backup/db/values.yaml (bitnami/mariadb)
FROM bitnami/mariadb:latest

EXPOSE 3306
CMD ["/opt/bitnami/scripts/mariadb/run.sh"]
