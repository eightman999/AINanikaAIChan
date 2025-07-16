using System.IO;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace MacUkagaka.SHIORI.Utils;

public class ConfigManager
{
    private readonly JsonNode _root;

    public ConfigManager(string path)
    {
        var json = File.ReadAllText(path);
        _root = JsonNode.Parse(json)!;
    }

    public string DefaultService => _root["ai_settings"]?["default_service"]?.ToString() ?? "chatgpt";

    public string? GetApiKey(string service) => _root["ai_settings"]?[service]? ["api_key"]?.ToString();

    public string? GetModel(string service) => _root["ai_settings"]?[service]? ["model"]?.ToString();
}
