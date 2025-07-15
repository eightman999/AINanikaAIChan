#r "Newtonsoft.Json.dll"
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json.Serialization;
using System;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

public interface IAITalk
{
    string Response { get; }
    bool IsProcessing { get; }
}

public class ChatGPTTalk : IAITalk
{
    public string Response { get; private set; } = string.Empty;
    public bool IsProcessing { get; private set; }

    public ChatGPTTalk(string apiKey, ChatGPTRequest chatGPTRequest)
    {
        _ = Process(apiKey, chatGPTRequest);
    }

    async Task Process(string apiKey, ChatGPTRequest chatGPTRequest)
    {
        IsProcessing = true;
        try
        {
            if (!chatGPTRequest.stream)
                throw new InvalidOperationException("stream should be true");

            var result = "";
            var endpoint = "https://api.openai.com/v1/chat/completions";

            var json = JsonConvert.SerializeObject(chatGPTRequest);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            using (var request = new HttpRequestMessage(HttpMethod.Post, endpoint))
            {
                request.Headers.Add("Authorization", $"Bearer {apiKey}");
                request.Content = content;

                var client = new HttpClient();
                using (var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead))
                using (var stream = await response.Content.ReadAsStreamAsync())
                using (var reader = new StreamReader(stream))
                {
                    while (!reader.EndOfStream)
                    {
                        var line = await reader.ReadLineAsync();
                        
                        if (!line.StartsWith("data:"))
                            continue;
                        var dataContent = line.Substring(6);
                        if (dataContent == "[DONE]")
                            continue;
                        var chunk = JsonConvert.DeserializeObject<ChatGPTStreamChunk>(dataContent);
                        var delta = chunk?.choices?.FirstOrDefault()?.delta?.content;
                        if (!string.IsNullOrEmpty(delta))
                        {
                            result += delta;
                            Response = result;
                        }
                    }
                }
            }
        }
        catch (Exception e)
        {
            Response = e.ToString();
        }
        finally
        {
            IsProcessing = false;
        }
    }
}

public class ClaudeTalk : IAITalk
{
    public string Response { get; private set; } = string.Empty;
    public bool IsProcessing { get; private set; }

    public ClaudeTalk(string apiKey, string prompt)
    {
        _ = Process(apiKey, prompt);
    }

    async Task Process(string apiKey, string prompt)
    {
        IsProcessing = true;
        try
        {
            var endpoint = "https://api.anthropic.com/v1/complete";
            var obj = new
            {
                prompt = prompt,
                model = "claude-instant-1",
                max_tokens_to_sample = 1024,
                stream = false
            };
            var json = JsonConvert.SerializeObject(obj);
            using(var request = new HttpRequestMessage(HttpMethod.Post, endpoint))
            {
                request.Content = new StringContent(json, Encoding.UTF8, "application/json");
                request.Headers.Add("X-API-Key", apiKey);
                request.Headers.Add("anthropic-version", "2023-06-01");
                var client = new HttpClient();
                var response = await client.SendAsync(request);
                var str = await response.Content.ReadAsStringAsync();
                dynamic res = JsonConvert.DeserializeObject(str);
                Response = res?.completion ?? str;
            }
        }
        catch(Exception e)
        {
            Response = e.ToString();
        }
        finally
        {
            IsProcessing = false;
        }
    }
}

public class GeminiTalk : IAITalk
{
    public string Response { get; private set; } = string.Empty;
    public bool IsProcessing { get; private set; }

    public GeminiTalk(string apiKey, string prompt)
    {
        _ = Process(apiKey, prompt);
    }

    async Task Process(string apiKey, string prompt)
    {
        IsProcessing = true;
        try
        {
            var endpoint = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key={apiKey}";
            var obj = new
            {
                contents = new[] { new { parts = new[] { new { text = prompt } } } }
            };
            var json = JsonConvert.SerializeObject(obj);
            using(var request = new HttpRequestMessage(HttpMethod.Post, endpoint))
            {
                request.Content = new StringContent(json, Encoding.UTF8, "application/json");
                var client = new HttpClient();
                var response = await client.SendAsync(request);
                var str = await response.Content.ReadAsStringAsync();
                dynamic res = JsonConvert.DeserializeObject(str);
                Response = res?.candidates?[0]?.content?.parts?[0]?.text ?? str;
            }
        }
        catch(Exception e)
        {
            Response = e.ToString();
        }
        finally
        {
            IsProcessing = false;
        }
    }
}
public class ChatGPTRequest
{
    public string model;
    public ChatGPTMessage[] messages;
    public bool stream;
}
public class ChatGPTMessage
{
    public string role;
    public string content;
}
public class ChatGPTResponse
{
    public string id;
    public string @object;
    public int created;
    public string model;
    public ChatGPTUsage usage;
    public ChatGPTChoice[] choices;
}
public class ChatGPTUsage
{
    public int prompt_tokens;
    public int completion_tokens;
    public int total_tokens;
}
public class ChatGPTChoice
{
    public ChatGPTMessage message;
    public string finish_reason;
    public int index;
}
public class ChatGPTStreamChunk
{
    public string id;
    public string @object;
    public int created;
    public string model;
    public ChatGPTChoiceDelta[] choices;
    public int index;
    public string finish_reason;
}
public class ChatGPTChoiceDelta
{
    public ChatGPTMessage delta;
    public string finish_reason;
    public int index;
}