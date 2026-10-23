FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY src/GameHall.Api/GameHall.Api.csproj src/GameHall.Api/
RUN dotnet restore src/GameHall.Api/GameHall.Api.csproj
COPY src/ src/
RUN dotnet publish src/GameHall.Api/GameHall.Api.csproj -c Release -o /app/publish --no-restore /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080 \
    DOTNET_EnableDiagnostics=0
COPY --from=build /app/publish .
# Corre sem privilégios de root (a variável APP_UID existe nas imagens oficiais .NET 8+)
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "GameHall.Api.dll"]
