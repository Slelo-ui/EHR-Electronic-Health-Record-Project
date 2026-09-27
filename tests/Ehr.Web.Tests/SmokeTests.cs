using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Ehr.Web.Tests;

// Starts the whole app in memory (no network, no database yet) and requests the home page.
public class SmokeTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task Home_page_returns_200()
    {
        using var client = factory.CreateClient();
        using var response = await client.GetAsync("/", TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
