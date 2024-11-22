
-- extract epoch from timestamp
--
create function to_ts(
    tz timestamp with time zone
)
    returns numeric
    language sql
    stable
    set search_path from current
as $$
    select extract(epoch from tz)
$$;