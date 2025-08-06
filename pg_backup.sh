#!/bin/bash

chmod 0600 /root/.pgpass

TIME_BKCP=+7
DSTDIR=/backups
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_FILE="/backups/${TIMESTAMP}_itapeva-sp.backup"

echo "[INFO] Gerando backup em $BACKUP_FILE"

# Use these connection parameters
pg_dump -h esus-db -p 5432 -U postgres -F c -f "$BACKUP_FILE" esus

chmod 777 "$BACKUP_FILE"

delete_backup(){
    #apagando arquivos mais antigos (a mais de dias que existe)
    find $DSTDIR -name "*_itapeva-sp*" -ctime $TIME_BKCP -exec rm -f {} ";"
    if [ $? -eq 0 ] ; then
        echo "Arquivo de backup mais antigo eliminado com sucesso!"
    else
        echo "Erro durante a busca e destruição do backup antigo!"
    fi
}

delete_backup