# Master News Widgets API

This document defines the backend contract for the `Bugun` and `Bu Hafta`
summary widgets shown at the top of the news tab in the master page.

## Goal

The frontend must not calculate widget values, counts, ordering, or labels for
these summary cards anymore.

The backend is now responsible for sending:

- Which sections should appear and in what order
- Which cards should appear inside each section and in what order
- The exact strings the app should display on each card
- The tap behavior for each card

The Flutter app only renders the payload returned by the API.

## Frontend Files

The new frontend implementation lives in:

- `lib/backend/master_news_widgets_repository.dart`
- `lib/backend/view/master_news_widgets_view.dart`
- `lib/pages/new_view/news_tab_view.dart`

## Endpoint

`GET /master/news-widgets`

Base URL is still `Constants.baseUrl`, so production requests look like:

`https://akademiz-api.nortixlabs.com/master/news-widgets`

## Auth

The frontend calls this endpoint with the same Firebase bearer token pattern
used by other authenticated API calls in the app.

Expected header:

```http
Authorization: Bearer <firebase-id-token>
Accept: application/json
```

## Required Response Shape

The endpoint must return a JSON object with a top-level `sections` array.

```json
{
  "sections": [
    {
      "id": "today",
      "title": "Bugun",
      "cards": [
        {
          "id": "today-event",
          "kind": "event",
          "subtitle": "En yakin etkinlik",
          "value": "Yapay Zeka Atolyesi",
          "trailingText": "17:30",
          "action": {
            "type": "open_tab",
            "targetTabIndex": 1
          }
        },
        {
          "id": "today-news",
          "kind": "news",
          "subtitle": "Bugun yayimlanan haber",
          "value": "4 haber",
          "action": {
            "type": "scroll_news_list"
          }
        },
        {
          "id": "today-community",
          "kind": "community",
          "subtitle": "Bugun topluluk gonderileri",
          "value": "2 gonderi",
          "action": {
            "type": "open_tab",
            "targetTabIndex": 2
          }
        }
      ]
    },
    {
      "id": "week",
      "title": "Bu Hafta",
      "cards": [
        {
          "id": "week-event",
          "kind": "event",
          "subtitle": "Bu hafta one cikan etkinlik",
          "value": "Kariyer Gunleri",
          "trailingText": "Per",
          "action": {
            "type": "open_tab",
            "targetTabIndex": 1
          }
        },
        {
          "id": "week-news",
          "kind": "news",
          "subtitle": "Bu hafta yayimlanan haber",
          "value": "9 haber",
          "action": {
            "type": "scroll_news_list"
          }
        },
        {
          "id": "week-community",
          "kind": "community",
          "subtitle": "Bu hafta topluluk gonderileri",
          "value": "6 gonderi",
          "action": {
            "type": "open_tab",
            "targetTabIndex": 2
          }
        }
      ]
    }
  ]
}
```

## Field Definitions

### `sections[]`

- `id`: stable section key. Current expected values are `today` and `week`.
- `title`: exact section title to render.
- `cards`: ordered list of cards to render under that section.

### `cards[]`

- `id`: stable unique card id.
- `kind`: one of `event`, `news`, `community`.
- `subtitle`: small label shown above the main value.
- `value`: the main text shown by the card.
- `trailingText`: optional short value shown at the right side of the card.
- `action`: navigation behavior.

### `action`

- `type: "open_tab"` opens a master tab using `targetTabIndex`
- `type: "scroll_news_list"` scrolls within the current news tab

For `open_tab`, current tab indexes are:

- `1` = Events tab
- `2` = Community tab

## Important Rule: No Frontend Calculation

The frontend no longer decides:

- whether `Bu Hafta` or `Bugun` should appear first
- how many news items belong to `Bugun`
- how many community posts belong to `Bu Hafta`
- what event should be featured
- what short labels or summary strings should be shown

If the backend wants `Bu Hafta` to appear first, it must return the `week`
section first in the `sections` array.

If the backend wants to show `0 haber`, `Veri yok`, or any other text, it must
send that exact text inside `value`.

## Backend Responsibilities

The backend should precompute the widget payload before sending it to the app.

That includes:

- selecting the featured event for `today` and `week`
- computing news counts
- computing community counts
- formatting human-readable strings such as `4 haber`, `2 gonderi`, `17:30`,
  or `Per`
- choosing the display order of sections and cards

## Empty States

Recommended behavior:

- Return `sections: []` only if there is truly no widget content to show.
- Prefer sending explicit cards with values like `0 haber` instead of omitting
  cards, when the UI should still keep the layout.

If the API returns an empty `sections` array, the app shows a neutral fallback
message instead of inventing values locally.

## Compatibility Notes

The frontend currently tolerates:

- missing `trailingText`
- missing `targetTabIndex` for non-`open_tab` actions

The frontend does not calculate fallback card data from `/news`, `/events`, or
`/community/posts` for these widgets anymore.

## Suggested Backend Checklist

1. Implement `GET /master/news-widgets`
2. Require Firebase bearer auth, same as other authenticated endpoints
3. Return a top-level JSON object with `sections`
4. Precompute all summary strings server-side
5. Preserve stable `id` values for sections and cards
6. Control section/card display order directly in the response arrays
