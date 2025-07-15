#r "System.Net.Http"
using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

if (Args.Length < 1)
{
    Console.WriteLine("Usage: dotnet script geminicli.csx \"<prompt>\" [--api-key KEY]");
    return;
}

string prompt = Args[0];
string apiKey = null;
for (int i = 1; i < Args.Length; i++)
{
    if (Args[i] == "--api-key" && i + 1 < Args.Length)
    {
        apiKey = Args[i + 1];
        i++;
    }
}
apiKey = apiKey ?? Environment.GetEnvironmentVariable("GEMINI_API_KEY");
if (string.IsNullOrEmpty(apiKey))
{
    Console.WriteLine("Gemini API key not provided. Use --api-key or set GEMINI_API_KEY.");
    return;
}

Console.Write("GeminiCLI will send your prompt to Gemini. Proceed? (y/n): ");
var confirm = Console.ReadLine();
if (confirm?.Trim().ToLower() != "y")
{
    Console.WriteLine("Aborted.");
    return;
}

var endpoint = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key={apiKey}";
var reqObj = new { contents = new[] { new { parts = new[] { new { text = prompt } } } } };
var json = JsonSerializer.Serialize(reqObj);
using var client = new HttpClient();
var content = new StringContent(json, Encoding.UTF8, "application/json");

try
{
    var resp = await client.PostAsync(endpoint, content);
    var body = await resp.Content.ReadAsStringAsync();
    using var doc = JsonDocument.Parse(body);
    var candidate = doc.RootElement.GetProperty("candidates")[0];
    var text = candidate.GetProperty("content").GetProperty("parts")[0].GetProperty("text").GetString();
    Console.WriteLine(text);
}
catch (Exception e)
{
    Console.WriteLine("Error: " + e.ToString());
}
