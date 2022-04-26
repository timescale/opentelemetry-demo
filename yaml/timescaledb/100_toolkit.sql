create extension if not exists timescaledb_toolkit;
create table if not exists used_passwords(digest text primary key);
