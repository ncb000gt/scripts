SELECT b.nspname, sum(relpages*8)/1024 as "est MB" 
FROM pg_class a, pg_namespace b
where b.oid = a.relnamespace
group by b.nspname
ORDER BY 2 DESC;
