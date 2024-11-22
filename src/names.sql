create or replace function to_pascal(
    text
)
    returns text
    set search_path from current
    language sql
    immutable
    strict
as $$
    select replace(initcap(replace($1, '_', ' ')), ' ', '');
$$;

create or replace function to_camel(
    text
)
    returns text
    set search_path from current
    language sql
    immutable
    strict
as $$
    select lower(left(a,1)) || right(a, -1)
    from to_pascal($1) a;
$$;

create or replace function to_snake(
    text
)
    returns text
    set search_path from current
    language sql
    immutable
    strict
as $$
    select lower(trim(
        both '_' from regexp_replace($1, '([A-Z])','_\1','g')
    ))
$$;




\if :{?test}
\if :test
    create function tests.test_util_naming()
        returns setof text
        language plpgsql
        set search_path from current
    as $$
    begin
        return next ok(to_pascal(null) is null, 'null');
        return next ok(to_pascal('hello_world')='HelloWorld', 'to_pascal HelloWorld');
        return next ok(to_pascal('hello__world')='HelloWorld', 'to_pascal HelloWorld');
        return next ok(to_pascal('_hello__world_')='HelloWorld', 'to_pascal HelloWorld');
        return next ok(to_pascal('HelloWorld')='Helloworld', 'to_pascal HelloWorld');

        return next ok(to_camel(null) is null, 'null');
        return next ok(to_camel('hello_world')='helloWorld', 'to_camel HelloWorld');
        return next ok(to_camel('hello__world')='helloWorld', 'to_camel HelloWorld');
        return next ok(to_camel('_hello__world_')='helloWorld', 'to_camel HelloWorld');
        return next ok(to_camel('HelloWorld')='helloworld', 'to_camel HelloWorld');

        return next ok(to_snake(null) is null, 'null');
        return next ok(to_snake('HelloWorld')='hello_world', 'to_snake HelloWorld');
        return next ok(to_snake('helloWorld')='hello_world', 'to_snake HelloWorld');
        return next ok(to_snake('helloWorld World')='hello_world _world', 'to_snake HelloWorld');
        return next ok(to_snake('hello_world')='hello_world', 'to_snake HelloWorld');

    end;
    $$;


\endif
\endif