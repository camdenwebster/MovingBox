#!/usr/bin/env python3
import os
from aws_cdk import App
from openai_lambda.openai_lambda_stack import OpenaiLambdaStack

app = App()

# Get OpenAI API key from environment variable
openai_api_key = os.environ.get("OPENAI_API_KEY")
if not openai_api_key:
    raise ValueError("OPENAI_API_KEY environment variable must be set")

OpenaiLambdaStack(
    app, 
    "OpenaiLambdaStack",
    openai_api_key=openai_api_key,
)

app.synth()
