#!/bin/bash

API_URL=https://7mc060nx64.execute-api.us-east-2.amazonaws.com/prod

curl -X POST "${API_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Hello, world!"}],
    "max_tokens": 50
  }'