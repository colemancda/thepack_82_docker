FROM mysql:5.7
ADD thepack.sql /docker-entrypoint-initdb.d
ADD mysqld.cnf /etc/mysql/conf.d/
ENV MYSQL_ROOT_PASSWORD=root
EXPOSE 3306
