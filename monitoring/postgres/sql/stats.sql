select schemaname, sum(stats) as has_stats, sum(nostats) as no_stats from (
	select schemaname, 1 as stats, 0 as nostats
	from pg_stat_all_tables
	where last_analyze is not null and schemaname != 'pg_toast' 
	UNION ALL
	select schemaname, 0 as stats, 1 as nostats
	from pg_stat_all_tables
	where last_analyze is null and schemaname != 'pg_toast' 
) x
group by schemaname
;
