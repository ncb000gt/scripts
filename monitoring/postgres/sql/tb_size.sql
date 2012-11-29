select spcname, pg_tablespace_size(oid), spclocation from pg_tablespace order by 2 desc;
