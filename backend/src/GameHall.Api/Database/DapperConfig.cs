using System.Data;
using Dapper;

namespace GameHall.Api.Database;

public static class DapperConfig
{
    private static int _registered;

    public static void Register()
    {
        if (Interlocked.Exchange(ref _registered, 1) == 1)
        {
            return;
        }

        // colunas snake_case (display_name) -> propriedades PascalCase (DisplayName)
        DefaultTypeMap.MatchNamesWithUnderscores = true;
        SqlMapper.AddTypeHandler(new DateOnlyTypeHandler());
    }
}

public sealed class DateOnlyTypeHandler : SqlMapper.TypeHandler<DateOnly>
{
    public override void SetValue(IDbDataParameter parameter, DateOnly value)
    {
        parameter.DbType = DbType.Date;
        parameter.Value = value;
    }

    public override DateOnly Parse(object value) => value switch
    {
        DateOnly d => d,
        DateTime dt => DateOnly.FromDateTime(dt),
        _ => throw new InvalidCastException($"Não é possível converter {value.GetType()} para DateOnly.")
    };
}
