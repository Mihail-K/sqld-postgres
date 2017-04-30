
module sqld.postgres.prepared_visitor;

import sqld.ast;
import sqld.postgres.format_literal;
import sqld.postgres.visitor;

import std.conv;
import std.variant;

struct PreparedSQL
{
private:
    string                     _sql;
    Algebraic!(LiteralTypes)[] _parameters;

public:
    @property
    string sql()
    {
        return _sql;
    }

    @property
    const(Algebraic!(LiteralTypes)[]) parameters()
    {
        return _parameters;
    }
}

class PostgresPreparedVisitor : PostgresVisitor
{
protected:
    Algebraic!(LiteralTypes)[] _parameters;

public:
    @property
    const(Algebraic!(LiteralTypes)[]) parameters()
    {
        return _parameters;
    }

    @property
    PreparedSQL preparedSQL()
    {
        return PreparedSQL(sql, _parameters);
    }

    alias visit = PostgresVisitor.visit;

    override void visit(immutable(ParameterNode) node)
    {
        _buffer     ~= "$" ~ (_parameters.length + 1).to!(string);
        _parameters ~= node.value.value;
    }
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto n = new immutable ParameterNode(literal(5));

    n.accept(v);
    assert(v.sql == "5");
}

@system unittest
{
    auto v = new PostgresPreparedVisitor;
    auto n = new immutable ParameterNode(literal(5));

    n.accept(v);
    assert(v.sql == "$1");
    assert(v.parameters == [Algebraic!(LiteralTypes)(5)]);
}
