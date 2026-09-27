# Build context is the repository root (see infra/compose/compose.yaml).
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore first, from the project files alone, so code changes don't invalidate the package cache.
COPY global.json Directory.Build.props Directory.Packages.props ./
COPY src/Ehr.Web/Ehr.Web.csproj src/Ehr.Web/
COPY src/Ehr.Domain/Ehr.Domain.csproj src/Ehr.Domain/
COPY src/Ehr.Data/Ehr.Data.csproj src/Ehr.Data/
COPY src/Ehr.Design/Ehr.Design.csproj src/Ehr.Design/
RUN dotnet restore src/Ehr.Web/Ehr.Web.csproj

COPY src/Ehr.Web/ src/Ehr.Web/
COPY src/Ehr.Domain/ src/Ehr.Domain/
COPY src/Ehr.Data/ src/Ehr.Data/
COPY src/Ehr.Design/ src/Ehr.Design/
RUN dotnet publish src/Ehr.Web/Ehr.Web.csproj --configuration Release --no-restore --output /app

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
# The image ships a non-root user but starts as root unless told otherwise.
USER $APP_UID
ENTRYPOINT ["dotnet", "Ehr.Web.dll"]
