"""Generate e-commerce datasets for the SQL portfolio.

Outputs (in datasets/):
  orders.csv     - order-level transactions
  customers.csv  - customer dimension
  events.csv     - clickstream events (for funnel analysis)
"""
import csv, random, math
from datetime import date, timedelta

random.seed(42)

START = date(2024, 1, 1)
END   = date(2025, 12, 31)
DAYS  = (END - START).days

REGIONS   = ["Northeast", "Southeast", "Midwest", "West"]
CHANNELS  = ["Web", "Mobile", "In-Store"]
SEGMENTS  = ["New", "Returning", "VIP"]
PRODUCTS  = [
    ("P001", "Wireless Headphones", 79.99),
    ("P002", "USB-C Hub",           34.99),
    ("P003", "Laptop Stand",        49.99),
    ("P004", "Mechanical Keyboard", 129.99),
    ("P005", "Webcam HD",           69.99),
    ("P006", "Mouse Pad XL",        19.99),
    ("P007", "Monitor Light",       39.99),
    ("P008", "Cable Organizer",     14.99),
]
FUNNEL    = ["page_view", "product_view", "add_to_cart", "checkout", "purchase"]

def rand_date(start=START, end=END):
    return start + timedelta(days=random.randint(0, (end - start).days))

# Customers
N_CUSTOMERS = 2000
customers = []
for i in range(1, N_CUSTOMERS + 1):
    signup = rand_date()
    customers.append({
        "customer_id":  f"C{i:05d}",
        "signup_date":  signup,
        "region":       random.choice(REGIONS),
        "segment":      random.choices(SEGMENTS, weights=[40, 45, 15])[0],
    })

# Orders
N_ORDERS = 8000
orders = []
for i in range(1, N_ORDERS + 1):
    c    = random.choice(customers)
    prod = random.choice(PRODUCTS)
    qty  = random.randint(1, 3)
    orders.append({
        "order_id":     f"O{i:06d}",
        "customer_id":  c["customer_id"],
        "order_date":   rand_date(c["signup_date"]),
        "product_id":   prod[0],
        "product_name": prod[1],
        "region":       c["region"],
        "channel":      random.choice(CHANNELS),
        "quantity":     qty,
        "unit_price":   prod[2],
        "total_amount": round(qty * prod[2], 2),
    })

# Funnel events (sessions that start with page_view, some convert)
N_SESSIONS = 5000
events = []
eid = 1
for s in range(1, N_SESSIONS + 1):
    c   = random.choice(customers)
    day = rand_date()
    ts  = 0
    for step in FUNNEL:
        events.append({
            "event_id":         f"E{eid:07d}",
            "customer_id":      c["customer_id"],
            "session_id":       f"S{s:06d}",
            "event_type":       step,
            "event_timestamp":  f"{day} {9 + ts//60:02d}:{ts%60:02d}:00",
        })
        eid += 1
        ts  += random.randint(1, 15)
        # drop-off probability increases through funnel
        if random.random() < [0.0, 0.35, 0.40, 0.45, 0.30][FUNNEL.index(step)]:
            break

import os
OUT = os.path.dirname(__file__)

def write(name, rows, fields):
    path = os.path.join(OUT, name)
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader(); w.writerows(rows)
    print(f"  {name}: {len(rows):,} rows")

print("Generating datasets...")
write("customers.csv", customers,
      ["customer_id","signup_date","region","segment"])
write("orders.csv", orders,
      ["order_id","customer_id","order_date","product_id","product_name",
       "region","channel","quantity","unit_price","total_amount"])
write("events.csv", events,
      ["event_id","customer_id","session_id","event_type","event_timestamp"])
print("Done.")
