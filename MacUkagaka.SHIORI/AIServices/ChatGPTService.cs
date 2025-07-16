using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace MacUkagaka.SHIORI.AIServices;

public class ChatGPTService : IAIService
{
    private readonly string _apiKey;
    private readonly string _model;

    public ChatGPTService(string apiKey, string model)
    {
        _apiKey = apiKey;
        _model = string.IsNullOrEmpty(model) ? "gpt-3.5-turbo" : model;
    }

    public async Task<string> GenerateResponseAsync(string prompt)
    {
        var endpoint = "https://api.openai.com/v1/chat/completions";
        var obj = new
        {
            model = _model,
            messages = new[] { new { role = "user", content = prompt } }
        };
        var json = JsonSerializer.Serialize(obj);
        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint);
        request.Headers.Add("Authorization", $"Bearer {_apiKey}");
        request.Content = new StringContent(json, Encoding.UTF8, "application/json");
        using var client = new HttpClient();
        var response = await client.SendAsync(request);
        var str = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(str);
        var content = doc.RootElement
            .GetProperty("choices")[0]
            .GetProperty("message")
            .GetProperty("content").GetString();
        return content ?? str;
    }
}
