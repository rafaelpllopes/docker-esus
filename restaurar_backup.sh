#!/bin/bash

# Configurações
PG_HOST="esus-db"
PG_PORT="5432"
PG_USER="postgres"
PG_PASS="esus"
BACKUP_DIR="/home/esus/backups"
PG_DATABASE="esus"

# Função para listar backups disponíveis
list_backups() {
    echo "Backups disponíveis em $BACKUP_DIR:"
    ls -lt "$BACKUP_DIR"/*.backup 2>/dev/null | awk -F/ '{print $NF}'
}

# Aguarda o PostgreSQL estar pronto
while ! pg_isready -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER"; do
    echo "Aguardando PostgreSQL..."
    sleep 5
done

# Verifica se o usuário passou um backup específico
if [ -n "$1" ]; then
    BACKUP_FILE="$BACKUP_DIR/$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "Erro: Backup '$1' não encontrado em $BACKUP_DIR!"
        list_backups
        exit 1
    fi
else
    # Seleciona o backup mais recente
    BACKUP_FILE=$(ls -t "$BACKUP_DIR"/*.backup 2>/dev/null | head -n 1)
    if [ -z "$BACKUP_FILE" ]; then
        echo "Erro: Nenhum backup (.backup) encontrado em $BACKUP_DIR!"
        exit 1
    fi
    echo "Usando o backup mais recente: $(basename "$BACKUP_FILE")"
fi

# Configuração do template1 e preparação do banco
export PGPASSWORD="$PG_PASS"
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" <<-EOSQL
    UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';
    DROP DATABASE IF EXISTS template1;
    CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING='UNICODE' LC_COLLATE='pt_BR.UTF-8' LC_CTYPE='pt_BR.UTF-8';
    UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';
    UPDATE pg_database SET datallowconn = FALSE WHERE datname = 'template1';
    ALTER USER postgres WITH ENCRYPTED PASSWORD 'esus';
    DROP DATABASE IF EXISTS "$PG_DATABASE";
    CREATE DATABASE "$PG_DATABASE" ENCODING 'UTF8';
EOSQL

# Restaura o backup com limpeza prévia
echo "Restaurando $BACKUP_FILE..."
pg_restore --verbose --clean --if-exists \
    -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" "$BACKUP_FILE"

echo "Restaurado $BACKUP_FILE"
echo "✅ Restauração concluída!"