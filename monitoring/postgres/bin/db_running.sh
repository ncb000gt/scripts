PSQL="psql -U postgres"


SQL="select s.datname, s.procpid, s.usename, substring(s.current_query from 1 for 100) as sql, clock_timestamp()-s.query_start as age, s.client_addr as query_ip
	, h.locktype, h.mode, substring(sh.current_query from 1 for 30) as hold_sql, sh.procpid as blocker_pid, sh.client_addr as blocker_ip
	from pg_stat_activity s
	left outer join pg_locks w on (w.pid = s.procpid and s.waiting and not w.granted)
	left outer join pg_locks h on ((w.relation = h.relation or w.virtualxid = h.virtualxid or w.transactionid = h.transactionid or w.page = h.page or w.tuple = h.tuple) and h.granted and (h.pid != s.procpid or h.pid is null))
	left outer join pg_stat_activity sh on (h.pid = sh.procpid and sh.procpid != s.procpid)
	where s.current_query <> '<IDLE>'
	and s.procpid != pg_backend_pid()
	order by s.query_start;"

$PSQL postgres -c "$SQL"

