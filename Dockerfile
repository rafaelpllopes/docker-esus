#----------------------- E-SUS POSTGRESQL -----------------------
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
    && apt install iputils-ping -y \
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

#----------------------- E-SUS SPRING -----------------------

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
    && apt install iproute2 -y \
    && apt install iputils-ping -y \
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
