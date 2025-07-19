import Foundation

func main() {
    let args = CommandLine.arguments
    guard args.count > 1 else {
        print("Usage: swift geminicli.swift \"<prompt>\" [--api-key KEY]")
        return
    }
    let prompt = args[1]
    var apiKey: String? = nil
    if let idx = args.firstIndex(of: "--api-key") {
        if idx + 1 >= args.count {
            print("Error: --api-key requires a value")
            return
        }
        apiKey = args[idx + 1]
    }
    if apiKey == nil {
        apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
    }
    guard let key = apiKey, !key.isEmpty else {
        print("Gemini API key not provided. Use --api-key or set GEMINI_API_KEY.")
        return
    }

    print("GeminiCLI will send your prompt to Gemini. Proceed? (y/n): ", terminator: "")
    guard let confirm = readLine(), confirm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "y" else {
        print("Aborted.")
        return
    }

    guard let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=\(key)") else {
        print("Invalid endpoint URL")
        return
    }

    let requestObject: [String: Any] = [
        "contents": [["parts": [["text": prompt]]]]
    ]
    guard let bodyData = try? JSONSerialization.data(withJSONObject: requestObject) else {
        print("Failed to encode request")
        return
    }

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = bodyData

    let semaphore = DispatchSemaphore(value: 0)
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        if let error = error {
            print("Error: \(error)")
            return
        }
        guard let data = data else {
            print("No response data")
            return
        }
        if
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let candidate = candidates.first,
            let content = candidate["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        {
            print(text)
        } else if let body = String(data: data, encoding: .utf8) {
            print(body)
        } else {
            print("Unknown response")
        }
    }
    task.resume()
    semaphore.wait()
}

main()
