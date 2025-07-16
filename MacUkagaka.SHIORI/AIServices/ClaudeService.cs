using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace MacUkagaka.SHIORI.AIServices;

public class ClaudeService : IAIService
{
    private readonly string _apiKey;
    private readonly string _model;

    public ClaudeService(string apiKey, string model)
    {
        _apiKey = apiKey;
        _model = string.IsNullOrEmpty(model) ? "claude-instant-1" : model;
    }

    public async Task<string> GenerateResponseAsync(string prompt)
    {
        var endpoint = "https://api.anthropic.com/v1/complete";
        var obj = new
        {
            prompt = prompt,
            model = _model,
            max_tokens_to_sample = 1024,
            stream = false
        };
        var json = JsonSerializer.Serialize(obj);
        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint);
        request.Content = new StringContent(json, Encoding.UTF8, "application/json");
        request.Headers.Add("X-API-Key", _apiKey);
        request.Headers.Add("anthropic-version", "2023-06-01");
        using var client = new HttpClient();
        var response = await client.SendAsync(request);
        var str = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(str);
        if (doc.RootElement.TryGetProperty("completion", out var c))
            return c.GetString() ?? str;
        return str;
    }
}
