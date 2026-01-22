# ============================================
# Lambda Function para Autenticação por CPF
# Consulta cliente no microsserviço customer e gera token JWT
# ============================================

# IAM Role para Lambda (usando LabRole do AWS Academy)
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Arquivo ZIP com o código da Lambda
data "archive_file" "lambda_auth" {
  type        = "zip"
  output_path = "${path.module}/lambda_auth.zip"

  source {
    content  = <<-EOF
const https = require('https');
const http = require('http');

// Configuração
const CUSTOMER_SERVICE_URL = process.env.CUSTOMER_SERVICE_URL || 'http://customer-service.tech-challenge:80';

// Helper para fazer requisições HTTP
function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    const req = protocol.get(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ statusCode: res.statusCode, body: JSON.parse(data) });
        } catch (e) {
          resolve({ statusCode: res.statusCode, body: data });
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

// Validar formato do CPF
function isValidCpfFormat(cpf) {
  if (!cpf) return false;
  const cleanCpf = cpf.replace(/\D/g, '');
  return cleanCpf.length === 11;
}

// Handler principal
exports.handler = async (event) => {
  console.log('Event received:', JSON.stringify(event));
  
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
  };

  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }

  try {
    // Extrair CPF do request
    let cpf;
    if (event.body) {
      const body = JSON.parse(event.body);
      cpf = body.cpf;
    } else if (event.queryStringParameters) {
      cpf = event.queryStringParameters.cpf;
    } else if (event.pathParameters) {
      cpf = event.pathParameters.cpf;
    }

    // Validar CPF
    if (!cpf) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ 
          error: 'CPF is required',
          message: 'Por favor, informe o CPF para identificação'
        })
      };
    }

    if (!isValidCpfFormat(cpf)) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ 
          error: 'Invalid CPF format',
          message: 'CPF deve conter 11 dígitos'
        })
      };
    }

    const cleanCpf = cpf.replace(/\D/g, '');

    // Consultar cliente no microsserviço customer
    console.log('Validando CPF:', cleanCpf);
    
    // Retorna sucesso - autenticação removida
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        message: 'CPF validado com sucesso',
        cpf: cleanCpf
      })
    };

  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ 
        error: 'Internal server error',
        message: error.message 
      })
    };
  }
};
EOF
    filename = "index.js"
  }
}

# Lambda Function
resource "aws_lambda_function" "auth_cpf" {
  filename         = data.archive_file.lambda_auth.output_path
  function_name    = "tech-challenge-auth-cpf"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_auth.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      CUSTOMER_SERVICE_URL = "http://${data.aws_lb.app_nlb.dns_name}/api/customers"
    }
  }

  tags = {
    Name        = "tech-challenge-auth-cpf"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# Permissão para API Gateway invocar a Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_cpf.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.tech_challenge_api.execution_arn}/*/*"
}

# ============================================
# API Gateway - Endpoint de Autenticação
# ============================================

# Resource /auth
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.tech_challenge_api.id
  parent_id   = aws_api_gateway_rest_api.tech_challenge_api.root_resource_id
  path_part   = "auth"
}

# Resource /auth/cpf
resource "aws_api_gateway_resource" "auth_cpf" {
  rest_api_id = aws_api_gateway_rest_api.tech_challenge_api.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "cpf"
}

# POST /auth/cpf - Autenticação por CPF
resource "aws_api_gateway_method" "post_auth_cpf" {
  rest_api_id   = aws_api_gateway_rest_api.tech_challenge_api.id
  resource_id   = aws_api_gateway_resource.auth_cpf.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integração com Lambda
resource "aws_api_gateway_integration" "auth_cpf_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.tech_challenge_api.id
  resource_id             = aws_api_gateway_resource.auth_cpf.id
  http_method             = aws_api_gateway_method.post_auth_cpf.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.auth_cpf.invoke_arn
}

# OPTIONS para CORS
resource "aws_api_gateway_method" "options_auth_cpf" {
  rest_api_id   = aws_api_gateway_rest_api.tech_challenge_api.id
  resource_id   = aws_api_gateway_resource.auth_cpf.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_auth_cpf" {
  rest_api_id = aws_api_gateway_rest_api.tech_challenge_api.id
  resource_id = aws_api_gateway_resource.auth_cpf.id
  http_method = aws_api_gateway_method.options_auth_cpf.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_auth_cpf" {
  rest_api_id = aws_api_gateway_rest_api.tech_challenge_api.id
  resource_id = aws_api_gateway_resource.auth_cpf.id
  http_method = aws_api_gateway_method.options_auth_cpf.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_auth_cpf" {
  rest_api_id = aws_api_gateway_rest_api.tech_challenge_api.id
  resource_id = aws_api_gateway_resource.auth_cpf.id
  http_method = aws_api_gateway_method.options_auth_cpf.http_method
  status_code = aws_api_gateway_method_response.options_auth_cpf.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}
