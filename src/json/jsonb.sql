-- various jsonb utility functions
--

-- returns the object keys
--
create function jsonb_keys(
    obj_ jsonb
)
    returns text[]
    language sql
    set search_path from current
    strict immutable
as $$
    select array(
        select a
        from jsonb_object_keys(obj_) as x(a)
        order by a
    )
$$;

-- returns json array values as texts
--
create function jsonb_texts(
    arr_ jsonb
)
    returns text[]
    language sql
    set search_path from current
    strict immutable
as $$
    select coalesce(array_agg(value), '{}')
    from jsonb_array_elements_text(arr_)
$$;

-- returns json object with selected keys
--
create function jsonb_select(
    obj_ jsonb,
    keys_ text[]
)
    returns jsonb
    language sql
    set search_path from current
    strict immutable
as $$
    select jsonb_strip_nulls(
        $1 - array_diff(jsonb_keys( obj_ ), keys_)
    )
$$;

-- returns json object with deleted keys
--
create function jsonb_delete(
    obj_ jsonb,
    keys_ text[]
)
    returns jsonb
    language sql
    set search_path from current
    strict immutable
as $$
    select jsonb_object_agg(kv.key, kv.value)
    from jsonb_each( obj_ ) kv
    where not kv.key = any(keys_)
$$;


-- aggregate Object.assign
--
create aggregate jsonb_assign(
    jsonb
) (
    sfunc  = 'jsonb_concat',
    stype = 'jsonb',
    initcond = '{}'
);

-- variadic Object.assign
--
create function jsonb_assign(
    variadic jsonb[]
)
    returns jsonb
    language sql
    set search_path from current
    strict immutable
as $$
    select jsonb_assign(v)
    from unnest($1) v
$$;

-- checks if object has a jsonpath match
-- can be useful for entitlement check
--
create function jsonb_has(
    obj_ jsonb,
    arr_ jsonpath[]
)
    returns boolean
    language sql
    set search_path from current
    strict immutable
as $$
    select case
    when cardinality(arr_) = 0 then true
    else (
        select count(1) > 0
        from unnest(arr_) rs
        where coalesce((obj_ @@ rs)::boolean, false)
    )
    end
$$;

-- checks if object has all jsonpath matches
-- can be useful for entitlement check
--
create function jsonb_have(
    obj_ jsonb,
    arr_ jsonpath[]
)
    returns boolean
    language sql
    set search_path from current
    strict immutable
as $$
    select count(1) = cardinality(arr_)
    from unnest(arr_) rs
    where coalesce((obj_ @@ rs)::boolean, false)
$$;



\if :{?test}
    create function tests.test_util_jsonb()
        returns setof text
        language plpgsql
        set search_path from current
    as $$
    begin
        return next ok(
            jsonb_keys('{"a":1,"b":2}'::jsonb) = array['a','b'],
            'get object keys');

        return next ok(
            jsonb_texts('["a",1,2]'::jsonb) = array['a','1','2'],
            'get array texts');

        return next ok(
            jsonb_select('{"a":1,"b":2}'::jsonb, array['a','c']) = '{"a":1}'::jsonb,
            'select object keys');

        return next ok(
            jsonb_delete('{"a":1,"b":2}'::jsonb, array['a','c']) = '{"b":2}'::jsonb,
            'delete object keys');

        return next ok(
            jsonb_assign('{"a":1}','{"b":2}','{}') = '{"a":1,"b":2}'::jsonb,
            'assign objects');

        return next ok(
            jsonb_has('{"a":{"b":true}}', '{"$.a.b","$.a.c"}'::jsonpath[]),
            'can query any jsonpath');

        return next ok(
            jsonb_has('{"a":{"b":true}}', '{}'),
            'allow empty jsonpath');

        return next ok(
            jsonb_has('{"a":{"b":true}}', null) is null,
            'capture null');

        return next ok(
            jsonb_have('{"a":{"b":true}}', null) is null
            and jsonb_have('{"a":{"b":true}}', '{}')
            and not jsonb_have('{"a":{"b":true}}', '{"$.a.b","$.a.c"}')
            and jsonb_have('{"a":{"b":true}}', '{"$.a.b"}'),
            'can query jsonpaths');
    end;
    $$;

\endif
