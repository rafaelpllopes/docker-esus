#!/bin/bash
DATA=`date +%Y%m%d%H%M%S`			#pega data atual
DSTDIR=/home/esus/backups	#diretório de destino do backup
TIME_BKCP=+30				    #número de dias em que será deletado o arquivo de backup
INICIO=`date +%d/%m/%Y-%H:%M:%S`
LOG=/var/log/esus/log.txt
echo "********* —– BACKUP DO ESUS —– ***********" >> $LOG
echo "____________________________________________________" >> $LOG
echo "backup da BASE do ESUS iniciado em $INICIO" >> $LOG

delete_backup(){
#apagando arquivos mais antigos (a mais de 30 dias que existe)
find $DSTDIR -name "esus*" -ctime $TIME_BKCP -exec rm -f {} ";"
if [ $? -eq 0 ] ; then
echo "Arquivo de backup mais antigo eliminado com sucesso!" >> $LOG
else
echo "Erro durante a busca e destruição do backup antigo!" >> $LOG
fi
}
select_diretorio(){
# Cria o diretório do dia se ele não existir
if [ -d $DSTDIR ]; then
echo "DIRETORIO JA EXISTE" >> $LOG
else
`mkdir $DSTDIR` >> $LOG
fi
}
realiza_backup(){
ARQ_BKP=$DSTDIR/$DATA"_itapeva-sp".backup
pg_dump -F c -U postgres -h localhost -d esus > $ARQ_BKP
if [ -e $ARQ_BKP ]; then
    chown postgres:root $ARQ_BKP
    echo "BACKUP REALIZADO COM SUCESSO !!!" >> $LOG
else
    echo "ERRO AO REALIZAR BACKUP" >> $LOG
fi
}

select_diretorio
realiza_backup
delete_backup

TERMINO=`date +%d/%m/%Y-%H:%M:%S`
echo "backup da BASE do ESUS terminado em $TERMINO" >> $LOG
echo "_______________________________________________________" >> $LOG

