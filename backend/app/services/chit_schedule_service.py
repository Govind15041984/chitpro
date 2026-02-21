# app/services/chit_schedule_service.py
from datetime import datetime, timedelta
import calendar

def compute_next_run(schedule_type, rule, from_date):
    if schedule_type == "FIXED_DATE":
        day = rule["day"]
        year = from_date.year
        month = from_date.month + 1
        if month > 12:
            month = 1
            year += 1
        return datetime(year, month, day)

    if schedule_type == "NTH_WEEKDAY":
        week = rule["week"]     # 1..5
        weekday = rule["weekday"]  # 0=Mon
        year = from_date.year
        month = from_date.month + 1
        cal = calendar.monthcalendar(year, month)
        return datetime(year, month, cal[week-1][weekday])

    if schedule_type == "INTERVAL":
        return from_date + timedelta(days=rule["interval_days"])

    if schedule_type == "CUSTOM":
        return rule["dates"].pop(0)

    raise ValueError("Invalid schedule type")
