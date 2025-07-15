#!/usr/bin/env python3
import json
import os
import sys
import urllib.request


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 geminicli.py \"<prompt>\" [--api-key KEY]")
        return

    prompt = sys.argv[1]
    api_key = None
    if "--api-key" in sys.argv:
        idx = sys.argv.index("--api-key")
        if idx + 1 >= len(sys.argv):
            print("Error: --api-key requires a value")
            return
        api_key = sys.argv[idx + 1]
    api_key = api_key or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("Gemini API key not provided. Use --api-key or set GEMINI_API_KEY.")
        return

    confirm = input("GeminiCLI will send your prompt to Gemini. Proceed? (y/n): ")
    if confirm.strip().lower() != "y":
        print("Aborted.")
        return

    endpoint = (
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key="
        + api_key
    )
    data = json.dumps({"contents": [{"parts": [{"text": prompt}]}]}).encode("utf-8")
    req = urllib.request.Request(endpoint, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read().decode("utf-8")
            res = json.loads(body)
            candidate = res.get("candidates", [{}])[0]
            text = candidate.get("content", {}).get("parts", [{}])[0].get("text", body)
            print(text)
    except Exception as e:
        print("Error:", e)


if __name__ == "__main__":
    main()
