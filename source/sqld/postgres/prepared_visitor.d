
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
