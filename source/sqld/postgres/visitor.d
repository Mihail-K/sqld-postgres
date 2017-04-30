
module sqld.postgres.visitor;

import sqld.ast;
import sqld.postgres.quote;
import sqld.postgres.format_literal;

import std.array;
import std.conv;
import std.meta;
import std.traits;

class PostgresVisitor : Visitor
{
protected:
    Appender!(string) _buffer;

public:
    @property
    string sql()
    {
        return _buffer.data;
    }

    void visit(immutable(ArithmeticNode) node)
    {
        node.left.accept(this);
        _buffer ~= " " ~ formatArithmeticOperator(node.operator) ~ " ";
        node.right.accept(this);
    }

    void visit(immutable(AsNode) node)
    {
        node.node.accept(this);
        _buffer ~= " AS " ~ quoteName(node.name);
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

    void visit(immutable(ColumnNode) node)
    {
        if(node.table !is null)
        {
            node.table.accept(this);
            _buffer ~= ".";
        }

        _buffer ~= quoteName(node.name);
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

            foreach(index, column; node.columns)
            {
                column.accept(this);

                if(index + 1 < node.columns.length)
                {
                    _buffer ~= ", ";
                }
            }

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
        _buffer ~= padded("LIMIT ") ~ formatLiteral(node.limit);
    }

    void visit(immutable(LiteralNode) node)
    {
        _buffer ~= formatLiteral(node);
    }

    void visit(immutable(LogicalNode) node)
    {
        if(node.operator == LogicalOperator.or) _buffer ~= "(";
        node.left.accept(this);
        if(node.operator == LogicalOperator.or) _buffer ~= ")";

        _buffer ~= " " ~ node.operator ~ " ";

        if(node.operator == LogicalOperator.or) _buffer ~= "(";
        node.right.accept(this);
        if(node.operator == LogicalOperator.or) _buffer ~= ")";
    }

    void visit(immutable(NamedWindowNode) node)
    {
        _buffer ~= quoteName(node.name) ~ " AS ";
        node.definition.accept(this);
    }

    void visit(immutable(OffsetNode) node)
    {
        _buffer ~= padded("OFFSET ") ~ formatLiteral(node.offset);
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

    void visit(immutable(ParameterNode) node)
    {
        node.value.accept(this);
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

    void visit(immutable(RelationalNode) node)
    {
        node.left.accept(this);
        _buffer ~= " " ~ node.operator ~ " ";
        node.right.accept(this);
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
            _buffer ~= quoteName(node.schema) ~ ".";
        }

        _buffer ~= quoteName(node.name);
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

protected:
    string formatArithmeticOperator(ArithmeticOperator operator)
    {
        return operator == ArithmeticOperator.bitXor ? "#" : cast(string) operator;
    }

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
    auto u = table("users");
    auto n = u.as("test");

    n.accept(v);
    assert(v.sql == `"users" AS "test"`);
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = table("users");
    auto n = u["id"].eq(u["user_id"]);

    n.accept(v);
    assert(v.sql == `"users"."id" = "users"."user_id"`);
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = table("users");
    auto p = table("posts");
    auto n = u["id"].eq(p["user_id"]).and(p["deleted"].eq(false));

    n.accept(v);
    assert(v.sql == `"users"."id" = "posts"."user_id" AND "posts"."deleted" = 'f'`);
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = table("users");
    auto p = table("posts");
    auto n = u["id"].eq(p["user_id"]).or(p["id"].isNull);

    n.accept(v);
    assert(v.sql == `("users"."id" = "posts"."user_id") OR ("posts"."id" IS NULL)`);
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = table("users");
    auto n = new immutable ExpressionListNode([u["id"], u["email"], u["name"]]);

    n.accept(v);
    assert(v.sql == `"users"."id", "users"."email", "users"."name"`);
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto n = new immutable FromNode(table("users"));

    n.accept(v);
    assert(v.sql == `FROM "users"`);
}

@system unittest
{
    import sqld : SQLD;

    auto v = new PostgresVisitor;
    auto u = table("users");
    auto n = new immutable FromNode(SQLD.select.from(u));

    n.accept(v);
    assert(v.sql == `FROM (SELECT FROM "users")`);
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = table("users");
    auto n = new immutable IntoNode(u, u["name"], u["email"], u["password"]);

    n.accept(v);
    assert(v.sql == `INTO "users"("name", "email", "password")`);
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto n = new immutable LimitNode(500);

    n.accept(v);
    assert(v.sql == "LIMIT 500");
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto n = new immutable OffsetNode(500);

    n.accept(v);
    assert(v.sql == "OFFSET 500");
}

@system unittest
{
    auto v = new PostgresVisitor;
    auto u = table("users");
    auto n = new immutable OrderByNode(u["name"].asc, u["email"].desc, u["created_at"].asc);

    n.accept(v);
    assert(v.sql == `ORDER BY "users"."name" ASC, "users"."email" DESC, "users"."created_at" ASC`);
}
