#!/bin/sh
DIR="$(dirname "$0")"
if [ -f "$DIR/geminicli.py" ]; then
    exec python3 "$DIR/geminicli.py" "$@"
elif [ -f "$DIR/geminicli.csx" ]; then
    if command -v dotnet >/dev/null 2>&1; then
        exec dotnet script "$DIR/geminicli.csx" "$@"
    else
        echo "dotnet not found"
        exit 1
    fi
else
    echo "GeminiCLI not found"
    exit 1
fi
