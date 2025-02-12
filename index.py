import json
import os
import requests
import base64

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
API_KEY = os.getenv("API_KEY")
FOLDER_ID = os.getenv("FOLDER_ID")

START_MESSAGE = """Я помогу подготовить ответ на экзаменационный вопрос по дисциплине "Операционные системы".
Пришлите мне фотографию с вопросом или наберите его текстом."""
NO_ANSWER_MESSAGE = """Я не смог подготовить ответ на экзаменационный вопрос."""
TOO_MANY_PHOTOS_MESSAGE = """Я могу обработать только одну фотографию."""
BAD_PHOTO_MESSAGE = """Я не могу обработать эту фотографию."""
UNKNOWN_REQUEST_MESSAGE = """Я могу обработать только текстовое сообщение или фотографию."""


def get_image_base64(url):
    try:
        response = requests.get(url)
        response.raise_for_status()
        image_data = response.content
        base64_encoded = base64.b64encode(image_data).decode('utf-8')
        return base64_encoded
    except requests.exceptions.RequestException as e:
        return None


def send_message(chat_id, message):
    requests.get(f'https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage?&chat_id={chat_id}&text={message}')


def get_image_url(file_id):
    try:
        response = requests.get(f'https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getFile?file_id={file_id}')
        response.raise_for_status() 
        response_data = response.json()
        file_path = response_data['result']['file_path']
        return f'https://api.telegram.org/file/bot{TELEGRAM_BOT_TOKEN}/{file_path}'
    except requests.exceptions.RequestException as e:
        print(f"Request error: {e}")
        return None
    except (KeyError, ValueError) as e:
        print(f"Invalid API response: {e}")
        return None
    

def recognize_text(photo_id):
    image_url = get_image_url(photo_id)
    if not image_url:
        return BAD_PHOTO_MESSAGE
    image_base64 = get_image_base64(image_url)
    return """1. Файловые системы: Метод выделения дискового пространства "Индексные узлы".
2. Управление памятью: Принцип локальности."""


def find_answer(text):
    prompt = """Сгенерируй структурированный ответ на экзаменационный вопрос по операционным системам. Ответ должен быть полным, точным и написанным на русском языке. Не давай ответы на посторонние вопросы, не связанные с операционными системами."""

    full_prompt = f"{prompt}\nВопрос: {text}\nОтвет:"

    try:
        headers = {
            "Authorization": f"Api-Key {API_KEY}",
            "Content-Type": "application/json"
        }

        body = {
            "modelUri": f"gpt://{FOLDER_ID}/yandexgpt-lite",
            "completionOptions": {
                "stream": False,
                "temperature": 0.3,
                "maxTokens": 1000
            },
            "messages": [
                {
                    "role": "user",
                    "text": full_prompt
                }
            ]
        }

        response = requests.post(
            "https://llm.api.cloud.yandex.net/foundationModels/v1/completion",
            headers=headers,
            json=body
        )
        response.raise_for_status()

        answer = response.json()["result"]["alternatives"][0]["message"]["text"]
        return answer.strip()

    except Exception as e:
        print(f"YandexGPT API error: {e}")
        return None


def handle_message(chat_id, message):
    if 'text' in message:
        text = message['text']
        match text:
            case "/start":
                send_message(chat_id=chat_id, message=START_MESSAGE)
            case "/help":
                send_message(chat_id=chat_id, message=START_MESSAGE)
            case _:
                answer = find_answer(text)
                send_message(chat_id=chat_id, message=answer)
    elif 'photo' in message:
        photo_id = message['photo'][-1]['file_id']
        text = recognize_text(photo_id)
        answer = find_answer(text)
        send_message(chat_id=chat_id, message=answer)
    else:
        send_message(chat_id=chat_id, message=UNKNOWN_REQUEST_MESSAGE)


def handler(event, context):
    body = json.loads(event['body'])
    message = body.get("message")

    if not message:
        return {"statusCode": 200, "body": "No message"}

    chat_id = message["from"]["id"]
    handle_message(chat_id, message)

    return {
        'statusCode': 200,
        'body': 'OK'
    }