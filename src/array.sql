-- various array functions

-- returns intersection of 2 array
--
create function array_intersection(
    anyarray,
    anyarray
)
    returns anyarray
    language sql
    set search_path from current
    strict immutable
as $$
    select
        array(select unnest($1)
        intersect
        select unnest($2))
$$;


-- concats 2 arrays
--
create function array_concat(
    anyarray,
    anyarray
)
    returns anyarray
    language sql
    set search_path from current
    strict immutable
as $$
    select array(
        select unnest($1)
        union
        select unnest($2))
$$;

-- concats 3 arrays
--
create function array_concat(
    anyarray,
    anyarray,
    anyarray
)
    returns anyarray
    language sql
    set search_path from current
    strict immutable
as $$
    select array(
        select unnest($1)
        union
        select unnest($2)
        union
        select unnest($3))
$$;

-- returns differences of 2 array
--
create function array_diff(
    anyarray,
    anyarray
)
    returns anyarray
    language sql
    set search_path from current
    strict immutable
as $$
    select array(
        select unnest($1)
        except
        select unnest($2))
$$;

-- returns sorted aray
--
create function array_sort(
    array_ anyarray,
    dir_ text default 'asc'
)
    returns anyarray
    language sql
    set search_path from current
    strict immutable
as $$
    select array(
        select a
        from unnest(array_) as x(a)
        order by
            (case when lower(dir_)='asc' then a end),
            a desc
    )
$$;

-- returns reindex array
--
create function array_reindex(
    array_ anyarray,
    index_ int[],
    dir_ text default 'asc'
)
    returns anyarray
    language sql
    set search_path from current
    strict immutable
as $$
    select array(
        select a
        from unnest(array_, index_) as x(a,i)
        order by
            (case when lower(dir_)='asc' then i end),
            i desc
    )
$$;

-- returns true if array includes element
--
create function array_includes(
    anyarray,
    anyelement
)
    returns boolean
    language sql
    set search_path from current
    strict immutable
as $$
    select $2 = any($1)
$$;

-- returns index/position of element in array
--
create function array_index_of(
    anyarray,
    anyelement
)
    returns integer
    language sql
    set search_path from current
    strict immutable
as $$
    select array_position($1, $2)
$$;

-- returns reversed order of array
--
create function array_reverse(
    array_ anyarray
)
    returns anyarray
    language sql
    set search_path from current
    strict immutable
as $$
    select array(
        select array_[i]
        from generate_subscripts(array_, 1) as s(i)
        order by i desc
    )
$$;

-- returns an array with nulls removed
--
create function array_nulls(
    anyarray
)
    returns anyarray
    language sql
    set search_path from current
    strict immutable
as $$
    select array_agg(a)
    from unnest($1) a
    where a is not null
$$;


\if :{?test}
    create function tests.test_util_array()
        returns setof text
        language plpgsql
        set search_path from current
    as $$
    begin
        return next ok(
            array_intersection(array[1,2,3], array[2,3,4]) = array[2,3],
            'array intersection'
        );

        return next ok(
            array_diff(array[1,2,3], array[2,3]) = array[1],
            'array diff'
        );

        return next ok(
            array_sort(array_concat(array[1,2,3], array[2,3,4])) = array[1,2,3,4],
            'array concat'
        );

        return next ok(
            array_sort(array[1,3,2]) = array[1,2,3],
            'array sort asc'
        );

        return next ok(
            array_sort(array[1,3,2], 'desc') = array[3,2,1],
            'array sort desc'
        );

        return next ok(
            array_reindex(array[1,2,3], array[3,2,1]) = array[3,2,1],
            'array reindex'
        );

        return next ok(
            array_reverse(array[1,2,3]) = array[3,2,1],
            'array reverse'
        );

        return next ok(
            array_includes(array[1,2,3], 2),
            'array has'
        );

        return next ok(
            array_index_of(array[1,2,3], 2) = 2,
            'array index_of'
        );

        return next ok(
            array_nulls(array[1,2,null,3]) = array[1,2,3],
            'array nulls'
        );

    end;
    $$;
\endif
