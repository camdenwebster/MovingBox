#!/usr/bin/env python3
import os
from aws_cdk import App, Environment
from openai_lambda.openai_lambda_stack import OpenaiLambdaStack

app = App()  # Use App instead of core.App

# Retrieve secrets from environment variables
openai_api_key = os.getenv("OPENAI_API_KEY", "default-openai-api-key")
jwt_secret_value = os.getenv("JWT_SECRET_VALUE", "default-jwt-secret")
jwt_secret_name = os.getenv("JWT_SECRET_NAME", "default-jwt-secret-name")

OpenaiLambdaStack(
    app,
    "OpenaiLambdaStack",
    openai_api_key=openai_api_key,
    jwt_secret_value=jwt_secret_value,
    jwt_secret_name=jwt_secret_name,
    # If you need to specify environment, use the Environment class directly
    # env=Environment(account="123456789012", region="us-east-1"),
)

app.synth()
