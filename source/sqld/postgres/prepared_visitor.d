
module sqld.postgres.prepared_visitor;

import sqld.ast;
import sqld.postgres.visitor;

import std.conv;

struct PreparedSQL
{
private:
    string   _sql;
    string[] _parameters;

public:
    @property
    string sql()
    {
        return _sql;
    }

    @property
    const(string[]) parameters()
    {
        return _parameters;
    }
}

class PostgresPreparedVisitor : PostgresVisitor
{
protected:
    string[] _parameters;

public:
    @property
    const(string[]) parameters()
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
        _parameters ~= literal(node.value);
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
    assert(v.parameters == ["5"]);
    assert(v.preparedSQL == PreparedSQL("$1", ["5"]));
}
