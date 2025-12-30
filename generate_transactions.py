import csv
import random
import os
from datetime import datetime, timedelta

# ====== NASTAVENIA ======

CURRENT_YEAR = datetime.now().year

START_DATE = datetime(CURRENT_YEAR, 1, 1)
END_DATE   = datetime(CURRENT_YEAR, 12, 31)

CSV_NAME = "transactions.csv"

SALARY_AMOUNT = 1450.00
RENT_AMOUNT   = 420.00
SUBSCRIPTION  = 14.99

# (merchant/desc, min, max, category)
POS_MERCHANTS = [
    # Groceries
    ("Lidl Bratislava", 5, 35, "Groceries"),
    ("Tesco Bratislava", 6, 45, "Groceries"),
    ("Kaufland", 8, 55, "Groceries"),
    ("Billa", 5, 35, "Groceries"),
    ("Yeme (delikatesy)", 10, 60, "Groceries"),

    # Dining / Coffee
    ("Bistro/Obed menu", 5, 14, "Dining"),
    ("Restaurant Bratislava", 12, 55, "Dining"),
    ("McDonald's", 6, 18, "Dining"),
    ("Kaviareň", 3, 10, "Coffee"),

    # Fuel / Transport
    ("OMV", 35, 85, "Fuel"),
    ("Shell", 35, 90, "Fuel"),
    ("Slovnaft", 30, 80, "Fuel"),
    ("MHD lístok", 0.90, 1.20, "Transport"),
    ("Bolt / Uber", 4, 18, "Transport"),
    ("Železničný lístok", 3, 25, "Transport"),

    # Entertainment
    ("Cinema", 7, 18, "Entertainment"),
    ("Concert ticket", 15, 60, "Entertainment"),
    ("Steam games", 5, 60, "Entertainment"),
    ("Netflix", 7, 14, "Subscription"),  # občas aj iné subscription

    # Health / Pharmacy
    ("Lekáreň", 3, 25, "Health"),
    ("Drogéria (DM)", 4, 30, "Health"),

    # Shopping
    ("Clothing store", 20, 120, "Clothing"),
    ("Sports store", 15, 120, "Shopping"),
    ("Electronics store", 30, 250, "Electronics"),
    ("Alza", 20, 220, "Electronics"),

    # Home
    ("IKEA", 10, 180, "Home"),
    ("Hobby market", 5, 120, "Home"),

    # Services
    ("Haircut / Barber", 8, 25, "Services"),
    ("Gym entry", 5, 20, "Fitness"),
]

ACCOUNT_IN  = "ACC-100001"
ACCOUNT_OUT = "ACC-200001"
FAKE_IBAN   = "SK0000000000000000000000"

# ====== CESTA K CSV ======

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(BASE_DIR, CSV_NAME)

# ====== POMOCNÉ FUNKCIE ======

def random_date(start, end):
    delta = end - start
    return start + timedelta(days=random.randint(0, delta.days))

def fmt_date(d):
    return d.strftime("%d.%m.%Y")

def euro(amount):
    return f"{amount:.2f}".replace(".", ",")

# ====== GENEROVANIE ======

rows = []
current = START_DATE

while current <= END_DATE:
    year = current.year
    month = current.month

    # Výplata
    salary_date = datetime(year, month, 5)
    rows.append([
        fmt_date(salary_date), fmt_date(salary_date), euro(SALARY_AMOUNT),
        "EUR", "Credit", "", ACCOUNT_IN, "", FAKE_IBAN,
        "", "", "", "Salary", "Employer s.r.o.", "Salary"
    ])

    # Nájom
    rent_date = datetime(year, month, 6)
    rows.append([
        fmt_date(rent_date), fmt_date(rent_date), euro(RENT_AMOUNT),
        "EUR", "Debit", "", ACCOUNT_OUT, "", FAKE_IBAN,
        "", "", "", "Monthly rent", "Rental Services", "Rent"
    ])

    # Subscription (stále Spotify ako “fix”, ale máš aj iné občas v POS_MERCHANTS)
    sub_date = datetime(year, month, 20)
    rows.append([
        fmt_date(sub_date), fmt_date(sub_date), euro(SUBSCRIPTION),
        "EUR", "Debit", "", "", "", "",
        "", "", "", "Spotify subscription", "", "Subscription"
    ])

    # POS nákupy
    pos_count = random.randint(60, 90)
    for _ in range(pos_count):
        desc, min_amt, max_amt, category = random.choice(POS_MERCHANTS)
        amount = round(random.uniform(min_amt, max_amt), 2)

        d = random_date(
            datetime(year, month, 1),
            datetime(year, month, 28)
        )

        rows.append([
            fmt_date(d), fmt_date(d), euro(amount),
            "EUR", "Debit", "", "", "", "",
            "", "", "", desc, "", category   # ✅ tu ide kategória, nie "POS purchase"
        ])

    # ďalší mesiac
    current = (current.replace(day=28) + timedelta(days=4)).replace(day=1)

# ====== ZÁPIS CSV (VŽDY PREPÍŠE) ======

with open(CSV_PATH, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow([
        "Posting date","Value date","Amount","Currency","Type",
        "Preffix","Account Number","Bank Code","IBAN",
        "Variable symbol","Specific symbol","Constant symbol",
        "Payer´s reference","Information for beneficiary","Description"
    ])
    writer.writerows(rows)
