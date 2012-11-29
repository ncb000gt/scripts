-- table/column/fkey definitions
select x.nspname || '.' || x.relname as "Table", x.attnum as "#", x.attname as "Column", x."Datatype", r.conname as "F Key", fn.nspname || '.' || f.relname as "Lookup Table"
from (
	SELECT c.oid, a.attnum, n.nspname, c.relname, a.attname, pg_catalog.format_type(a.atttypid, a.atttypmod) as "Datatype"
	FROM   pg_catalog.pg_attribute a, pg_namespace n, pg_class c
	WHERE  a.attnum > 0
	AND NOT a.attisdropped
	AND a.attrelid = c.oid
	and c.relnamespace = n.oid
	and n.nspname not in ('pg_catalog','pg_toast','information_schema')
) x
left join pg_constraint r on r.conrelid = x.oid and r.conkey[1] = x.attnum
left join pg_class f on r.confrelid = f.oid
left join pg_namespace fn on f.relnamespace = fn.oid
order by 1,2

