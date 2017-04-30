
module sqld.postgres.quote;

import std.algorithm;
import std.array;
import std.conv;
import std.traits;

@property
string quoteName(string input) @safe pure nothrow
{
    return '"' ~ input.replace(`"`, `""`) ~ '"';
}

@safe unittest
{
    assert(quoteName("users") == `"users"`);
    assert(quoteName(`"tables"`) == `"""tables"""`);
    assert(quoteName("users.id") == `"users.id"`);
}

@property
string quoteReference(string input, size_t limit = size_t.max) pure
{
    import std.range : tail;

    return input.splitter(".")
                .map!(quoteName)
                .tail(limit)
                .joiner(".")
                .to!(string);
}

@system unittest
{
    assert(quoteReference("users") == `"users"`);
    assert(quoteReference("users.id") == `"users"."id"`);
    assert(quoteReference(`users.i"d`) == `"users"."i""d"`);

    assert(quoteReference(`public.users.id`) == `"public"."users"."id"`);
    assert(quoteReference(`public.users.id`, 2) == `"users"."id"`);
}

@property
string quoteString(T)(T input) @safe pure if(isSomeString!(T))
{
    import std.string : translate;

    immutable string[dchar] table = [
        '\b': `\b`,
        '\f': `\f`,
        '\n': `\n`,
        '\r': `\r`,
        '\t': `\t`,
        '\'': `''`,
        '\\': `\\`
    ];

    auto result = "'" ~ input.translate(table) ~ "'";
    return result.to!(string);
}

@safe unittest
{
    assert(quoteString("potato") == "'potato'");
    assert(quoteString("john's") == "'john''s'");
    assert(quoteString("a\nbook") == "'a\\nbook'");
    assert(quoteString("danger\\") == "'danger\\\\'");
    assert(quoteString("title\\\n") == "'title\\\\\\n'");
}
