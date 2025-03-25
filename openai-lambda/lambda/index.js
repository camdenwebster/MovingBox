const axios = require('axios');
const AWS = require('aws-sdk');
const zlib = require('zlib');
const { promisify } = require('util');
const gunzip = promisify(zlib.gunzip);
const brotliDecompress = promisify(zlib.brotliDecompress);
const jwt = require('jsonwebtoken');

// Initialize DynamoDB client for rate limiting
const dynamoDB = new AWS.DynamoDB.DocumentClient();
const RATE_LIMIT_TABLE = process.env.RATE_LIMIT_TABLE || 'OpenAIRateLimit';
const RATE_LIMIT_WINDOW = process.env.RATE_LIMIT_WINDOW || 60000; // 1 minute in milliseconds
const MAX_REQUESTS_PER_WINDOW = process.env.MAX_REQUESTS_PER_WINDOW || 60; // Adjust based on your OpenAI plan

// Get OpenAI API key from AWS Secrets Manager
let OPENAI_API_KEY;
const OPENAI_API_BASE_URL = 'https://api.openai.com';
const SECRET_NAME = process.env.OPENAI_API_KEY_SECRET_NAME;

// Function to get the secret
async function getOpenAIApiKey() {
    if (OPENAI_API_KEY) return OPENAI_API_KEY;
    
    const secretsManager = new AWS.SecretsManager();
    try {
        const data = await secretsManager.getSecretValue({ SecretId: SECRET_NAME }).promise();
        if (data.SecretString) {
            try {
                // Try to parse as JSON
                const secret = JSON.parse(data.SecretString);
                OPENAI_API_KEY = secret.OPENAI_API_KEY;
            } catch (e) {
                // If parsing fails, use the raw string
                OPENAI_API_KEY = data.SecretString;
            }
        }
        return OPENAI_API_KEY;
    } catch (error) {
        console.error('Error retrieving secret:', error);
        throw error;
    }
}

// Function to get the JWT secret from AWS Secrets Manager
let JWT_SECRET_CACHE;
async function getJwtSecret() {
    if (JWT_SECRET_CACHE) return JWT_SECRET_CACHE;

    const secretsManager = new AWS.SecretsManager();
    const secretName = process.env.JWT_SECRET_NAME; // Environment-specific secret name

    try {
        const data = await secretsManager.getSecretValue({ SecretId: secretName }).promise();
        if (data.SecretString) {
            JWT_SECRET_CACHE = data.SecretString;
        }
        return JWT_SECRET_CACHE;
    } catch (error) {
        console.error('Error retrieving JWT secret:', error);
        throw error;
    }
}

// Update the verifyToken function to use the secret from AWS Secrets Manager
const verifyToken = async (event) => {
    try {
        const authHeader = event.headers.Authorization || event.headers.authorization;
        if (!authHeader) {
            throw new Error('No authorization header');
        }

        const token = authHeader.replace('Bearer ', '');
        const jwtSecret = await getJwtSecret(); // Fetch the secret dynamically
        const decoded = jwt.verify(token, jwtSecret);

        // Check expiration
        if (decoded.exp < Date.now() / 1000) {
            throw new Error('Token expired');
        }

        return decoded;
    } catch (error) {
        console.error('JWT verification failed:', error);
        throw {
            statusCode: 401,
            message: 'Unauthorized: ' + error.message
        };
    }
};

exports.handler = async (event) => {
    try {
        // Verify JWT token first
        await verifyToken(event);
        
        // Get the OpenAI API key
        const apiKey = await getOpenAIApiKey();
        
        // Extract client identifier
        const clientId = extractClientId(event);
        
        // Check rate limiting
        await checkRateLimit(clientId);
        
        // Parse the request from the event
        const { path, method, body, headers } = parseRequest(event);
        
        // Forward the request to OpenAI
        const response = await forwardToOpenAI(path, method, body, headers, apiKey);
        
        // Return the uncompressed response
        return formatResponse(200, response.data);
    } catch (error) {
        console.error('Error:', error);
        
        const statusCode = error.statusCode || 500;
        let errorMessage = error.message || 'Internal server error';
        
        return formatResponse(statusCode, { error: errorMessage });
    }
};

/**
 * Extract client identifier from the request
 */
function extractClientId(event) {
    // You could use API key from headers, IP address, or query parameters
    // This is a basic implementation - adjust based on your authentication strategy
    const headers = event.headers || {};
    return headers['x-api-key'] || event.requestContext?.identity?.sourceIp || 'anonymous';
}

/**
 * Check rate limit for the client
 */
async function checkRateLimit(clientId) {
    const now = Date.now();
    const windowStart = now - RATE_LIMIT_WINDOW;
    
    try {
        // Get current rate limit data for client
        const params = {
            TableName: RATE_LIMIT_TABLE,
            Key: { clientId },
        };
        
        const result = await dynamoDB.get(params).promise();
        const item = result.Item || { clientId, requests: [], count: 0 };
        
        // Filter out old requests
        const recentRequests = item.requests.filter(timestamp => timestamp > windowStart);
        
        // Check if limit exceeded
        if (recentRequests.length >= MAX_REQUESTS_PER_WINDOW) {
            const error = new Error('Rate limit exceeded');
            error.statusCode = 429;
            throw error;
        }
        
        // Update rate limit data
        await dynamoDB.put({
            TableName: RATE_LIMIT_TABLE,
            Item: {
                clientId,
                requests: [...recentRequests, now],
                count: recentRequests.length + 1,
                lastRequest: now
            }
        }).promise();
    } catch (error) {
        if (error.statusCode === 429) {
            throw error;
        }
        console.error('Error checking rate limit:', error);
        // If there's a DynamoDB error, allow the request to proceed
    }
}

/**
 * Parse the request details from the Lambda event
 */
function parseRequest(event) {
    console.log('Raw body:', event.body); // Log the raw body for debugging

    let path = event.path || '';
    path = path.replace(/^\/+/, '');
    console.log('Parsed path:', path);

    let body = null;
    if (event.body) {
        if (event.isBase64Encoded) {
            // Decode Base64-encoded body
            const decodedBody = Buffer.from(event.body, 'base64').toString('utf-8');
            console.log('Decoded body:', decodedBody); // Log the decoded body for debugging
            try {
                body = JSON.parse(decodedBody); // Parse the decoded body as JSON
            } catch (e) {
                console.error('Error parsing decoded body:', e);
                throw new Error('Invalid JSON in request body');
            }
        } else if (typeof event.body === 'string') {
            try {
                body = JSON.parse(event.body); // Parse if it's a string
            } catch (e) {
                console.error('Error parsing body:', e);
                throw new Error('Invalid JSON in request body');
            }
        } else {
            body = event.body; // Use as-is if it's already an object
        }
    }

    const headers = event.headers || {};
    const forwardHeaders = {};
    Object.keys(headers).forEach(key => {
        const lowerKey = key.toLowerCase();
        if (!['host', 'x-api-key', 'content-length'].includes(lowerKey)) {
            forwardHeaders[lowerKey] = headers[key];
        }
    });

    const method = event.httpMethod || event.requestContext?.http?.method || 'GET';

    return { path, method, body, headers: forwardHeaders };
}

/**
 * Forward the request to OpenAI
 */
async function forwardToOpenAI(path, method, body, headers, apiKey) {
    const url = `${OPENAI_API_BASE_URL}/${path}`;
    console.log('Forwarding request to OpenAI URL:', url);
    console.log('Request body:', JSON.stringify(body, null, 2));

    const config = {
        method,
        url,
        headers: {
            ...headers,
            'Authorization': `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
            'Accept-Encoding': 'gzip, deflate, br'
        },
        decompress: false,  // We'll handle decompression ourselves
        responseType: 'arraybuffer'  // Get raw response data
    };

    if (body) {
        config.data = body;
    }

    try {
        const response = await axios(config);
        console.log('OpenAI response status:', response.status);
        console.log('OpenAI response headers:', response.headers);

        // Get the content encoding
        const contentEncoding = response.headers['content-encoding'];
        let decompressedData;

        // Handle different compression types
        if (contentEncoding === 'gzip') {
            decompressedData = await gunzip(response.data);
        } else if (contentEncoding === 'br') {
            decompressedData = await brotliDecompress(response.data);
        } else {
            // If no compression or unknown type, use as-is
            decompressedData = response.data;
        }

        // Convert to string and parse as JSON
        const textDecoder = new TextDecoder('utf-8');
        const jsonString = textDecoder.decode(decompressedData);
        const jsonData = JSON.parse(jsonString);

        console.log('Decompressed OpenAI response:', JSON.stringify(jsonData, null, 2));
        return { ...response, data: jsonData };
    } catch (error) {
        console.error('OpenAI API error:', error);
        if (error.response) {
            console.error('Error response data:', error.response.data.toString());
            console.error('Error response headers:', error.response.headers);
        }
        const statusCode = error.response ? error.response.status : 500;
        const message = error.response ? error.response.data.toString() : error.message;
        const customError = new Error(JSON.stringify(message));
        customError.statusCode = statusCode;
        throw customError;
    }
}

/**
 * Format Lambda response
 */
function formatResponse(statusCode, body) {
    let responseBody;
    try {
        // Ensure we're working with a plain object/string
        responseBody = typeof body === 'object' ? JSON.stringify(body) : body;
        
        if (typeof responseBody !== 'string') {
            responseBody = JSON.stringify(responseBody);
        }

        // Validate that we have valid JSON
        JSON.parse(responseBody);
    } catch (error) {
        console.error('Error formatting response:', error);
        statusCode = 500;
        responseBody = JSON.stringify({
            error: 'Error processing response',
            details: error.message
        });
    }

    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Content-Encoding': 'identity',  // Explicitly specify no compression
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,Content-Encoding'
        },
        body: responseBody,
        isBase64Encoded: false
    };
}
