"""
Seed realistic DEMO clinics through the public API (no direct DB access).

Every clinic, doctor, address and phone number here is FICTIONAL. Names carry
"(Demo)" and every tagline says it is sample data, so nobody mistakes them for
real practices. Neighbourhoods and coordinates are real places so "near me"
and maps behave realistically; street addresses are invented.

Idempotent: re-running skips clinics (by slug) that already exist for the
seed admin, so it is safe to run twice.

Usage:
    SEED_ADMIN_PASSWORD='choose-a-strong-one' python scripts/seed_demo_clinics.py
    # optional: CLINIC_API=https://<host> (defaults to production)

Requires the backend deploy that accepts latitude/longitude on locations.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE_URL = os.environ.get("CLINIC_API", "https://remind-me-indol.vercel.app").rstrip("/")
ADMIN_EMAIL = os.environ.get("SEED_ADMIN_EMAIL", "seed-admin@demo.dosewise.test")
ADMIN_PASSWORD = os.environ.get("SEED_ADMIN_PASSWORD")

MON_SAT = range(1, 7)  # ISO weekdays, 1 = Monday


def hm(h, m=0):
    return h * 60 + m


# --------------------------------------------------------------------------- #
# Fictional clinics. Fees are in paise (minor units).
# --------------------------------------------------------------------------- #
CLINICS = [
    {
        "slug": "demo-sunrise-family-clinic",
        "name": "Sunrise Family Clinic (Demo)",
        "orgType": "CLINIC",
        "tagline": "Demo clinic - sample data. Everyday care for the whole family.",
        "about": "Sample listing for trying out Clinic. A neighbourhood family practice offering general consultations, child health and routine check-ups.",
        "publicPhone": "+91 90000 10001",
        "publicEmail": "sunrise@demo.dosewise.test",
        "location": {"name": "Indiranagar", "addressLine1": "14, 2nd Cross (sample address)", "city": "Bengaluru",
                      "state": "Karnataka", "postalCode": "560038", "latitude": 12.9719, "longitude": 77.6412},
        "types": [("General Consultation", 15), ("Follow-up Visit", 10), ("Child Health Check", 20)],
        "doctors": [
            {"displayName": "Dr. Ananya Rao", "specialty": "General Medicine", "qualifications": "MBBS, MD (Internal Medicine)",
             "years": 12, "languages": ["English", "Kannada", "Hindi"], "fee": 50000, "mode": "BOTH",
             "bio": "Sample profile. Focuses on preventive care, diabetes and blood pressure management."},
            {"displayName": "Dr. Rohan Mehta", "specialty": "Pediatrics", "qualifications": "MBBS, DCH",
             "years": 8, "languages": ["English", "Hindi"], "fee": 60000, "mode": "SCHEDULED",
             "bio": "Sample profile. Child health, vaccinations and growth monitoring."},
        ],
    },
    {
        "slug": "demo-lotus-multispeciality",
        "name": "Lotus Multispeciality Hospital (Demo)",
        "orgType": "HOSPITAL",
        "tagline": "Demo hospital - sample data. Specialists under one roof.",
        "about": "Sample listing for trying out Clinic. A multispeciality hospital with cardiology, orthopaedics and women's health outpatient departments.",
        "publicPhone": "+91 90000 10002",
        "publicEmail": "lotus@demo.dosewise.test",
        "location": {"name": "Malviya Nagar", "addressLine1": "Plot 7, Sector 3 (sample address)", "city": "Jaipur",
                      "state": "Rajasthan", "postalCode": "302017", "latitude": 26.8530, "longitude": 75.8047},
        "types": [("Specialist Consultation", 20), ("Follow-up Visit", 15)],
        "doctors": [
            {"displayName": "Dr. Vikram Singh", "specialty": "Cardiology", "qualifications": "MBBS, MD, DM (Cardiology)",
             "years": 18, "languages": ["English", "Hindi"], "fee": 120000, "mode": "SCHEDULED",
             "bio": "Sample profile. Heart health, hypertension and cardiac follow-up."},
            {"displayName": "Dr. Meera Sharma", "specialty": "Gynecology", "qualifications": "MBBS, MS (Obstetrics & Gynaecology)",
             "years": 14, "languages": ["English", "Hindi", "Rajasthani"], "fee": 90000, "mode": "BOTH",
             "bio": "Sample profile. Women's health, pregnancy care and routine screening."},
            {"displayName": "Dr. Arjun Kapoor", "specialty": "Orthopedics", "qualifications": "MBBS, MS (Orthopaedics)",
             "years": 11, "languages": ["English", "Hindi"], "fee": 100000, "mode": "SCHEDULED",
             "bio": "Sample profile. Joint pain, sports injuries and fracture follow-up."},
        ],
    },
    {
        "slug": "demo-greenleaf-skin-care",
        "name": "GreenLeaf Skin & Hair Clinic (Demo)",
        "orgType": "CLINIC",
        "tagline": "Demo clinic - sample data. Skin, hair and nail care.",
        "about": "Sample listing for trying out Clinic. Outpatient dermatology for acne, allergies, hair fall and skin infections.",
        "publicPhone": "+91 90000 10003",
        "publicEmail": "greenleaf@demo.dosewise.test",
        "location": {"name": "Koregaon Park", "addressLine1": "22, Lane 5 (sample address)", "city": "Pune",
                      "state": "Maharashtra", "postalCode": "411001", "latitude": 18.5362, "longitude": 73.8939},
        "types": [("Skin Consultation", 15), ("Hair & Scalp Consultation", 20)],
        "doctors": [
            {"displayName": "Dr. Priya Kulkarni", "specialty": "Dermatology", "qualifications": "MBBS, MD (Dermatology)",
             "years": 9, "languages": ["English", "Marathi", "Hindi"], "fee": 70000, "mode": "SCHEDULED",
             "bio": "Sample profile. Acne, eczema, pigmentation and hair-loss treatment."},
        ],
    },
    {
        "slug": "demo-cityplus-polyclinic",
        "name": "CityPlus Polyclinic (Demo)",
        "orgType": "POLYCLINIC",
        "tagline": "Demo polyclinic - sample data. Walk in with a same-day token.",
        "about": "Sample listing for trying out Clinic. A busy polyclinic running same-day token queues for general and ENT consultations.",
        "publicPhone": "+91 90000 10004",
        "publicEmail": "cityplus@demo.dosewise.test",
        "location": {"name": "Lajpat Nagar", "addressLine1": "B-41, Central Market (sample address)", "city": "New Delhi",
                      "state": "Delhi", "postalCode": "110024", "latitude": 28.5677, "longitude": 77.2436},
        "types": [("General Consultation", 10), ("ENT Consultation", 15)],
        "doctors": [
            {"displayName": "Dr. Sameer Khan", "specialty": "General Medicine", "qualifications": "MBBS",
             "years": 6, "languages": ["English", "Hindi", "Urdu"], "fee": 40000, "mode": "SAME_DAY_TOKEN",
             "bio": "Sample profile. Fever, infections and everyday illnesses."},
            {"displayName": "Dr. Neha Bansal", "specialty": "ENT", "qualifications": "MBBS, MS (ENT)",
             "years": 10, "languages": ["English", "Hindi", "Punjabi"], "fee": 60000, "mode": "BOTH",
             "bio": "Sample profile. Ear, nose and throat problems, sinus and hearing checks."},
        ],
    },
    {
        "slug": "demo-pearl-dental-studio",
        "name": "Pearl Dental Studio (Demo)",
        "orgType": "CLINIC",
        "tagline": "Demo clinic - sample data. Gentle dental care.",
        "about": "Sample listing for trying out Clinic. Check-ups, cleaning, fillings and toothache relief.",
        "publicPhone": "+91 90000 10005",
        "publicEmail": "pearl@demo.dosewise.test",
        "location": {"name": "Banjara Hills", "addressLine1": "Road No. 12, Plot 9 (sample address)", "city": "Hyderabad",
                      "state": "Telangana", "postalCode": "500034", "latitude": 17.4126, "longitude": 78.4392},
        "types": [("Dental Check-up", 20), ("Cleaning & Polishing", 30)],
        "doctors": [
            {"displayName": "Dr. Kavya Reddy", "specialty": "Dentistry", "qualifications": "BDS, MDS (Conservative Dentistry)",
             "years": 7, "languages": ["English", "Telugu", "Hindi"], "fee": 50000, "mode": "SCHEDULED",
             "bio": "Sample profile. Preventive dentistry, fillings and root-canal consultations."},
        ],
    },
    {
        "slug": "demo-harbour-diagnostics",
        "name": "Harbour Health & Diagnostics (Demo)",
        "orgType": "DIAGNOSTIC_CENTER",
        "tagline": "Demo centre - sample data. Consultations with reports on the spot.",
        "about": "Sample listing for trying out Clinic. Physician consultations alongside routine blood tests and health packages.",
        "publicPhone": "+91 90000 10006",
        "publicEmail": "harbour@demo.dosewise.test",
        "location": {"name": "Andheri West", "addressLine1": "3rd Floor, Link Plaza (sample address)", "city": "Mumbai",
                      "state": "Maharashtra", "postalCode": "400053", "latitude": 19.1363, "longitude": 72.8277},
        "types": [("Physician Consultation", 15), ("Health Check Review", 20)],
        "doctors": [
            {"displayName": "Dr. Farhan Shaikh", "specialty": "General Medicine", "qualifications": "MBBS, MD (General Medicine)",
             "years": 15, "languages": ["English", "Hindi", "Marathi"], "fee": 80000, "mode": "BOTH",
             "bio": "Sample profile. Lifestyle conditions and reviewing lab reports."},
            {"displayName": "Dr. Ishita Desai", "specialty": "Endocrinology", "qualifications": "MBBS, MD, DM (Endocrinology)",
             "years": 12, "languages": ["English", "Gujarati", "Hindi"], "fee": 110000, "mode": "SCHEDULED",
             "bio": "Sample profile. Diabetes, thyroid and hormone disorders."},
        ],
    },
]


# --------------------------------------------------------------------------- #
def request(method, path, data=None, token=None, ok_statuses=(200, 201)):
    headers = {"X-Client": "app", "Content-Type": "application/json", "Accept": "application/json",
               "User-Agent": "DoseWiseDemoSeed/1.0"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(BASE_URL + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            text = resp.read().decode("utf-8")
            return resp.status, (json.loads(text) if text else {})
    except urllib.error.HTTPError as e:
        text = e.read().decode("utf-8")
        try:
            payload = json.loads(text)
        except ValueError:
            payload = {"raw": text}
        if e.code in ok_statuses:
            return e.code, payload
        return e.code, payload


def must(result, what):
    status, payload = result
    if status not in (200, 201):
        print(f"  ! {what} failed (HTTP {status}): {json.dumps(payload)[:400]}")
        sys.exit(1)
    return payload


def login():
    status, _ = request("POST", "/api/auth/register",
                        {"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD, "fullName": "Demo Seed Admin"})
    if status not in (200, 201, 409):
        print(f"  (register returned {status}; trying login)")
    tokens = must(request("POST", "/api/auth/login", {"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD}), "login")
    return tokens["accessToken"]


def seed_clinic(token, c, existing_slugs):
    if c["slug"] in existing_slugs:
        print(f"= {c['name']} already exists - skipped")
        return
    print(f"+ {c['name']}")
    org = must(request("POST", "/api/orgs", {"name": c["name"], "slug": c["slug"], "timezone": "Asia/Kolkata"}, token),
               "create clinic")
    org_id = org["id"]

    must(request("PATCH", f"/api/orgs/{org_id}", {
        "orgType": c["orgType"], "tagline": c["tagline"], "about": c["about"],
        "publicPhone": c["publicPhone"], "publicEmail": c["publicEmail"],
    }, token), "update profile")

    loc = must(request("POST", f"/api/orgs/{org_id}/locations", dict(c["location"], country="India"), token),
               "create location")
    loc_id = loc["id"]

    for name, minutes in c["types"]:
        must(request("POST", f"/api/orgs/{org_id}/appointment-types",
                     {"name": name, "durationMinutes": minutes}, token), f"appointment type {name}")

    for i, d in enumerate(c["doctors"]):
        local = d["displayName"].lower().replace("dr. ", "").replace(" ", ".")
        doc = must(request("POST", f"/api/orgs/{org_id}/doctors", {
            "email": f"{local}.{c['slug']}@demo.dosewise.test",
            "fullName": d["displayName"],
            "displayName": d["displayName"],
            "specialty": d["specialty"],
            "bio": d["bio"],
            "consultationDurationMin": 15,
        }, token), f"doctor {d['displayName']}")
        doc_id = doc["id"]
        must(request("PATCH", f"/api/orgs/{org_id}/doctors/{doc_id}", {
            "isPubliclyListed": True,
            "qualifications": d["qualifications"],
            "yearsOfExperience": d["years"],
            "languages": d["languages"],
            "consultationFeeMinor": d["fee"],
            "bookingMode": d["mode"],
            "tokenOpensMinute": hm(8),
            "tokenClosesMinute": hm(13),
            "queueStartMinute": hm(10),
            "maxDailyTokens": 40,
        }, token), f"doctor profile {d['displayName']}")

        # Morning + evening OPD, Mon-Sat; second doctor starts later for variety.
        start = hm(9) if i % 2 == 0 else hm(10, 30)
        rules = []
        for day in MON_SAT:
            rules.append({"weekday": day, "startMinute": start, "endMinute": hm(13),
                          "slotMinutes": 15, "locationId": loc_id})
            rules.append({"weekday": day, "startMinute": hm(17), "endMinute": hm(20),
                          "slotMinutes": 15, "locationId": loc_id})
        must(request("PUT", f"/api/orgs/{org_id}/doctors/{doc_id}/availability", {"rules": rules}, token),
             f"availability {d['displayName']}")

    must(request("POST", f"/api/orgs/{org_id}/publish", {}, token), "publish")
    print(f"  published: {len(c['doctors'])} doctor(s), {len(c['types'])} visit type(s)")


def main():
    if not ADMIN_PASSWORD or len(ADMIN_PASSWORD) < 12:
        print("Set SEED_ADMIN_PASSWORD (12+ characters) for the demo seed admin account.")
        sys.exit(2)
    print(f"Seeding demo clinics into {BASE_URL} as {ADMIN_EMAIL}")
    token = login()
    _, mine = request("GET", "/api/orgs", token=token)
    existing = {o.get("slug") for o in mine.get("data", [])}
    for c in CLINICS:
        seed_clinic(token, c, existing)
        time.sleep(0.5)  # stay well under the API rate limit
    print("Done.")


if __name__ == "__main__":
    main()
