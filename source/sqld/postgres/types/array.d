
module sqld.postgres.types.array;

import sqld.ast.literal_node;
import sqld.postgres.format_literal;

import std.algorithm;
import std.array;
import std.traits;

template isPostgresArrayType(T)
{
    enum isPostgresArrayType = isArray!(T) && !isSomeString!(T);
}

class PostgresArray(T) : LiteralType if(isPostgresArrayType!(T))
{
private:
    T _elements;

public:
    alias elements this;

    this(T elements)
    {
        _elements = elements;
    }

    @property
    T elements()
    {
        return _elements;
    }

    @property
    override string sql()
    {
        return "ARRAY[" ~ elements.map!(formatLiteral).join(", ") ~ "]";
    }
}

@property
auto pgArray(T)(T elements) nothrow if(isPostgresArrayType!(T) && !isPostgresArrayType!(ForeachType!(T)))
{
    return new PostgresArray!(T)(elements);
}

@property
auto pgArray(T)(T elements) nothrow if(isPostgresArrayType!(T) && isPostgresArrayType!(ForeachType!(T)))
{
    auto result = elements.map!(e => e.pgArray).array;
    return new PostgresArray!(typeof(result))(result);
}

@system unittest
{
    assert(pgArray([1, 2, 3, 4]).sql == "ARRAY[1, 2, 3, 4]");
    assert(pgArray([[1, 2], [3, 4]]).sql == "ARRAY[ARRAY[1, 2], ARRAY[3, 4]]");
    assert(pgArray([[[1], [2]], [[3], [4]]]).sql == "ARRAY[ARRAY[ARRAY[1], ARRAY[2]], ARRAY[ARRAY[3], ARRAY[4]]]");
}
