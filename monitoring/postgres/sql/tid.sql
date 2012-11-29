SELECT datname, datfrozenxid, age(datfrozenxid), txid_current() FROM pg_database ORDER BY 3;
