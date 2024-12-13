-- cleans up a json/jsonb objects from null, "", [], {}
-- it can be particularly useful for reducing payload size
--
-- note: standard json_object('a':...) style produces json

-- checks if "considered" empty jsonb
-- @param {jsonb}
-- @return {boolean} true if json/jsonb is null, "", [], {}
--
create function jsonb_is_empty(jsonb)
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
create function json_is_empty(json)
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


-- returns null if empty jsonb
-- @param {jsonb} value
-- @return {jsonb} null if empty
--
create function jsonb_null_if_empty(jsonb)
    returns jsonb
    language sql
    set search_path from current
    immutable
as $$
    select case
    when jsonb_is_empty($1) then null
    else $1
    end
$$;

-- returns null if empty json
-- @param {json} value
-- @return {json} null if empty
--
create function json_null_if_empty(json)
    returns json
    language sql
    set search_path from current
    immutable
as $$
    select case
    when json_is_empty($1) then null
    else $1
    end
$$;
