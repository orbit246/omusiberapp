# Schedule Grid API Guide

This note explains how the weekly timetable grid in the app reads schedule data from the centralized backend API and how to keep the contract stable.

## Frontend Flow

The schedule screen lives in [lib/pages/schedule_page.dart](/Users/orbit/Documents/GitHub/omusiberapp/lib/pages/schedule_page.dart).

Data flow:

1. `SchedulePage` calls `ScheduleService().fetchSchedules()`
2. `ScheduleService` sends `GET /schedules` to the centralized API
3. The response is parsed into `ProgramSchedule`
4. The selected program and selected year are saved into `SharedPreferences`
5. The page converts the selected year's lessons into a weekly grid

Current preference keys:

- `selected_program_id`
- `selected_grade_index`

These keys are also used by notes/context logic, so they should stay stable unless the rest of the app is updated too.

## API Endpoint

Base URL is defined in [lib/backend/constants.dart](/Users/orbit/Documents/GitHub/omusiberapp/lib/backend/constants.dart).

Current endpoint:

- `GET /schedules`

Current auth:

- `Authorization: Bearer <firebase-id-token>`

## Expected Response Shape

The frontend expects a JSON array like this:

```json
[
  {
    "id": 12,
    "programName": "Siber Guvenlik Teknolojileri",
    "academicYear": "2025-2026",
    "semester": "Bahar",
    "updatedAt": "2026-04-09T08:45:00.000Z",
    "schedule": {
      "grade1": {
        "PAZARTESI": [
          {
            "time": "08:30",
            "courseCode": "SGT101",
            "courseName": "Ag Temelleri",
            "instructor": "Ogretim Gorevlisi A",
            "classroom": "Lab 3"
          }
        ],
        "SALI": []
      },
      "grade2": {
        "PAZARTESI": [],
        "SALI": [
          {
            "time": "09:30",
            "courseCode": "SGT204",
            "courseName": "Web Guvenligi",
            "instructor": "Ogretim Gorevlisi B",
            "classroom": "Lab 2"
          }
        ]
      }
    }
  }
]
```

## Important Contract Rules

- `id` must be stable for a program. The saved selection restores by `id`.
- `programName` is what the user sees in the selector.
- `grade1` and `grade2` should both exist, even if one is empty.
- `time` should be `HH:mm`.
- Day keys should preferably be uppercase Turkish weekday names:
  - `PAZARTESI`
  - `SALI`
  - `CARSAMBA`
  - `PERSEMBE`
  - `CUMA`
  - optional: `CUMARTESI`, `PAZAR`
- Empty lessons should not be sent. If there is no class, send an empty array for that day.

## Current Frontend Mapping

The page does these transformations:

- Sorts programs by `programName`
- Restores the last selected program from `selected_program_id`
- Restores the last selected year from `selected_grade_index`
- Reads either `grade1` or `grade2` depending on the selected year
- Groups lessons into a grid by day and `time`
- Uses a default visual duration of 50 minutes for display labels on the left

If the backend changes the time format or day keys, update the parsing helpers in [lib/pages/schedule_page.dart](/Users/orbit/Documents/GitHub/omusiberapp/lib/pages/schedule_page.dart).

## Backend Implementation Checklist

When adding or updating the centralized API:

1. Return one object per program/class option.
2. Keep `id` unchanged between deploys if the same program still exists.
3. Normalize day names before sending them.
4. Normalize lesson time to `HH:mm`.
5. Always return arrays for each day, not `null`.
6. Return `updatedAt` so the UI can show freshness.

## If You Want a More Centralized Schedule API

If the backend grows, keep all schedule data behind a single service layer like this:

- `GET /schedules`
- optional `GET /schedules/:id`
- optional `GET /schedules?department=...`
- optional `GET /schedules?academicYear=...`

The frontend should still map everything through `ScheduleService`, so the UI never talks to raw URLs directly.

## Recommended Frontend Rule

Keep all schedule fetching inside:

- [lib/backend/schedule_service.dart](/Users/orbit/Documents/GitHub/omusiberapp/lib/backend/schedule_service.dart)

Keep all JSON parsing inside:

- [lib/backend/view/schedule_model.dart](/Users/orbit/Documents/GitHub/omusiberapp/lib/backend/view/schedule_model.dart)

Keep all rendering logic inside:

- [lib/pages/schedule_page.dart](/Users/orbit/Documents/GitHub/omusiberapp/lib/pages/schedule_page.dart)

That separation makes it much easier to swap backend details without redesigning the UI.
