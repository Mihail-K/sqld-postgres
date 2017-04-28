
module sqld.postgres.escape;

@property
string escapeString(string input)
{
    return "'" ~ input ~ "'"; // TODO
}
