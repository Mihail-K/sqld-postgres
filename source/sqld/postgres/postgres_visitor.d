
module sqld.postgres.postgres_visitor;

import sqld.ast;
import sqld.postgres.escape;

import std.algorithm;
import std.array;
import std.conv;
import std.meta;
import std.traits;

class PostgresVisitor : Visitor
{
private:
    Appender!(string) _buffer;

public:
    @property
    string sql()
    {
        return _buffer.data;
    }

    void visit(immutable(AsNode) node)
    {
        node.node.accept(this);
        _buffer ~= " AS " ~ node.name;
    }

    void visit(immutable(AssignmentNode) node)
    {
        node.left.accept(this);
        _buffer ~= " = ";

        if(node.right !is null)
        {
            node.right.accept(this);
        }
        else
        {
            _buffer ~= "DEFAULT";
        }
    }

    void visit(immutable(BetweenNode) node)
    {
        node.first.accept(this);
        _buffer ~= " BETWEEN ";
        node.second.accept(this);
        _buffer ~= " AND ";
        node.third.accept(this);
    }

    void visit(immutable(BinaryNode) node)
    {
        if(node.operator == BinaryOperator.or) _buffer ~= "(";
        node.left.accept(this);
        if(node.operator == BinaryOperator.or) _buffer ~= ")";
        _buffer ~= " " ~ node.operator ~ " ";
        if(node.operator == BinaryOperator.or) _buffer ~= "(";
        node.right.accept(this);
        if(node.operator == BinaryOperator.or) _buffer ~= ")";
    }

    void visit(immutable(ColumnNode) node)
    {
        if(node.table !is null)
        {
            node.table.accept(this);
            _buffer ~= ".";
        }

        _buffer ~= node.name;
    }

    void visit(immutable(DeleteNode) node)
    in
    {
        assert(node.limit is null, "LIMIT on DELETE is not supported in Postgres.");
    }
    body
    {
        _buffer ~= padded("DELETE ");

        foreach(field; AliasSeq!("from", "using", "where", "returning"))
        {
            if(auto child = __traits(getMember, node, field))
            {
                child.accept(this);
            }
        }
    }

    void visit(immutable(DirectionNode) node)
    {
        node.node.accept(this);
        _buffer ~= " " ~ node.direction;
    }

    void visit(immutable(ExpressionListNode) node)
    {
        foreach(index, child; node.nodes)
        {
            child.accept(this);

            if(index + 1 < node.nodes.length)
            {
                _buffer ~= ", ";
            }
        }
    }

    void visit(immutable(FromNode) node)
    {
        _buffer ~= padded("FROM ");
        node.sources.accept(this);
    }

    void visit(immutable(FunctionNode) node)
    {
        _buffer ~= node.name;
    }

    void visit(immutable(GroupByNode) node)
    {
        _buffer ~= padded("GROUP BY ");
        node.groupings.accept(this);
    }

    void visit(immutable(HavingNode) node)
    {
        _buffer ~= padded("HAVING ");
        node.clause.accept(this);
    }

    void visit(immutable(InsertNode) node)
    in
    {
        assert((node.values is null) ^ (node.select is null), "INSERT must has either VALUES or SELECT");
    }
    body
    {
        _buffer ~= padded("INSERT ");

        foreach(field; AliasSeq!("with_", "into", "values", "select", "returning"))
        {
            if(auto child = __traits(getMember, node, field))
            {
                child.accept(this);
            }
        }
    }

    void visit(immutable(IntoNode) node)
    {
        _buffer ~= padded("INTO ");
        node.table.accept(this);

        if(node.columns !is null)
        {
            _buffer ~= "(";
            node.columns.accept(this);
            _buffer ~= ")";
        }
    }

    void visit(immutable(InvocationNode) node)
    {
        node.callable.accept(this);

        _buffer ~= "(";
        node.arguments.accept(this);
        _buffer ~= ")";
    }

    void visit(immutable(JoinNode) node)
    {
        _buffer ~= padded(node.type) ~ " ";
        node.source.accept(this);

        if(node.condition !is null)
        {
            _buffer ~= " ON ";
            node.condition.accept(this);
        }
    }

    void visit(immutable(LimitNode) node)
    {
        _buffer ~= padded("LIMIT ") ~ literal(node.limit);
    }

    void visit(immutable(LiteralNode) node)
    {
        foreach(Type; LiteralTypes)
        {
            if(Type* value = node.value.peek!(Type))
            {
                _buffer ~= literal(*value);
                return;
            }
        }
    }

    void visit(immutable(NamedWindowNode) node)
    {
        _buffer ~= node.name ~ " AS ";
        node.definition.accept(this);
    }

    void visit(immutable(OffsetNode) node)
    {
        _buffer ~= padded("OFFSET ") ~ literal(node.offset);
    }

    void visit(immutable(OrderByNode) node)
    {
        _buffer ~= padded("ORDER BY ");
        node.directions.accept(this);
    }

    void visit(immutable(OverNode) node)
    {
        node.subject.accept(this);
        _buffer ~= " OVER ";
        node.window.accept(this);
    }

    void visit(immutable(PartitionByNode) node)
    {
        _buffer ~= padded("PARTITION BY ");
        node.partitions.accept(this);
    }

    void visit(immutable(PostfixNode) node)
    {
        node.operand.accept(this);
        _buffer ~= " " ~ node.operator;
    }

    void visit(immutable(PrefixNode) node)
    {
        _buffer ~= node.operator ~ " ";
        node.operand.accept(this);
    }

    void visit(immutable(ProjectionNode) node)
    {
        node.projections.accept(this);
    }

    void visit(immutable(ReturningNode) node)
    {
        _buffer ~= padded("RETURNING ");
        node.outputs.accept(this);
    }

    void visit(immutable(SelectNode) node)
    {
        _buffer ~= padded("SELECT ");

        foreach(field; AliasSeq!("with_", "projection", "from", "joins", "where", "groupBy",
                                 "having", "window", "union_", "orderBy", "limit", "offset"))
        {
            static if(isArray!(typeof(__traits(getMember, node, field))))
            {
                foreach(child; __traits(getMember, node, field))
                {
                    child.accept(this);
                }
            }
            else
            {
                if(auto child = __traits(getMember, node, field))
                {
                    child.accept(this);
                }
            }
        }
    }

    void visit(immutable(SetNode) node)
    {
        _buffer ~= padded("SET ");
        
        foreach(index, assignment; node.assignments)
        {
            assignment.accept(this);

            if(index + 1 < node.assignments.length)
            {
                _buffer ~= ", ";
            }
        }
    }

    void visit(immutable(SQLNode) node)
    {
        _buffer ~= node.sql;
    }
    
    void visit(immutable(SubqueryNode) node)
    {
        _buffer ~= "(";
        node.query.accept(this);
        _buffer ~= ")";
    }

    void visit(immutable(TableNode) node)
    {
        if(node.schema !is null)
        {
            _buffer ~= node.schema ~ ".";
        }

        _buffer ~= node.name;
    }

    void visit(immutable(UnionNode) node)
    {
        if(node.type != UnionType.distinct)
        {
            _buffer ~= padded(node.type) ~ " ";
        }

        _buffer ~= padded("UNION ");
        node.select.accept(this);
    }

    void visit(immutable(UpdateNode) node)
    in
    {
        assert(node.limit is null, "LIMIT on DELETE is not supported Postgres.");
    }
    body
    {
        _buffer ~= padded("UPDATE ");

        foreach(field; AliasSeq!("table", "set", "from", "where", "returning"))
        {
            if(auto child = __traits(getMember, node, field))
            {
                child.accept(this);
            }
        }
    }

    void visit(immutable(UsingNode) node)
    {
        _buffer ~= padded("USING ");
        node.sources.accept(this);
    }

    void visit(immutable(ValuesNode) node)
    {
        _buffer ~= padded("VALUES ");
        foreach(index, child; node.values)
        {
            _buffer ~= "(";
            child.accept(this);
            _buffer ~= ")";

            if(index + 1 < node.values.length)
            {
                _buffer ~= ", ";
            }
        }
    }

    void visit(immutable(WhereNode) node)
    {
        _buffer ~= padded("WHERE ");
        node.clause.accept(this);
    }

    void visit(immutable(WindowDefinitionNode) node)
    {
        _buffer ~= "(";

        if(node.reference !is null)
        {
            _buffer ~= node.reference ~ " ";
        }
        if(node.partitionBy !is null)
        {
            node.partitionBy.accept(this);
        }
        if(node.orderBy !is null)
        {
            node.orderBy.accept(this);
        }

        _buffer ~= ")";
    }

    void visit(immutable(WindowNode) node)
    {
        _buffer ~= padded("WINDOW ");

        foreach(index, window; node.windows)
        {
            window.accept(this);

            if(index + 1 < node.windows.length)
            {
                _buffer ~= ", ";
            }
        }
    }

    void visit(immutable(WithNode) node)
    {
        _buffer ~= padded("WITH ");
        if(node.recursive)
        {
            _buffer ~= "RECURSIVE ";
        }

        node.table.accept(this);
        _buffer ~= " AS (";
        node.select.accept(this);
        _buffer ~= ")";
    }

private:
    string padded(string keyword)
    {
        if(_buffer.data.length > 0)
        {
            immutable auto trailing = _buffer.data[$ - 1];

            if(trailing != ' ' && trailing != '(')
            {
                return " " ~ keyword;
            }
        }

        return keyword;
    }

    string literal(T)(T values) if(isArray!(T) && !isSomeString!(T))
    {
        return "(" ~ values.map!(e => literal(e)).joiner(", ").to!(string) ~ ")";
    }

    string literal(T : bool)(T value)
    {
        return value ? "'t'" : "'f'";
    }

    string literal(T)(T value) if(isIntegral!(T))
    {
        return value.to!(string);
    }

    string literal(T)(T value) if(isFloatingPoint!(T))
    {
        import std.string : indexOf;

        immutable auto result = value.to!(string);
        return result.indexOf('.') == -1 ? result ~ ".0" : result;
    }

    string literal(T)(T value) if(isSomeString!(T))
    {
        return escapeString(value); // TODO : Escape.
    }
}

@system unittest
{
    auto v = new PostgresVisitor;
    assert(v.padded("foo") == "foo");

    v._buffer ~= "(";
    assert(v.padded("foo") == "foo");

    v._buffer ~= ")";
    assert(v.padded("foo") == " foo");

    v._buffer ~= " ";
    assert(v.padded("foo") == "foo");
}

@system unittest
{
    auto v = new PostgresVisitor;
    assert(v.literal(1) == "1");
    assert(v.literal(123_456) == "123456");

    assert(v.literal(123.45) == "123.45");
    assert(v.literal(1.0) == "1.0");
    assert(v.literal(1.99999) == "1.99999");

    assert(v.literal(true) == "'t'");
    assert(v.literal(false) == "'f'");

    assert(v.literal([1, 2, 3, 4, 5]) == "(1, 2, 3, 4, 5)");
    assert(v.literal([true, false]) == "('t', 'f')");
    assert(v.literal([1.2, 2.3, 4.999]) == "(1.2, 2.3, 4.999)");
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = TableNode("users");
    auto n = u.as("test");

    n.accept(v);
    assert(v.sql == "users AS test");
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = TableNode("users");
    auto n = u["id"].eq(u["user_id"]);

    n.accept(v);
    assert(v.sql == "users.id = users.user_id");
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = TableNode("users");
    auto p = TableNode("posts");
    auto n = u["id"].eq(p["user_id"]).and(p["deleted"].eq(false));

    n.accept(v);
    assert(v.sql == "users.id = posts.user_id AND posts.deleted = 'f'");
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = TableNode("users");
    auto p = TableNode("posts");
    auto n = u["id"].eq(p["user_id"]).or(p["id"].isNull);

    n.accept(v);
    assert(v.sql == "(users.id = posts.user_id) OR (posts.id IS NULL)");
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = TableNode("users");
    auto n = new immutable ExpressionListNode([u["id"], u["email"], u["name"]]);

    n.accept(v);
    assert(v.sql == "users.id, users.email, users.name");
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto n = new immutable FromNode(TableNode("users"));

    n.accept(v);
    assert(v.sql == "FROM users");
}

@system unittest
{
    import sqld.select_builder : SelectBuilder;

    auto v = new PostgresVisitor;
    auto u = TableNode("users");
    auto n = new immutable FromNode(SelectBuilder.init.from(u));

    n.accept(v);
    assert(v.sql == "FROM (SELECT FROM users)");
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = TableNode("users");
    auto n = new immutable OrderByNode(u["name"].asc, u["email"].desc, u["created_at"].asc);

    n.accept(v);
    assert(v.sql == "ORDER BY users.name ASC, users.email DESC, users.created_at ASC");
}
