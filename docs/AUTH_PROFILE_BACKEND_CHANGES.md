# Auth And Profile Backend Changes

This app update removes the hard requirement for `@stu.omu.edu.tr` Google accounts and adds Apple Sign-In on iOS. Backend behavior must be updated to match the new client assumptions.

## Summary

- Any valid Google or Apple account can authenticate.
- `studentId` is now optional.
- If an email local-part looks like a numeric student ID such as `210601234@...`, the app auto-fills `studentId`.
- Profiles without `studentId` must still be accepted and returned cleanly.

## Required Backend Changes

### 1. Stop enforcing student-only email domains

If the backend currently rejects users unless their email ends with `@stu.omu.edu.tr`, remove that restriction.

Expected behavior:

- Accept Firebase-authenticated users from Google and Apple.
- Trust the Firebase ID token as the primary identity proof.
- Do not reject users only because their email domain is not a student domain.

### 2. Make `studentId` nullable everywhere

The backend should allow user profiles with no `studentId`.

Affected areas:

- user creation
- profile update validation
- profile read serializers
- any DB unique indexes or constraints
- user search logic

Expected behavior:

- `studentId` may be `null` or an empty string on write.
- `studentId` may be absent or `null` on read.
- Missing `studentId` must not break profile reads or updates.

### 3. Update `/users/profile` PATCH validation

The app may now send these fields during sign-in/profile edits:

- `name`
- `email`
- `photoUrl`
- `studentId`
- `age`
- `department`
- `gender`
- `campus`
- `isPrivate`

Expected behavior:

- Unknown or omitted fields should not fail the request.
- `studentId` must be optional.
- If `studentId` is present, validate it leniently as a string of digits.
- If `studentId` is omitted, keep the current stored value unchanged.
- If `studentId` is sent as `null` or `""`, treat it as clearing the field.

### 4. Profile bootstrap behavior

After Google or Apple sign-in, the client may immediately PATCH `/users/profile` with auth-derived profile fields.

Expected backend behavior:

- Ensure the authenticated user profile exists before applying updates.
- Upsert missing profile records automatically if needed.
- Do not require a prior manual profile creation step.

Suggested bootstrap defaults:

- `name`: auth provider display name if available, otherwise a fallback label
- `email`: Firebase user email
- `photoUrl`: Firebase photo URL if available
- `role`: prefer a neutral default such as `member` instead of forcing `student`

### 5. Student ID auto-fill support

The client auto-derives `studentId` from email only when the local part is numeric with at least 6 digits.

Examples:

- `210601234@stu.omu.edu.tr` -> `studentId = "210601234"`
- `john@example.com` -> no derived student ID
- `alice.2024@example.com` -> no derived student ID

Expected backend behavior:

- Accept the provided derived `studentId` as normal profile data.
- Do not require the email domain to match a university domain.
- Do not force role escalation based only on email domain.

### 6. Search by student ID

`GET /users/search?studentId=...` can remain supported, but users without a `studentId` will naturally not be searchable through this endpoint.

Expected behavior:

- Return 404 or an empty result when no user has the given `studentId`.
- Ignore users whose `studentId` is missing or empty.

Optional improvement:

- Add a separate search mode by name or email for non-student users.

### 7. Apple Sign-In support in Firebase-backed auth

The backend does not need to verify Apple tokens directly if Firebase Auth already verifies them and the API trusts Firebase ID tokens.

Expected behavior:

- Continue validating Firebase ID tokens server-side.
- Treat Apple-authenticated Firebase users like other authenticated users.

## Recommended Data Model

Suggested user profile shape:

```json
{
  "uid": "firebase-uid",
  "email": "user@example.com",
  "name": "User Name",
  "photoUrl": "https://...",
  "studentId": null,
  "role": "member",
  "department": null,
  "campus": null,
  "gender": null,
  "age": null,
  "isPrivate": false
}
```

## Regression Checklist

- A Google user with a non-student email can sign in and fetch `/users/me`.
- An Apple user can sign in and fetch `/users/me`.
- A profile can be saved with no `studentId`.
- A profile can clear an existing `studentId`.
- Search by `studentId` still works for users that have one.
- Existing student accounts continue to work unchanged.
