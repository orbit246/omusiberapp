# General Idea

The academic structure is modeled as a strict tree:

`Faculty -> Department -> Grade`

This is different from the old shared-class approach. Grades are no longer global records reused across multiple departments. Each grade belongs to exactly one department, and each department belongs to exactly one faculty.

## Ownership Rules

- A faculty is the top-level academic unit.
- A department is always created under one faculty.
- A grade is always created under one department.
- A grade cannot exist without a department.
- A department cannot exist without a faculty.

## Key Strategy

Keys are collective and scoped by ownership so they stay unique and readable.

- Faculty key: `engineering`
- Department key: `engineering-computer-science`
- Grade key: `engineering-computer-science-grade1`

This removes ambiguity. `grade1` alone is no longer enough. The full key always tells you which faculty and department own the grade.

## Why This Model

- The hierarchy is explicit.
- Fetching is predictable.
- Validation is simpler.
- Profile selection is safer.
- Admin management maps directly to the real academic structure.


# Admin Implementation

The admin side is responsible for creating and maintaining the tree.

## Faculty Management Payload Shape

The backend now expects faculties to be managed with nested departments and nested grades.

Example:

```json
{
  "name": "Engineering Faculty",
  "key": "engineering",
  "departments": [
    {
      "name": "Computer Science",
      "key": "computer-science",
      "grades": [
        { "level": 1, "name": "1. Grade", "key": "grade1" },
        { "level": 2, "name": "2. Grade", "key": "grade2" },
        { "level": 3, "name": "3. Grade", "key": "grade3" },
        { "level": 4, "name": "4. Grade", "key": "grade4" }
      ]
    }
  ]
}
```

The backend expands these into collective keys:

- department: `engineering-computer-science`
- grade 1: `engineering-computer-science-grade1`
- grade 2: `engineering-computer-science-grade2`

## Admin Endpoints

### `GET /academic-faculties`

Returns the full tree:

- faculty
- departments under faculty
- grades under each department

This should be the main admin read endpoint for academic management.

### `POST /academic-faculties`

Creates a faculty and its nested departments and grades in one operation.

Backend behavior:

- validates faculty key
- builds collective department keys
- builds collective grade keys
- validates grade levels `1..6`
- rejects duplicate department keys inside the same payload
- rejects duplicate grade levels inside the same department

### `PATCH /academic-faculties/:idOrKey`

Replaces the full tree for one faculty.

Backend behavior:

- updates faculty metadata
- recreates all departments under that faculty
- recreates all grades under those departments
- revalidates affected user profiles

Profile update rules:

- if the old department still exists, keep `departmentKey`
- otherwise clear `departmentKey`
- if the old grade still exists under the kept department, keep `gradeKey`
- otherwise clear `gradeKey`

### `DELETE /academic-faculties/:idOrKey`

Deletes the faculty and all nested departments and grades.

Affected user profiles are cleared:

- `facultyKey = null`
- `departmentKey = null`
- `gradeKey = null`
- cached `department = null`

## Grade Management

The old global class registry is no longer the source of truth for academics.

`POST /admin/classes` now means:

- create one or more grades for a specific department
- require `departmentKey`
- require `minLevel` and `maxLevel`
- generate one collective key per level from the owning department
- create every level in the inclusive range `minLevel..maxLevel`
- reject the request before writing anything if any requested level already exists for that department

Example request:

```json
{
  "departmentKey": "engineering-computer-science",
  "minLevel": 1,
  "maxLevel": 4
}
```

Resulting stored keys:

- `engineering-computer-science-grade1`
- `engineering-computer-science-grade2`
- `engineering-computer-science-grade3`
- `engineering-computer-science-grade4`

### `GET /classes`

Fetches grades from the tree:

- if `departmentKey` is given, return only that department’s grades
- if `facultyKey` is given, return all grades under that faculty
- otherwise return all grades from all departments

### `GET /admin/classes`

Same idea as `GET /classes`, but admin-protected and includes ownership context in the response.

Useful fields:

- `facultyKey`
- `departmentKey`
- `level`
- `key`
- `name`


# Flutter Side

Flutter should treat academics as a cascading selection flow, not as a flat class list.

## Customer-Facing Fetch Flow

Recommended startup flow:

1. Fetch `GET /academic-faculties`
2. Build the full academic tree in memory
3. Drive faculty, department, and grade pickers from that tree

This is the cleanest approach because one response contains the full hierarchy.

## UI Selection Flow

The profile selection should work in this order:

1. User selects faculty
2. Show only departments under that faculty
3. User selects department
4. Show only grades under that department
5. User selects grade

The UI should never show grades before a department is selected.

## Profile Update Payload

When the user saves profile academics, send:

```json
{
  "facultyKey": "engineering",
  "departmentKey": "engineering-computer-science",
  "gradeKey": "engineering-computer-science-grade1"
}
```

Backend validation enforces:

- no department without faculty
- no grade without department
- department must belong to faculty
- grade must belong to department

## Flutter Data Handling

Recommended local structures:

- `Faculty`
  - `key`
  - `name`
  - `departments`
- `Department`
  - `key`
  - `name`
  - `grades`
- `Grade`
  - `key`
  - `level`
  - `name`

Recommended UX rules:

- when faculty changes, clear selected department and grade
- when department changes, clear selected grade
- store keys, not labels
- render labels from API response

## Schedule and Filtering Implication

If Flutter uses grade-specific schedule filtering, it must use the full collective `gradeKey`, not plain values like `grade1`.

Correct:

- `engineering-computer-science-grade1`

Not correct:

- `grade1`

This is important because grade levels are now department-owned, not globally shared.
