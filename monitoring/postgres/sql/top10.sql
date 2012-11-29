select c.relname, c.relpages, t.relpages as toastpages, (c.relpages+coalesce(t.relpages,0))*8/1024 as MB 
from pg_class c
left outer join pg_class t on c.reltoastrelid=t.oid 
order by 4 desc limit 10;
