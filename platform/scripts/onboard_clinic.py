import urllib.request
import urllib.parse
import json
import sys

BASE_URL = "https://remind-me-indol.vercel.app"
# BASE_URL = "http://localhost:3000"

def request(method, path, data=None, token=None):
    url = BASE_URL + path
    headers = {
        "x-client": "app",
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) DoseWiseScript/1.0"
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    
    body = None
    if data is not None:
        body = json.dumps(data).encode("utf-8")
        
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            resp_body = response.read().decode("utf-8")
            if resp_body:
                return json.loads(resp_body)
            return {}
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code} on {method} {url}")
        print(e.read().decode("utf-8"))
        sys.exit(1)

def main():
    email = "demo-admin@dosewise.app"
    password = "Password123!"
    
    print("1. Register/Login")
    try:
        request("POST", "/api/auth/register", {
            "email": email,
            "password": password,
            "fullName": "Demo Admin"
        })
    except SystemExit:
        pass # Probably already registered
        
    # Now login to get tokens
    auth_res = request("POST", "/api/auth/login", {
        "email": email,
        "password": password
    })
        
    token = auth_res.get("accessToken")
    print("Got token:", token[:10] + "...")

    print("2. Check existing orgs")
    orgs_res = request("GET", "/api/orgs", token=token)
    my_orgs = orgs_res.get("data", [])
    
    if not my_orgs:
        print("Creating Organization...")
        org = request("POST", "/api/orgs", {
            "name": "DoseWise Demo Clinic",
            "slug": "demo-clinic",
            "timezone": "Asia/Kolkata",
            "location": {
                "name": "DoseWise Demo Location",
                "city": "Demo City",
                "addressLine1": "123 Demo Street"
            }
        }, token)
    else:
        org = my_orgs[0]
        print("Using existing Organization:", org["name"])
        
    org_id = org["id"]
    
    print("3. Updating Organization details for publishing")
    request("PATCH", f"/api/orgs/{org_id}", {
        "orgType": "CLINIC",
        "tagline": "Demo Tagline",
        "about": "This is a demo clinic for testing the DoseWise platform.",
        "publicPhone": "+1-555-0100",
        "publicEmail": "demo@dosewise.app"
    }, token)
    
    print("4. Fetch locations")
    locs_res = request("GET", f"/api/orgs/{org_id}/locations", token=token)
    locs = locs_res.get("data", [])
    if not locs:
        print("No locations found. Creating one...")
        loc = request("POST", f"/api/orgs/{org_id}/locations", {
            "name": "DoseWise Demo Location",
            "city": "Demo City",
            "addressLine1": "123 Demo Street"
        }, token)
        loc_id = loc["id"]
    else:
        loc_id = locs[0]["id"]
    print("Location ID:", loc_id)
    
    print("5. Create/Update Doctor")
    docs_res = request("GET", f"/api/orgs/{org_id}/doctors", token=token)
    docs = docs_res.get("data", [])
    if not docs:
        doc = request("POST", f"/api/orgs/{org_id}/doctors", {
            "email": "dr.demo@dosewise.app",
            "fullName": "Dr. Demo Doctor",
            "displayName": "Dr. Demo Doctor",
            "specialty": "General Medicine",
            "consultationDurationMin": 15
        }, token)
    else:
        doc = docs[0]
        
    doc_id = doc["id"]
    print("Doctor ID:", doc_id)
    
    print("Updating Doctor public fields and booking mode")
    request("PATCH", f"/api/orgs/{org_id}/doctors/{doc_id}", {
        "isPubliclyListed": True,
        "bookingMode": "BOTH",
        "tokenOpensMinute": 8 * 60,
        "tokenClosesMinute": 17 * 60,
        "queueStartMinute": 9 * 60,
        "maxDailyTokens": 50,
        "consultationFeeMinor": 50000,
        "yearsOfExperience": 10
    }, token)
    
    print("6. Create Appointment Type")
    appts_res = request("GET", f"/api/orgs/{org_id}/appointment-types", token=token)
    appts = appts_res.get("data", [])
    if not appts:
        appt = request("POST", f"/api/orgs/{org_id}/appointment-types", {
            "name": "General Consultation",
            "durationMinutes": 15,
            "colorHex": "#3b82f6"
        }, token)
    else:
        appt = appts[0]
    appt_id = appt["id"]
    print("Appointment Type ID:", appt_id)
    
    print("7. Create Availability Rule")
    # For testing, we create availability for every day
    rules_payload = []
    for day in range(1, 8):
        rules_payload.append({
            "weekday": day,
            "startMinute": 9 * 60,
            "endMinute": 17 * 60,
            "slotMinutes": 15,
            "locationId": loc_id
        })
    request("PUT", f"/api/orgs/{org_id}/doctors/{doc_id}/availability", {
        "rules": rules_payload
    }, token)
    print("Availability rules created.")
    
    print("8. Publish Organization")
    res = request("POST", f"/api/orgs/{org_id}/publish", {}, token)
    print("Publish success:", res)

if __name__ == "__main__":
    main()
