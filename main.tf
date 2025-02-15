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
  service_account_id = var.service_account_id

  environment = {
    TELEGRAM_BOT_TOKEN    = var.tg_bot_key
    API_KEY               = var.service_account_api_key
    FOLDER_ID             = var.folder_id
    BUCKET_NAME           = var.instructions_bucket_name
    BUCKET_KEY            = var.instructions_bucket_key
  }

  content {
    zip_filename = "function.zip"
  }

  mounts {
    name = var.instructions_bucket_name
    mode = "ro"
    object_storage {
      bucket = yandex_storage_bucket.telegram_bot_bucket.bucket
    }
  }
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = var.service_account_id
  description        = "static access key for object storage"
}

resource "yandex_storage_bucket" "telegram_bot_bucket" {
  access_key            = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key            = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = var.instructions_bucket_name
}

resource "yandex_storage_object" "gpt_instructions" {
  access_key            = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key            = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = yandex_storage_bucket.telegram_bot_bucket.bucket
  key    = var.instructions_bucket_key
  source = "./gpt_instructions.txt"
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
            service_account_id: ${var.service_account_id}
  EOT
  depends_on = [yandex_function.telegram-bot]
}

resource "null_resource" "telegram_webhook" {
  provisioner "local-exec" {
    command = "curl -X POST https://api.telegram.org/bot${var.tg_bot_key}/setWebhook?url=${yandex_api_gateway.tg-api-gateway.domain}/telegram-bot"
  }

  depends_on = [yandex_api_gateway.tg-api-gateway]
}