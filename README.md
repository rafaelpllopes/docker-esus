# Instalação do e-SUS PEC (Via Docker)
Passos para criar e usar o e-SUS PEC pelo docker

## Ambiente
* Docker
* Docker Compose
* [Baixar os arquivos que serão usados](https://github.com/rafaelpllopes/docker-esus/archive/refs/heads/main.zip)

### Criar as pastas sistemas e backups dentro da pasta do projeto
```
mkdir sistemas && mkdir backups
```
### Estrutura de diretorios e arquivos
```
.
├── application.properties
├── backups
├── cron-esusdb
├── docker-compose.yml
├── Dockerfile
├── esusbkp.sh
├── java.conf
├── log.txt
├── pg_hba.conf
├── pgpass
├── postgresql.conf
└── sistemas
```

## Criar Container do Banco de Dados Postgresql

### Dockerfile.postgresql
```
FROM jrei/systemd-ubuntu

ENV WORKSPACE=/home/esus/backups

ADD . $WORKSPACE
WORKDIR $WORKSPACE

RUN apt update \
    && apt upgrade -y \
    && apt install wget -y \
    && apt install software-properties-common -y \
    && apt install sudo -y \
    && apt install vim -y \
    && apt install unzip -y \
    && apt install htop -y \
    && apt install locales -y \
    && apt-get install tzdata -y \
    && apt install iproute2 -y \
    && locale-gen pt_BR.UTF-8

ENV export TZ='America/Sao_Paulo'

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt update \
    && apt install -y tzdata

RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - \
    && apt update \
    && apt install postgresql-9.6 postgresql-contrib-9.6 -y \
    && apt clean -y

RUN chown postgres:root -R /home/esus \
    && chmod 777 /home/esus

COPY ./esusbkp.sh /home/esus/esusbkp.sh
RUN chown postgres:root -R /home/esus
RUN chmod +x /home/esus/esusbkp.sh

COPY ./postgresql.conf /etc/postgresql/9.6/main/postgresql.conf
RUN chown postgres:postgres /etc/postgresql/9.6/main/postgresql.conf

COPY ./pg_hba.conf /etc/postgresql/9.6/main/pg_hba.conf
RUN chown postgres:postgres /etc/postgresql/9.6/main/pg_hba.conf

COPY ./cron-esusdb /etc/cron.d/cron-esusdb
RUN chown root:root /etc/cron.d/cron-esusdb \
    && chmod 644 /etc/cron.d/cron-esusdb

COPY ./pgpass /root/.pgpass
RUN chown postgres:root /root/.pgpass \
    && chmod 0600 /root/.pgpass

COPY ./log.txt /var/log/esus/log.txt
RUN chown postgres:root -R /var/log/esus/ \
    && chmod 774 /var/log/esus/log.txt

RUN systemctl enable postgresql && systemctl enable cron

CMD ["/sbin/init"]

EXPOSE 5432

```
### Construir a imagem
```
docker -f Dockerfile.postgresql -t esusdb .
```

### Subir o container
```
docker run -d -it --name database-esus -h database-esus --net=esus-rede  -p 5432:5432 --restart=always --privileged -v ${PWD}/backups:/home/esus/backups -v /sys/fs/cgroup:/sys/fs/cgroup:ro -e TZ='America/Sao_Paulo' esusdb /sbin/init
```

### Acessar o container
```
docker exec -it databaseesus /bin/bash
```
### Configurar o container

1. Entrar no usuario do postgres ```su postgres```
2. Entrar no psqp ```psql```
3. Criar o banco de dados: 
```
UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';
DROP DATABASE template1;
CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING='UNICODE' LC_COLLATE='pt_BR.UTF-8' LC_CTYPE='pt_BR.UTF-8';
UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';
UPDATE pg_database SET datallowconn = FALSE WHERE datname = 'template1';
ALTER user postgres with encrypted password 'esus';
CREATE DATABASE esus encoding 'UTF8';
```
4. Verificar se foi criado: 
```
\list

  Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 esus      | postgres | UTF8     | pt_BR.UTF-8 | pt_BR.UTF-8 |
```
5. Sair do psql ```\q```
6. Restaurar o backup "o arquivo deve estar na pastas backups" ```pg_restore 20210814000000-itapeva-sp.backup -d esus```

### Configurar o pg_hba.conf

1. Verificar qual o ip da rede esus-rede ```docker network inspect esus-rede```
2. Adicionar no arquivo pg_hba.config ```host    all             all             ip_da_rede (Ex. 172.17.0.0/24)           md5 ``` para liberar o acesso ao banco de dados

## Criar Container do Aplicação

### Dockerfile.spring

```
FROM jrei/systemd-ubuntu

ENV WORKSPACE=/home/esus/sistemas

ADD . $WORKSPACE
WORKDIR $WORKSPACE

RUN apt update \
    && apt upgrade -y \
    && apt install wget -y \
    && apt install software-properties-common -y \
    && apt install sudo -y \
    && apt install vim -y \
    && apt install unzip -y \
    && apt install htop -y \
    && apt install locales -y \
    && add-apt-repository ppa:openjdk-r/ppa -y

ENV export TZ='America/Sao_Paulo'

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt update \
    && apt install -y tzdata

RUN apt update && apt install openjdk-8-jdk -y \
    && apt clean -y

COPY ./java.conf /etc/java.conf
RUN chown root:root /etc/java.conf

COPY ./sistemas/ $WORKSPACE
RUN chown root:root -R $WORKSPACE \
    && chmod 755 /home/esus

COPY ./application.properties /opt/e-SUS/webserver/config/application.properties
RUN chown root:root /opt/e-SUS/webserver/config/application.properties \
    && chmod 644 /home/esus

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

CMD ["/sbin/init"]

EXPOSE 8080
```
### Construir a imagem
```
docker -f Dockerfile.spring -t esusspring .
```

### Subir o container
```
docker run -d -it --name esus-spring -h esus-spring --net=esus-rede -p 8080:8080 --restart=always --privileged -v ${PWD}/sistemas:/home/esus/sistemas -v /sys/fs/cgroup:/sys/fs/cgroup:ro -e TZ='America/Sao_Paulo' esusspring /sbin/init
```

### Acessar o container
```
docker exec -it esus-spring /bin/bash
```

### Instalar a aplicação

A aplicação deve estar na pasta ```/home/esus/sistemas/```, baixar no site da [APS](https://sisaps.saude.gov.br/esus/)

```java -jar eSUS-AB-PEC-4.2.8-Linux64.jar -console -url="jdbc:postgresql://database-esus:5432/esus" -username="postgres" -password="esus"```

## Criar docker compose

Usar  com docker-compose, usar ele antes de realizar as etapas de subir os containers e configurar

### Criar o arquivo docker-compose.yml

```
version: "3.1"
services:
    esus:
        image: esusspring
        restart: always
        container_name: esus-spring
        hostname: esus-spring
        ports:
            - 8080:8080
        environment:
            - TZ='America/Sao_Paulo'
        privileged: true
        volumes:
            - ./application.properties:/opt/e-SUS/webserver/config/application.properties
            - ./sistemas:/home/esus/sistemas
            - /sys/fs/cgroup:/sys/fs/cgroup:ro
        command: /sbin/init
        depends_on:
            - database
    database:
        image: esusdb
        restart: always
        container_name: database-esus
        hostname: database-esus
        ports:
            - 5432:5432
        environment:
            - TZ='America/Sao_Paulo'
        privileged: true
        volumes:
            - ./backups:/home/esus/backups
            - /sys/fs/cgroup:/sys/fs/cgroup:ro
        command: /sbin/init
networks:
    esus-rede:
```

### Subir os container pelo docker compose
```docker-compose up -d```
