
PSQL="psql -U postgres"

get_param() {
   PARAM=$1
   echo "  $PARAM = `psql -U postgres postgres -A -t -c "show $PARAM"`"
}

echo
echo "Logging Parameters..."
get_param "log_destination"
get_param "logging_collector"
get_param "log_directory"
get_param "log_filename"
get_param "log_rotation_age"
get_param "log_rotation_size"
get_param "log_min_messages"
get_param "log_min_error_statement"
get_param "log_min_duration_statement"
get_param "silent_mode"
get_param "log_duration"
get_param "log_line_prefix"
get_param "log_lock_waits"
get_param "log_statement"
get_param "log_temp_files"

echo
echo "Memory Parameters..."
get_param "shared_buffers"
get_param "effective_cache_size"
get_param "wal_buffers"
get_param "work_mem"
get_param "maintenance_work_mem"

echo
echo "Vacuum Parameters..."
get_param "autovacuum"

echo
echo "Backup Parameters..."
get_param "archive_mode"
get_param "archive_command"
get_param "checkpoint_segments"
get_param "checkpoint_timeout"

echo
echo "Performance Parameters..."
get_param "fsync"
get_param "wal_sync_method"
get_param "seq_page_cost"
get_param "random_page_cost"

echo

