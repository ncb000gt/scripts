SELECT pg_database.datname, pg_database_size(pg_database.datname) AS size FROM pg_database order by 2 desc;
