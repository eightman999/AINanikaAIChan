#!/bin/bash
# Start the app in background
/Users/eightman/Desktop/software_develop/AINanikaAIChan/build/Debug/AINanikaAIChan.app/Contents/MacOS/AINanikaAIChan &
APP_PID=$!

# Wait 3 seconds
sleep 3

# Kill the app
kill $APP_PID 2>/dev/null

echo "Test completed"