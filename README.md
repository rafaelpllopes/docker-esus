# Instalação do e-SUS PEC (Via Docker)
Passos para criar e usar o e-SUS PEC pelo docker

## Ambiente
* Docker
* Docker Compose
* [Baixar os arquivos que serão usados](https://github.com/rafaelpllopes/docker-esus/archive/refs/heads/main.zip)

### Criar as pastas necessarias do projeto
```
mkdir -p sistemas backups pgdata chaves
```
### Estrutura de diretorios e arquivos
```
.
├── application.properties
├── backups
├── chaves
├── cron-esusdb
├── docker-compose.yml
├── Dockerfile-esus
├── Dockerfile-postgres
├── esusbkp.sh
├── init-db.sh
├── java.conf
├── log.txt
├── pgdata
├── pgpass
├── README.md
└── sistemas
```

## Criar Container do Banco de Dados Postgresql

### Dockerfile.postgres
```
FROM postgres:9.6

# Configura locale pt_BR (se disponível na imagem base)
RUN set -ex; \
    if ! localedef -i pt_BR -c -f UTF-8 -A /usr/share/locale/locale.alias pt_BR.UTF-8; then \
        echo "Locale pt_BR.UTF-8 não pôde ser criado, continuando com locale padrão"; \
    fi

# Script de inicialização personalizado
COPY init-db.sh /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/init-db.sh

ENV LANG=pt_BR.UTF-8 \
    LC_ALL=pt_BR.UTF-8 \
    POSTGRES_PASSWORD=esus
```
### Construir a imagem
```
docker build -f Dockerfile-postgres -t esusdb . --no-cache
```

### Subir o container (Recomendo)
```
docker run -d \
  --name esus-db \
  --hostname esus-db \
  --network rede-esus \
  -p 5433:5432 \
  --restart=always \
  -e POSTGRES_DB=esus \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=esus \
  -e TZ=America/Sao_Paulo \
  -e LC_ALL=pt_BR.UTF-8 \
  -v $(pwd)/pgdata:/var/lib/postgresql/data \
  -v $(pwd)/backups:/home/esus/backups \
  --restart unless-stopped \
  esusdb
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

### Dockerfile.esus

```
FROM antmelekhin/docker-systemd:debian-11

# Define variáveis de ambiente
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=pt_BR.UTF-8 \
    TZ=America/Sao_Paulo

# Instala dependências básicas em etapas separadas para melhor debug
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    gnupg2 \
    lsb-release \
    locales \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Instala pacotes systemd separadamente
RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd \
    systemd-sysv \
    dbus \
    && rm -rf /var/lib/apt/lists/*

# Instala outros pacotes necessários
RUN apt-get update && apt-get install -y --no-install-recommends \
    apparmor \
    procps \
    file \
    udisks2 \
    network-manager \
    && rm -rf /var/lib/apt/lists/*

# Configura locale e timezone
RUN echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen pt_BR.UTF-8 && \
    update-locale LANG=pt_BR.UTF-8 && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

# Adiciona repositório do Zulu OpenJDK 8
RUN wget -qO - https://repos.azul.com/azul-repo.key | gpg --dearmor -o /usr/share/keyrings/zulu.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/zulu.gpg] https://repos.azul.com/zulu/deb stable main" > /etc/apt/sources.list.d/zulu.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends zulu8-jdk && \
    rm -rf /var/lib/apt/lists/*

# Define JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/zulu8

# Cria diretórios necessários
RUN mkdir -p /opt/e-SUS/webserver/config /home/esus/sistemas && \
    chmod 755 /home/esus

WORKDIR /home/esus/sistemas

# Copia arquivos de configuração
COPY ./java.conf /etc/java.conf
COPY ./application.properties /opt/e-SUS/webserver/config/application.properties

# Ajusta permissões
RUN chown root:root /etc/java.conf /opt/e-SUS/webserver/config/application.properties

VOLUME ["/sys/fs/cgroup"]

EXPOSE 8080

CMD ["/sbin/init"]
```
### Construir a imagem
```
docker build -f Dockerfile-esus -t esusapp . --no-cache
```

### Subir o container (Recomendo)
```
docker run -d -it --privileged \
  --name esus-app \
  -h esus-app \
  -p 8080:8080 \
  --restart=always \
  --cgroupns=host \
  --tmpfs /run \
  --tmpfs /run/lock \
  --net=rede-esus \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -v $(pwd)/chaves/:/opt/e-SUS/webserver/chaves/:rw \
  -v $(pwd)/application.properties:/opt/e-SUS/webserver/config/application.properties:rw \
  -v $(pwd)/sistemas/:/home/esus/sistemas/:rw \
  -e TZ='America/Sao_Paulo' \
  esusapp \
  /lib/systemd/systemd
```

### Acessar o container
```
docker exec -it esus-spring /bin/bash
```

### Instalar a aplicação

A aplicação deve estar na pasta ```/home/esus/sistemas/```, baixar no site da [APS](https://sisaps.saude.gov.br/esus/)

```java -jar eSUS-AB-PEC-5.4.8-Linux64.jar -console -url="jdbc:postgresql://esus-db:5432/esus" -username="postgres" -password="esus"```

## Criar docker compose

Usar  com docker-compose, usar ele antes de realizar as etapas de subir os containers e configurar

### Criar o arquivo docker-compose.yml

```
version: '3.8'

services:
  esus-db:
    image: esusdb
    container_name: esus-db
    hostname: esus-db
    environment:
      POSTGRES_DB: esus
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: esus
      TZ: America/Sao_Paulo
      LC_ALL: pt_BR.UTF-8
    volumes:
      - ./pgdata:/var/lib/postgresql/data
      - ./backups:/home/esus/backups
    ports:
      - "5433:5432"
    networks:
      - rede-esus
    restart: unless-stopped

  esus-app:
    image: esusapp
    container_name: esus-app
    privileged: true
    hostname: esus-app
    restart: unless-stopped
    command: /lib/systemd/systemd
    ports:
      - "8080:8080"
    networks:
      - rede-esus
    tmpfs:
      - /run
      - /run/lock
      - /run/systemd
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - ./chaves/:/opt/e-SUS/webserver/chaves/:rw
      - ./application.properties:/opt/e-SUS/webserver/config/application.properties:rw
      - ./sistemas/:/home/esus/sistemas/:rw
    environment:
      - TZ=America/Sao_Paulo

networks:
  rede-esus:
```

### Subir os container pelo docker compose
```docker-compose up -d```
