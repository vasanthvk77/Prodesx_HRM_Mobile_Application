using System.Data;
using Microsoft.Data.SqlClient;

namespace backend.Data;

public class DataBaseConnection
{
    private readonly string? _connectionString;
    public DataBaseConnection(string? connectionString)
    {
        _connectionString = connectionString;
    }
    public IDbConnection CreateConnection()
    {
        var conn = new SqlConnection(_connectionString);
        conn.Open();
        return conn;
    }
}
