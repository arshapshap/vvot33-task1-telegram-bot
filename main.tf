terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone                      = "ru-central1-a"
  service_account_key_file  = pathexpand("~/.yc-keys/key.json")
  cloud_id                  = var.cloud_id
  folder_id                 = var.folder_id
}

resource "yandex_function" "telegram-bot" {
  name               = "telegram-bot"
  runtime            = "python312"
  entrypoint         = "index.handler"
  memory             = 128
  execution_timeout  = 20
  user_hash          = "hash"

  environment = {
    TELEGRAM_BOT_TOKEN = var.tg_bot_key
    API_KEY            = var.api_key
    FOLDER_ID          = var.folder_id
  }

  content {
    zip_filename = "function.zip"
  }
}

resource "yandex_api_gateway" "tg-api-gateway" {
  name = "telegram-webhook"
  spec = <<-EOT
    openapi: 3.0.0
    info:
      title: Telegram Webhook
      version: 1.0.0
    paths:
      /telegram-bot:
        post:
          x-yc-apigateway-integration:
            type: cloud_functions
            function_id: ${yandex_function.telegram-bot.id}
  EOT
  depends_on = [yandex_function.telegram-bot]
}

resource "null_resource" "telegram_webhook" {
  provisioner "local-exec" {
    command = "curl -X POST https://api.telegram.org/bot${var.tg_bot_key}/setWebhook?url=${yandex_api_gateway.tg-api-gateway.domain}/telegram-bot"
  }

  depends_on = [yandex_api_gateway.tg-api-gateway]
}