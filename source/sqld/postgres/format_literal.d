
module sqld.postgres.format_literal;

import sqld.ast.literal_node;
import sqld.postgres.quote;

import std.algorithm;
import std.array;
import std.conv;
import std.traits;

string formatLiteral(T)(T node) if(is(T == immutable(LiteralNode)))
{
    foreach(Type; LiteralTypes)
    {
        if(Type* value = node.value.peek!(Type))
        {
            return formatLiteral(*value);
        }
    }

    assert(0, "Unsupported type: " ~ node.value.type.toString);
}

string formatLiteral(T)(T values) if(isArray!(T) && !isSomeString!(T))
{
    return "(" ~ values.map!(v => formatLiteral(v)).join(", ") ~ ")";
}

string formatLiteral(T : bool)(T value)
{
    return value ? "'t'" : "'f'";
}

string formatLiteral(T)(T value) if(isIntegral!(T))
{
    return value.to!(string);
}

string formatLiteral(T)(T value) if(isFloatingPoint!(T))
{
    import std.string : indexOf;

    immutable auto result = value.to!(string);
    return result.indexOf('.') == -1 ? result ~ ".0" : result;
}

string formatLiteral(T)(T value) if(isSomeString!(T))
{
    return quoteString(value);
}

@system unittest
{
    assert(formatLiteral(1) == "1");
    assert(formatLiteral(123_456) == "123456");

    assert(formatLiteral(123.45) == "123.45");
    assert(formatLiteral(1.0) == "1.0");
    assert(formatLiteral(1.99999) == "1.99999");

    assert(formatLiteral(true) == "'t'");
    assert(formatLiteral(false) == "'f'");

    assert(formatLiteral("john") == "'john'");
    assert(formatLiteral("jane's") == "'jane''s'");

    assert(formatLiteral([1, 2, 3, 4, 5]) == "(1, 2, 3, 4, 5)");
    assert(formatLiteral([true, false]) == "('t', 'f')");
    assert(formatLiteral([1.2, 2.3, 4.999]) == "(1.2, 2.3, 4.999)");
}
