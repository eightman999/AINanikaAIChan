using System.Text;
using MacUkagaka.SHIORI.AIServices;
using MacUkagaka.SHIORI.Models;
using MacUkagaka.SHIORI.Utils;

namespace MacUkagaka.SHIORI;

class Program
{
    static async Task Main(string[] args)
    {
        var configPath = args.Length > 0 ? args[0] : "config.json";
        var config = new ConfigManager(configPath);
        IAIService service = config.DefaultService switch
        {
            "claude" => new ClaudeService(config.GetApiKey("claude") ?? string.Empty, config.GetModel("claude") ?? string.Empty),
            "gemini" => new GeminiService(config.GetApiKey("gemini") ?? string.Empty, config.GetModel("gemini") ?? string.Empty),
            _ => new ChatGPTService(config.GetApiKey("chatgpt") ?? string.Empty, config.GetModel("chatgpt") ?? string.Empty)
        };

        while (true)
        {
            var requestText = ReadRequest();
            if (requestText == null) break;

            var request = SHIORIRequest.Parse(requestText);
            string value = string.Empty;
            if (request.Id == "OnBoot")
            {
                value = SakuraScriptBuilder.Simple("こんにちは！MacUkagakaです。");
            }
            else if (request.Id == "OnClose")
            {
                value = SakuraScriptBuilder.Simple("さようなら！");
            }
            else if (request.Id == "OnTalk")
            {
                var prompt = request.GetReference(0) ?? string.Empty;
                value = SakuraScriptBuilder.Simple(await service.GenerateResponseAsync(prompt));
            }

            var response = new SHIORIResponse { Value = value };
            Console.Write(response.ToString());
        }
    }

    static string? ReadRequest()
    {
        var sb = new StringBuilder();
        string? line;
        while ((line = Console.ReadLine()) != null)
        {
            sb.AppendLine(line);
            if (string.IsNullOrWhiteSpace(line))
                break;
        }
        if (sb.Length == 0)
            return null;
        return sb.ToString();
    }
}
