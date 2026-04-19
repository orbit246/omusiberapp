# Schedule Grid API Guide

This document defines how the frontend should fetch, resolve, and render
weekly schedule data from the centralized backend.

The key rule is simple:

- the UI does not need faculty, department, or grade to render a schedule
- those fields only help the backend choose a better default schedule/class
- the actual rendered schedule is always:
  - one selected schedule record
  - one selected `classKey`
  - one selected `dayKey`

## Frontend Contract

Recommended client flow:

1. Fetch `GET /academic-faculties` to build faculty -> department -> grade
   pickers when the user wants to select academic context manually.
2. Fetch `GET /classes` if the UI needs the registered class list used by
   schedules.
3. Fetch `GET /schedules` to render schedule data.

The schedule payload already contains the effective schedule to render. The
client should not merge auto/manual schedule sources on its own.

## Endpoints

Base URL is defined in
[lib/backend/constants.dart](/Users/orbit/Documents/GitHub/omusiberapp/lib/backend/constants.dart).

Relevant endpoints:

- `GET /academic-faculties`
- `GET /classes`
- `GET /schedules`

## Auth

Anonymous schedule browsing is allowed if the backend supports it.

When the user is authenticated, send the normal Firebase bearer token:

```http
Authorization: Bearer <firebase-id-token>
Accept: application/json
```

If auth is present, each schedule item may include `academicContext`, which the
frontend should use for default selection.

## What To Send

### Default request

For normal schedule loading:

```http
GET /schedules
```

### Optional schedule hints

If the client already knows which schedule/class it wants, it may send query
hints with `GET /schedules`:

- `scheduleId`
- `programName`
- `classKey`
- `classIndex`

These are hints, not a different rendering model.

### Academic browsing helpers

Use these when the user is selecting academics manually:

- `GET /academic-faculties` for faculty/department/grade pickers
- `GET /classes` for registered class keys and labels

The frontend should not require faculty/department/grade before attempting to
display a schedule.

## What To Expect Back

The frontend should expect a JSON array of schedule records:

```json
[
  {
    "id": 1,
    "programName": "BILISIM GUVENLIGI PROGRAMI",
    "academicYear": "2025-2026",
    "semester": "Bahar",
    "updatedAt": "2026-04-09T08:45:00.000Z",
    "schedule": {
      "engineering-computer-science-grade1": {
        "PAZARTESI": [
          {
            "time": "13:00",
            "courseCode": "BGP112",
            "courseName": "Bilgisayar Donanimi",
            "instructor": "Ogr. Gor. ...",
            "classroom": "A201"
          }
        ],
        "SALI": []
      }
    },
    "availableClassKeys": [
      "engineering-computer-science-grade1",
      "engineering-computer-science-grade2"
    ],
    "registeredClassKeys": [
      "engineering-computer-science-grade1",
      "engineering-computer-science-grade2"
    ],
    "manualOverrideEnabled": false,
    "effectiveSource": "auto",
    "academicContext": {
      "scheduleId": 1,
      "classKey": "engineering-computer-science-grade1",
      "faculty": {
        "key": "engineering",
        "name": "Engineering Faculty"
      },
      "department": {
        "key": "engineering-computer-science",
        "name": "Computer Science"
      },
      "grade": {
        "key": "engineering-computer-science-grade1",
        "name": "1. Grade",
        "level": 1
      },
      "matchedBy": "seeded",
      "isSeededFallback": true
    }
  }
]
```

## Important Response Rules

- `schedule` is the effective schedule to render
- the client should read schedule data from:
  - `schedule[selectedClassKey][dayKey]`
- `availableClassKeys` is the available class list inside the schedule payload
- `registeredClassKeys` is the preferred class list when present
- `academicContext.classKey` is the backend-selected default class
- `academicContext` may be absent for anonymous requests

Day keys should be normalized uppercase weekday names:

- `PAZARTESI`
- `SALI`
- `CARSAMBA`
- `PERSEMBE`
- `CUMA`
- `CUMARTESI`
- `PAZAR`

Lesson items should use:

- `time` in `HH:mm`
- `courseCode`
- `courseName`
- `instructor`
- `classroom`

If a day has no lessons, return an empty array instead of `null`.

## How The Frontend Should Display It

The UI should work from the response in this order:

1. Build the program list from `GET /schedules`
2. Pick the selected schedule record
3. Build class tabs/dropdown from:
   - `registeredClassKeys` when present
   - otherwise `availableClassKeys`
4. Pick the selected class key
5. Render day columns from `schedule[selectedClassKey]`
6. Render lesson rows from each `dayKey` array

The frontend should not derive schedule content from profile fields directly.
Profile fields are only inputs to backend matching.

## No Faculty / No Department / No Grade Case

This is the main fallback rule the frontend must support.

If the user is authenticated but has no usable academic selection and the
client sends no query hints:

- the backend may choose a deterministic seeded fallback schedule/class
- the matched schedule is returned with `academicContext`
- that matched schedule may be moved to the top of the `GET /schedules`
  response

Frontend behavior should be:

1. Call `GET /schedules` with auth
2. Find the first schedule whose `academicContext.scheduleId` is set
3. Use `academicContext.classKey` as the default selected class
4. Render that schedule normally
5. If `isSeededFallback == true`, show a small note that the result was
   inferred

This means the UI should not block schedule rendering just because the user has
not selected faculty/department/grade in profile yet.

## Recommended UX Flows

### Logged-in user with academic profile

- call `GET /schedules` with auth
- use the schedule with matching `academicContext`
- default to `academicContext.classKey`

### Logged-in user with no academic profile

- call `GET /schedules` with auth
- let backend provide the fallback schedule/class
- render it directly
- if `isSeededFallback` is true, show that the schedule is inferred

### Anonymous user

- call `GET /schedules`
- show a program picker
- after program selection, show a class picker from the schedule payload

## Client Rendering Rule

The frontend should always think in this model:

- selected schedule record
- selected `classKey`
- selected `dayKey`

Faculty, department, and grade are metadata for selection and matching. They
are not required to render the timetable grid itself.

## Current Flutter Note

The current Flutter implementation in
[lib/pages/schedule_page.dart](/Users/orbit/Documents/GitHub/omusiberapp/lib/pages/schedule_page.dart)
and
[lib/backend/view/schedule_model.dart](/Users/orbit/Documents/GitHub/omusiberapp/lib/backend/view/schedule_model.dart)
still assumes grade-level access like `grade1`, `grade2` and currently treats
academic profile selection as required before fetching schedules.

To align the app with this contract, the client should move toward:

- parsing arbitrary `classKey` entries inside `schedule`
- reading `availableClassKeys` and `registeredClassKeys`
- reading `academicContext`
- allowing `GET /schedules` even when profile academics are empty
