from aws_cdk import (
    Stack,
    Duration,
    RemovalPolicy,
    aws_lambda as lambda_,
    aws_apigateway as apigw,
    aws_dynamodb as dynamodb,
    aws_secretsmanager as secretsmanager,
    aws_iam as iam,
    SecretValue,
)
from constructs import Construct

class OpenaiLambdaStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, openai_api_key: str, jwt_secret_value: str, jwt_secret_name: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create Secrets Manager secret for OpenAI API key
        openai_api_key_secret = secretsmanager.Secret(
            self, "OpenAIApiKeySecret",
            secret_name=f"{construct_id}-openai-api-key",
            description="Secret containing the OpenAI API key",
            removal_policy=RemovalPolicy.DESTROY,  # Change to RETAIN for production
            secret_string_value=SecretValue.unsafe_plain_text(openai_api_key),
        )

        # Create Secrets Manager secret for JWT secret
        jwt_secret = secretsmanager.Secret(
            self, "JwtSecret",
            secret_name=jwt_secret_name,
            description="Secret containing the JWT signing key",
            removal_policy=RemovalPolicy.DESTROY,  # Change to RETAIN for production
            secret_string_value=SecretValue.unsafe_plain_text(jwt_secret_value),  # Use the value passed in
        )

        # DynamoDB table for rate limiting
        rate_limit_table = dynamodb.Table(
            self, "OpenAIRateLimitTable",
            table_name=f"{construct_id}-rate-limit",
            partition_key=dynamodb.Attribute(
                name="clientId",
                type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            removal_policy=RemovalPolicy.DESTROY,  # Change to RETAIN for production
            time_to_live_attribute="ttl",
        )

        # Lambda function to proxy OpenAI API requests
        openai_proxy_lambda = lambda_.Function(
            self, "OpenAIProxyLambda",
            function_name=f"{construct_id}-lambda",
            runtime=lambda_.Runtime.NODEJS_16_X,
            handler="index.handler",
            code=lambda_.Code.from_asset("./lambda"),  # Directory containing Lambda code
            timeout=Duration.seconds(30),
            memory_size=256,
            environment={
                "RATE_LIMIT_TABLE": rate_limit_table.table_name,
                "MAX_REQUESTS_PER_WINDOW": "60",
                "RATE_LIMIT_WINDOW": "60000",
                "OPENAI_API_KEY_SECRET_NAME": openai_api_key_secret.secret_name,
                "JWT_SECRET_NAME": jwt_secret.secret_name,  # Pass the secret name as an environment variable
            },
        )

        # Grant Lambda permissions to read the secret
        openai_api_key_secret.grant_read(openai_proxy_lambda)
        
        # Grant Lambda permissions to read the JWT secret
        jwt_secret.grant_read(openai_proxy_lambda)

        # Grant Lambda permissions to read/write to DynamoDB
        rate_limit_table.grant_read_write_data(openai_proxy_lambda)

        # Create API Gateway
        api = apigw.RestApi(
            self, "OpenAIProxyApi",
            rest_api_name=f"{construct_id}-api",
            description="API Gateway for OpenAI Proxy",
            binary_media_types=["*/*"],
            default_cors_preflight_options=apigw.CorsOptions(
                allow_origins=apigw.Cors.ALL_ORIGINS,
                allow_methods=apigw.Cors.ALL_METHODS,
                allow_headers=[
                    "Content-Type",
                    "X-Amz-Date",
                    "Authorization",
                    "X-Api-Key",
                ],
            ),
        )

        # Add proxy resource to handle all paths
        proxy_resource = api.root.add_resource("{proxy+}")
        proxy_integration = apigw.LambdaIntegration(openai_proxy_lambda)
        proxy_resource.add_method("ANY", proxy_integration)

        # Also add a method to the root resource for requests without a path
        api.root.add_method("ANY", proxy_integration)