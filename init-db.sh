#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';
    DROP DATABASE template1;
    CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING='UNICODE' LC_COLLATE='pt_BR.UTF-8' LC_CTYPE='pt_BR.UTF-8';
    UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';
    UPDATE pg_database SET datallowconn = FALSE WHERE datname = 'template1';
    ALTER USER postgres WITH ENCRYPTED PASSWORD 'esus';
    CREATE DATABASE esus ENCODING 'UTF8' LC_COLLATE 'pt_BR.UTF-8' LC_CTYPE 'pt_BR.UTF-8';
EOSQL