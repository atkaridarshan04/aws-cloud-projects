import boto3
import json
import time
import random
import uuid
from datetime import datetime, timezone

kinesis = boto3.client('kinesis', region_name='us-east-1')
STREAM_NAME = 'dashboard-stream'

MENU_ITEMS = [
    'Butter Chicken', 'Naan', 'Dal Makhani', 'Paneer Tikka',
    'Biryani', 'Garlic Bread', 'Lassi', 'Gulab Jamun'
]

STATUSES = ['NEW', 'PREPARING', 'READY']

active_orders = {}

def send_event(order):
    kinesis.put_record(
        StreamName=STREAM_NAME,
        Data=json.dumps(order),
        PartitionKey=order['entity_id']  # same order always goes to same shard
    )
    print(f"Sent: {order['entity_id']} | Table {order['table_no']} | {order['status']}")

print("Kitchen producer started...")

for i in range(20):
    # Every iteration: place a new order
    order_id = f"ORD-{str(uuid.uuid4())[:6].upper()}"
    order = {
        'entity_id': order_id,
        'table_no': f"T{random.randint(1, 12)}",
        'items': random.sample(MENU_ITEMS, random.randint(1, 3)),
        'status': 'NEW',
        'placed_at': datetime.now(timezone.utc).isoformat(),
        'last_updated': datetime.now(timezone.utc).isoformat()
    }
    active_orders[order_id] = order
    send_event(order)
    time.sleep(3)

    # Randomly advance some existing orders through statuses
    for oid, o in list(active_orders.items()):
        current_idx = STATUSES.index(o['status'])
        if current_idx < len(STATUSES) - 1 and random.random() > 0.4:
            o['status'] = STATUSES[current_idx + 1]
            o['last_updated'] = datetime.now(timezone.utc).isoformat()
            send_event(o)
            if o['status'] == 'READY':
                del active_orders[oid]  # remove from active once ready

print("Producer finished.")