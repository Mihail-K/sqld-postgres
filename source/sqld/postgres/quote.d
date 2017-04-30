
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
string escapeString(string input)
{
    return "'" ~ input ~ "'"; // TODO
}
