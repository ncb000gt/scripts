select d.datname, w.locktype, ha.usename as hold_user, h.pid as holder_pid, h.mode as hold_mode, w.locktype
	, coalesce(c.relname,'Connect to DB') as relation, substring(ha.current_query from 1 for 50) as hold_sql
	, w.pid as waiter_pid, w.mode as wait_mode, current_timestamp-wa.query_start as age
	, substring(wa.current_query from 1 for 50) as wait_sql
from pg_locks w 
	left outer join pg_class c on w.relation = c.oid
	join pg_locks h on (w.relation = h.relation or w.virtualxid = h.virtualxid or w.transactionid = h.transactionid)
	join pg_stat_activity ha on h.pid = ha.procpid
	join pg_stat_activity wa on w.pid = wa.procpid
	left outer join pg_database d on h.database = d.oid
where w.granted = false
and h.granted = true
order by 7, 12

