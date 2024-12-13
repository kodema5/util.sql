
create schema if not exists util_;
set search_path=util_,public;

create table if not exists console_log (
    -- for tagging/query
    log_id serial,
    log_tz timestamp with time zone
        default clock_timestamp(),

    -- original caller of transaction
    --
    root text,
    root_id text,

    -- current location where log is called
    current text,

    -- type and data logged
    --
    type text,
    data jsonb
);

drop schema if exists util cascade;
create schema if not exists util;
set search_path=util,util_,public;

\ir array.sql
\ir iif.sql
\ir json/index.sql
\ir names.sql
\ir to_ts.sql
\ir console_log.sql