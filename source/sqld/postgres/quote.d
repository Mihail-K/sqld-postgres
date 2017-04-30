
module sqld.postgres.quote;

import std.algorithm;
import std.array;
import std.conv;

@property
string quoteName(string input)
{
    return '"' ~ input.replace(`"`, `""`) ~ '"';
}

@system unittest
{
    assert(quoteName("users") == `"users"`);
    assert(quoteName(`"tables"`) == `"""tables"""`);
    assert(quoteName("users.id") == `"users.id"`);
}

@property
string quoteReference(string input)
{
    return input.splitter(".")
                .map!(quoteName)
                .joiner(".")
                .to!(string);
}

@system unittest
{
    assert(quoteReference("users") == `"users"`);
    assert(quoteReference("users.id") == `"users"."id"`);
    assert(quoteReference(`users.i"d`) == `"users"."i""d"`);
}

@property
string quoteString(string input)
{
    import std.string : translate;

    immutable string[dchar] table = [
        '\b': `\b`,
        '\f': `\f`,
        '\n': `\n`,
        '\r': `\r`,
        '\t': `\t`,
        '\'': `''`,
        '\\': `\\`,
    ];

    return "'" ~ input.translate(table) ~ "'"; // TODO
}

@system unittest
{
    assert(quoteString("potato") == "'potato'");
    assert(quoteString("john's") == "'john''s'");
    assert(quoteString("a\nbook") == "'a\\nbook'");
    assert(quoteString("danger\\") == "'danger\\\\'");
    assert(quoteString("title\\\n") == "'title\\\\\\n'");
}
