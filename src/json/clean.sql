-- cleans a jsonb
-- @param {jsonb} to be cleaned
-- @param {boolean} deep_ if to check recursively
-- @return {jsonb} cleaned-up jsonb
--
create function jsonb_clean(
    jsonb,
    deep_ boolean default false
)
    returns jsonb
    language sql
    set search_path from current
    immutable
as $$
    select case
    when jsonb_typeof($1)='object'
        then (
            select jsonb_null_if_empty(
                jsonb_object_agg(key, value)
            )
            from jsonb_each($1)
            where not jsonb_is_empty(
                case
                when deep_ then jsonb_clean(value, deep_)
                else value
                end
            ))

    when jsonb_typeof($1)='array'
        then (
            select jsonb_null_if_empty(
                jsonb_agg(value)
            )
            from jsonb_array_elements($1)
            where not jsonb_is_empty(
                case
                when deep_ then jsonb_clean(value, deep_)
                else value
                end
            ))

    else jsonb_null_if_empty($1)
    end
$$;

-- cleans a json
-- @param {json} obj to be cleaned
-- @param {boolean} deep_ if to check recursively
-- @return {json} cleaned-up json
--
create function json_clean(
    json,
    deep_ boolean default false
)
    returns json
    language sql
    set search_path from current
    immutable
as $$
    select case
    when json_typeof($1)='object'
        then (
            select json_null_if_empty(
                json_object_agg(key, value)
            )
            from json_each($1)
            where not json_is_empty(
                case
                when deep_ then json_clean(value, deep_)
                else value
                end
            ))

    when json_typeof($1)='array'
        then (
            select json_null_if_empty(
                json_agg(value)
            )
            from json_array_elements($1)
            where not json_is_empty(
                case
                when deep_ then json_clean(value, deep_)
                else value
                end
            ))

    else json_null_if_empty($1)
    end
$$;

\if :{?test}
\if :test
    create function tests.test_util_json_clean()
        returns setof text
        language plpgsql
        set search_path from current
    as $$
    begin
        return next ok(
            jsonb_is_empty(null::jsonb)
            and jsonb_is_empty('""'::jsonb)
            and jsonb_is_empty('[]'::jsonb)
            and jsonb_is_empty('{}'::jsonb)
            , 'checks jsonb empties');

        return next ok(
            jsonb_clean('{"a":null,"b":{},"c":"","d":[]}'::jsonb) is null
            and jsonb_clean('[null,{},"",[]]'::jsonb) is null
            , 'cleans jsonb object');

        return next ok(
            jsonb_clean('{"a":null,"b":{},"c":"","d":[null,{"a":null}]}'::jsonb, true) is null
            and jsonb_clean('[null,{},"",{"a":null},[]]'::jsonb, true) is null
            , 'deep cleans jsonb object');


        return next ok(
            json_is_empty(null::json)
            and json_is_empty('""'::json)
            and json_is_empty('[]'::json)
            and json_is_empty('{}'::json)
            , 'checks json empties');


        return next ok(
            json_clean('{"a":null,"b":{},"c":"","d":[]}'::json) is null
            and json_clean('[null,{},"",[]]'::json) is null
            , 'cleans json object');

        return next ok(
            json_clean('{"a":null,"b":{},"c":"","d":[null,{"a":null}]}'::json, true) is null
            and json_clean('[null,{},"",{"a":null},[]]'::json, true) is null
            , 'deep cleans json object');

    end;
    $$;

\endif
\endif
