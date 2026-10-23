namespace GameHall.Api.Modules.Geo;

/// <summary>Lista de distritos e concelhos para os filtros da app. Dados fixos, sem base de dados.</summary>
public static class GeoEndpoints
{
    public static void MapGeoEndpoints(this IEndpointRouteBuilder app) =>
        app.MapGet("/api/v1/geo/districts", () => Results.Ok(PortugalGeo.Districts));
}
