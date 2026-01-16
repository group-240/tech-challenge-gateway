# 🌐 Tech Challenge - API Gateway

Repositório responsável pelo API Gateway que expõe os microserviços para o mundo externo.

## 📐 Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                    INTERNET                                          │
│                                        │                                             │
│                                        ▼                                             │
│                          ┌─────────────────────────┐                                │
│                          │     API Gateway         │                                │
│                          │   (Regional Endpoint)   │                                │
│                          │                         │                                │
│                          │  ┌─────────────────┐   │                                │
│                          │  │ Cognito         │   │   ← Autenticação JWT           │
│                          │  │ Authorizer      │   │                                │
│                          │  └─────────────────┘   │                                │
│                          │                         │                                │
│                          │  ┌─────────────────┐   │                                │
│                          │  │ Lambda Auth     │   │   ← Identificação por CPF      │
│                          │  │ (POST /auth/cpf)│   │                                │
│                          │  └─────────────────┘   │                                │
│                          └───────────┬─────────────┘                                │
│                                      │                                              │
│                                      ▼                                              │
│                          ┌─────────────────────────┐                                │
│                          │      VPC Link           │                                │
│                          └───────────┬─────────────┘                                │
│                                      │                                              │
│                                      ▼                                              │
│   ┌──────────────────────────────────────────────────────────────────────────────┐ │
│   │                         VPC (Private Subnets)                                 │ │
│   │                                                                               │ │
│   │   ┌─────────────────────────────────────────────────────────────────────┐    │ │
│   │   │                    Network Load Balancer (NLB)                       │    │ │
│   │   └─────────────────────────────┬───────────────────────────────────────┘    │ │
│   │                                 │                                            │ │
│   │   ┌─────────────────────────────┴───────────────────────────────────────┐    │ │
│   │   │                         EKS Cluster                                  │    │ │
│   │   │                                                                      │    │ │
│   │   │   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐           │    │ │
│   │   │   │   Customer   │   │    Orders    │   │   Payments   │           │    │ │
│   │   │   │   Service    │   │   Service    │   │   Service    │           │    │ │
│   │   │   │   :8080      │   │   :8080      │   │   :8080      │           │    │ │
│   │   │   └──────────────┘   └──────────────┘   └──────────────┘           │    │ │
│   │   │                                                                      │    │ │
│   │   └──────────────────────────────────────────────────────────────────────┘    │ │
│   │                                                                               │ │
│   └───────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

## 🔐 Fluxo de Autenticação

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                         FLUXO DE AUTENTICAÇÃO                                        │
└──────────────────────────────────────────────────────────────────────────────────────┘

  OPÇÃO 1: Cliente Identificado (com CPF)
  ═══════════════════════════════════════

  ┌─────────┐    1. POST /auth/cpf     ┌─────────────┐
  │ Cliente │ ──────────────────────▶  │   Lambda    │
  │         │    { "cpf": "123..." }   │  Auth CPF   │
  └─────────┘                          └──────┬──────┘
       │                                      │
       │                                      ▼ 2. Valida CPF
       │                               ┌─────────────┐
       │                               │  Customer   │
       │                               │  Service    │
       │                               └──────┬──────┘
       │                                      │
       │    3. Token JWT                      ▼
       │◀──────────────────────────────────────
       │
       ▼ 4. Usa Token nas requisições
  ┌─────────────────────────────────────────────────────────────────┐
  │ GET /orders                                                      │
  │ Authorization: Bearer <token>                                    │
  └─────────────────────────────────────────────────────────────────┘


  OPÇÃO 2: Cliente Anônimo (sem identificação)
  ════════════════════════════════════════════

  ┌─────────┐                          ┌─────────────┐
  │ Cliente │ ──────────────────────▶  │ Rotas       │
  │ Anônimo │    Sem Authorization     │ Públicas    │
  └─────────┘                          └─────────────┘

  Rotas públicas disponíveis:
  • GET /categories
  • GET /products
  • POST /customers (registro)
  • POST /webhooks (callbacks externos)
```

## 📋 Rotas Disponíveis

### 🔓 Rotas Públicas (sem autenticação)

| Método | Rota | Descrição | Microserviço |
|--------|------|-----------|--------------|
| `GET` | `/health` | Health check do sistema | Orders |
| `GET` | `/categories` | Listar categorias | Orders |
| `GET` | `/products` | Listar produtos | Orders |
| `POST` | `/customers` | Registrar novo cliente | Customer |
| `POST` | `/webhooks` | Webhook do Mercado Pago | Orders |
| `POST` | `/auth/cpf` | Autenticação por CPF | Lambda |

### 🔒 Rotas Protegidas (requer token JWT)

| Método | Rota | Descrição | Microserviço |
|--------|------|-----------|--------------|
| `POST` | `/categories` | Criar categoria | Orders |
| `POST` | `/products` | Criar produto | Orders |
| `GET` | `/orders` | Listar pedidos | Orders |
| `POST` | `/orders` | Criar pedido | Orders |
| `PUT` | `/orders/{id}/status` | Atualizar status do pedido | Orders |
| `GET` | `/customers` | Listar clientes | Customer |
| `POST` | `/payments` | Criar pagamento | Payments |
| `GET` | `/payments/{id}` | Consultar pagamento | Payments |

## 🚀 Guia de Uso Passo a Passo

### Passo 1: Obter a URL do API Gateway

Após o deploy, a URL estará disponível no output do Terraform:
```bash
# No diretório do gateway
terraform output api_gateway_invoke_url
# Exemplo: https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev
```

### Passo 2: Testar Health Check

```bash
# Verificar se o sistema está funcionando
curl https://<API_GATEWAY_URL>/dev/health
```

**Resposta esperada:**
```json
{
  "status": "UP",
  "timestamp": "2026-01-15T10:00:00Z"
}
```

### Passo 3: Registrar um Cliente (Público)

```bash
curl -X POST https://<API_GATEWAY_URL>/dev/customers \
  -H "Content-Type: application/json" \
  -d '{
    "name": "João Silva",
    "email": "joao@email.com",
    "cpf": "12345678901"
  }'
```

**Resposta esperada:**
```json
{
  "id": "uuid-do-cliente",
  "name": "João Silva",
  "email": "joao@email.com",
  "cpf": "12345678901"
}
```

### Passo 4: Autenticar com CPF (Obter Token)

```bash
curl -X POST https://<API_GATEWAY_URL>/dev/auth/cpf \
  -H "Content-Type: application/json" \
  -d '{
    "cpf": "12345678901"
  }'
```

**Resposta esperada:**
```json
{
  "success": true,
  "message": "Cliente identificado com sucesso",
  "cpf": "12345678901",
  "token": "eyJzdWIiOiIxMjM0NTY3ODkwMSIsImNwZiI6IjEyMzQ1Njc4OTAxIiwiaWF0IjoxNzA1MzE...",
  "expiresIn": 3600
}
```

### Passo 5: Usar o Token nas Requisições Protegidas

```bash
# Salvar o token em uma variável
TOKEN="eyJzdWIiOiIxMjM0NTY3ODkwMSIsImNwZiI6IjEyMzQ1Njc4OTAxIiwiaWF0IjoxNzA1MzE..."

# Listar pedidos (rota protegida)
curl -X GET https://<API_GATEWAY_URL>/dev/orders \
  -H "Authorization: Bearer $TOKEN"

# Criar um pedido
curl -X POST https://<API_GATEWAY_URL>/dev/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "cpf": "12345678901",
    "items": [
      {
        "productId": "uuid-do-produto",
        "quantity": 2
      }
    ]
  }'
```

### Passo 6: Consultar Produtos (Público)

```bash
# Listar todos os produtos
curl https://<API_GATEWAY_URL>/dev/products

# Listar categorias
curl https://<API_GATEWAY_URL>/dev/categories
```

### Passo 7: Criar um Pagamento

```bash
curl -X POST https://<API_GATEWAY_URL>/dev/payments \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "amount": 100.00,
    "description": "Pedido #123",
    "paymentMethodId": "pix",
    "installments": 1,
    "payerEmail": "joao@email.com",
    "identificationType": "CPF",
    "identificationNumber": "12345678901"
  }'
```

### Passo 8: Consultar Status do Pagamento

```bash
curl -X GET https://<API_GATEWAY_URL>/dev/payments/1325737896 \
  -H "Authorization: Bearer $TOKEN"
```

## 🔑 Como Funciona a Autenticação

### AWS Cognito User Pool

O Cognito é usado como **authorizer** do API Gateway para validar tokens JWT.

```
┌────────────────────────────────────────────────────────────────────┐
│                    COGNITO USER POOL                               │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  User Pool: tech-challenge-user-pool                         │ │
│  │                                                              │ │
│  │  • Gerencia identidades de usuários                          │ │
│  │  • Emite tokens JWT (Access Token, ID Token)                 │ │
│  │  • Valida tokens automaticamente via API Gateway Authorizer  │ │
│  │                                                              │ │
│  │  App Client:                                                 │ │
│  │  • Client ID: usado para autenticação                        │ │
│  │  • Sem client secret (para apps públicos)                    │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### Lambda de Autenticação por CPF

A Lambda `/auth/cpf` permite autenticação simplificada usando apenas o CPF:

```javascript
// Fluxo da Lambda
1. Recebe CPF no body da requisição
2. Valida formato do CPF (11 dígitos)
3. Consulta cliente no microserviço Customer
4. Gera token JWT com informações do cliente
5. Retorna token para uso nas rotas protegidas
```

### Estrutura do Token JWT

```json
{
  "sub": "12345678901",      // CPF do cliente
  "cpf": "12345678901",      // CPF (redundância)
  "iat": 1705312800,         // Issued At (timestamp)
  "exp": 1705316400,         // Expiration (1 hora)
  "iss": "tech-challenge-auth" // Issuer
}
```

## 📦 O que este repositório cria

| Recurso | Descrição |
|---------|-----------|
| `aws_api_gateway_rest_api` | API Gateway REST regional |
| `aws_api_gateway_stage` | Stage "dev" para deployment |
| `aws_api_gateway_vpc_link` | VPC Link para conectar ao NLB |
| `aws_api_gateway_authorizer` | Cognito Authorizer para JWT |
| `aws_lambda_function` | Lambda para autenticação por CPF |
| Resources e Methods | Endpoints para cada rota |
| Integrações HTTP_PROXY | Conexão com microserviços via VPC Link |

## 📋 Outputs Exportados

| Output | Descrição | Usado Por |
|--------|-----------|-----------|
| `api_gateway_invoke_url` | URL pública do API Gateway | Frontend, Postman |
| `api_gateway_id` | ID do API Gateway | Referências |
| `vpc_link_id` | ID do VPC Link | Debug |
| `lambda_auth_function_name` | Nome da Lambda de auth | Logs |

## 📦 Dependências (Remote State)

```hcl
# Infra (VPC, EKS, Cognito, NLB)
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "tech-challenge-tfstate-group240"
    key    = "infra/terraform.tfstate"
    region = "us-east-1"
  }
}
```

| Dependência | Outputs Utilizados |
|-------------|-------------------|
| tech-challenge-infra | `nlb_arn`, `cognito_user_pool_arn`, `cognito_user_pool_id`, `cognito_user_pool_client_id` |

## 🔐 Secrets Necessários (GitHub)

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (obrigatório para AWS Academy Learner Lab)

## 🚀 Como executar

```bash
cd terraform

# Inicializar Terraform
terraform init

# Verificar plano de execução
terraform plan

# Aplicar infraestrutura
terraform apply
```

## 📝 Exemplos com cURL

### Fluxo Completo: Do Registro ao Pedido

```bash
# 1. Definir URL base
API_URL="https://<API_GATEWAY_URL>/dev"

# 2. Registrar cliente
curl -X POST "$API_URL/customers" \
  -H "Content-Type: application/json" \
  -d '{"name": "Maria Santos", "email": "maria@email.com", "cpf": "98765432100"}'

# 3. Autenticar e obter token
TOKEN=$(curl -s -X POST "$API_URL/auth/cpf" \
  -H "Content-Type: application/json" \
  -d '{"cpf": "98765432100"}' | jq -r '.token')

# 4. Listar categorias (público)
curl "$API_URL/categories"

# 5. Criar categoria (autenticado)
curl -X POST "$API_URL/categories" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name": "Lanches"}'

# 6. Criar produto (autenticado)
curl -X POST "$API_URL/products" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "X-Burger",
    "description": "Hambúrguer artesanal",
    "price": 25.90,
    "categoryId": "<uuid-categoria>"
  }'

# 7. Criar pedido (autenticado)
curl -X POST "$API_URL/orders" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "cpf": "98765432100",
    "items": [{"productId": "<uuid-produto>", "quantity": 2}]
  }'

# 8. Listar pedidos
curl -H "Authorization: Bearer $TOKEN" "$API_URL/orders"

# 9. Atualizar status do pedido
curl -X PUT "$API_URL/orders/<order-id>/status" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"status": "EM_PREPARACAO"}'

# 10. Criar pagamento
curl -X POST "$API_URL/payments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "amount": 51.80,
    "description": "Pedido #1",
    "paymentMethodId": "pix",
    "installments": 1,
    "payerEmail": "maria@email.com",
    "identificationType": "CPF",
    "identificationNumber": "98765432100"
  }'
```

## 🔧 Troubleshooting

### Erro 401 Unauthorized

```bash
# Verifique se o token está válido
# Tokens expiram em 1 hora

# Obtenha um novo token
curl -X POST "$API_URL/auth/cpf" \
  -H "Content-Type: application/json" \
  -d '{"cpf": "seu-cpf"}'
```

### Erro 403 Forbidden

```bash
# Verifique se está usando o header correto
# Authorization: Bearer <token>  ✓
# Authorization: <token>         ✗
```

### Erro 500 Internal Server Error

```bash
# Verifique os logs do CloudWatch
aws logs tail /aws/lambda/tech-challenge-auth-cpf --follow
```

## 📊 Monitoramento

O API Gateway possui métricas habilitadas:
- **Throttling**: 100 burst, 50 rate limit
- **Métricas**: Habilitadas para todas as rotas
- **Logs**: Via CloudWatch (quando disponível)
