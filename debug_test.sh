#!/bin/bash

echo "Starting AINanikaAIChan with debug output..."

# Start the app and capture output
/Users/eightman/Desktop/software_develop/AINanikaAIChan/build/Debug/AINanikaAIChan.app/Contents/MacOS/AINanikaAIChan > /tmp/ainanikaichan_debug.log 2>&1 &
APP_PID=$!

echo "App started with PID: $APP_PID"
echo "Waiting 5 seconds for initialization..."
sleep 5

echo "Debug output so far:"
echo "==================="
cat /tmp/ainanikaichan_debug.log
echo "==================="

# Kill the app
kill $APP_PID 2>/dev/null
wait $APP_PID 2>/dev/null

echo "App stopped. Full debug log saved to /tmp/ainanikaichan_debug.log"