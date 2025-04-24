if [ "$PWD" != "$HOME/documenso" ]; then
  cd "$HOME/documenso"
fi

if [ ! -d "./sql-backups" ]; then
  echo "No SQL Backups found in ./sql-backups"
  exit
fi

selected_dump=$(ls ./sql-dumps/dump_*.gz | sort -t '_' -k2,2 -k3,3 -k4,4 | tail -n 1)

gunzip < $selected_dump | docker exec -i documenso-production_database_1 psql -U documenso -d documenso