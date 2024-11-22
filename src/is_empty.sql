-- cleans up a json/jsonb objects from null, "", [], {}
-- it can be particularly useful for reducing payload size
--
-- note: standard json_object('a':...) style produces json

-- checks if "considered" empty jsonb
-- @param {jsonb}
-- @return {boolean} true if json/jsonb is null, "", [], {}
--
create function is_empty(jsonb)
    returns boolean
    language sql
    set search_path from current
    immutable
as $$
    select case
    when $1 is null then true
    when jsonb_typeof($1)='null' then true
    when jsonb_typeof($1)='string' then $1::text = '""'
    when jsonb_typeof($1)='array' then jsonb_array_length($1)=0
    when jsonb_typeof($1)='object' then (select count(1)=0 from jsonb_object_keys($1))
    else false
    end;
$$;

-- checks if "considered" empty json
-- @param {jsonb}
-- @return {boolean} true if json/jsonb is null, "", [], {}
--
create function is_empty(json)
    returns boolean
    language sql
    set search_path from current
    immutable
as $$
    select case
    when $1 is null then true
    when json_typeof($1)='null' then true
    when json_typeof($1)='string' then $1::text = '""'
    when json_typeof($1)='array' then json_array_length($1)=0
    when json_typeof($1)='object' then (select count(1)=0 from json_object_keys($1))
    else false
    end;
$$;
