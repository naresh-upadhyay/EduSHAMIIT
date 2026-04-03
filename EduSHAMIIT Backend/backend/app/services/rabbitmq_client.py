import pika
import json
import os


def get_rabbitmq_connection():
    """Get RabbitMQ connection."""
    params = pika.URLParameters(os.getenv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672"))
    return pika.BlockingConnection(params)


def publish_message(queue: str, message: dict):
    """Publish a message to a RabbitMQ queue."""
    try:
        connection = get_rabbitmq_connection()
        channel = connection.channel()
        channel.queue_declare(queue=queue, durable=True)
        channel.basic_publish(
            exchange='',
            routing_key=queue,
            body=json.dumps(message),
            properties=pika.BasicProperties(delivery_mode=2)
        )
        connection.close()
        return True
    except Exception as e:
        print(f"RabbitMQ publish error: {e}")
        return False


def consume_messages(queue: str, callback):
    """Consume messages from a RabbitMQ queue."""
    try:
        connection = get_rabbitmq_connection()
        channel = connection.channel()
        channel.queue_declare(queue=queue, durable=True)
        channel.basic_qos(prefetch_count=1)
        channel.basic_consume(queue=queue, on_message_callback=callback)
        channel.start_consuming()
    except Exception as e:
        print(f"RabbitMQ consume error: {e}")