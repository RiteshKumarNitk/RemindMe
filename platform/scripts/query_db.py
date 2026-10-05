import os
import pg8000.native
from urllib.parse import urlparse

db_url_str = os.environ.get('DATABASE_URL')
if not db_url_str:
    raise ValueError("DATABASE_URL environment variable is not set")
db_url = urlparse(db_url_str)

con = pg8000.native.Connection(
    user=db_url.username,
    password=db_url.password,
    host=db_url.hostname,
    port=db_url.port or 5432,
    database=db_url.path.lstrip('/'),
    ssl_context=True
)

orgs = con.run('SELECT id, name, "isActive", "isPubliclyListed", "verificationStatus" FROM "Organization"')
print("Organizations:", orgs)

docs = con.run('SELECT id, "displayName", "isActive", "isPubliclyListed", "organizationId" FROM "DoctorProfile"')
print("Doctors:", docs)

locs = con.run('SELECT id, name, "isActive", "organizationId" FROM "ClinicLocation"')
print("Locations:", locs)

appt_types = con.run('SELECT id, name, "isActive", "organizationId" FROM "AppointmentType"')
print("Appointment Types:", appt_types)

avail_rules = con.run('SELECT id, "doctorId", "dayOfWeek", "startTime", "endTime" FROM "AvailabilityRule"')
print("Availability Rules:", avail_rules)

con.close()
