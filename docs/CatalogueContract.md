# Catalogue release contract (schema version 1)

Real food data enters the app only as a **catalogue release**: one JSON
document that is validated as a whole. Either every record is valid and the
release is used, or nothing from it is used and every problem is reported.
Nothing is repaired, guessed or defaulted.

Code: `lib/data/food/catalogue_release.dart` (the contract and validation) and
`lib/data/food/catalogue_release_provider.dart` (the offline provider).
Tests: `test/catalogue_release_test.dart`.

## What is NOT part of this contract yet

- Wiring a release file into the app (asset declaration and loading). The
  provider takes a loader function, so any text source works.
- Recipe records and cooking adjustments (schema version 2 or later).
- Downloaded updates, signatures and rollback.

## Release

| Field | Required | Rule |
|---|---|---|
| `schemaVersion` | yes | Must be `1`. Any other value is rejected before anything else is read. |
| `catalogueId` | yes | 2 to 16 lowercase letters or digits, starting with a letter. `sample` is reserved. Every food id starts with it and a colon. |
| `releaseId` | yes | Looks like `2026.10.1` (year, month, release number). A published release is never edited; corrections are a new release. |
| `publishedOn` | yes | Real date, `yyyy-mm-dd`. |
| `sources` | yes | At least one source. |
| `foods` | yes | At least one food. Ids and searchable names must be unique. |

Unrecognised fields are rejected, so a typo cannot silently drop data.

## Source

| Field | Required | Rule |
|---|---|---|
| `id` | yes | 2 to 32 characters: lowercase letters, digits, underscore, hyphen; starts with a letter. Unique. |
| `name` | yes | Name of the upstream dataset. |
| `version` | yes | Edition or release of the upstream data. |
| `licence` | yes | Licence name or summary. |
| `licenceStatus` | yes | `cleared`, `permissionPending` or `unresolved`. **Only `cleared` is accepted in a release.** |
| `licenceEvidence` | yes | Text recording why reuse is permitted (where the licence is published, or a permission reference). |
| `retrievedOn` | yes | Date the upstream data was obtained. |
| `attribution` | no | Credit to show, when the licence requires one. |
| `url` | no | `https://` or `http://` link. |

A source whose permission has not been granted (for example one that needs
written permission) cannot appear in a release, so its data cannot be bundled
by accident.

## Food

| Field | Required | Rule |
|---|---|---|
| `id` | yes | `catalogueId:` followed by 2 to 64 characters: lowercase letters, digits, underscore; starts with a letter. Stable: never reused for a different food. |
| `name` | yes | Must contain letters or digits. Unique once case and punctuation are ignored. |
| `aliases` | no | List of non-blank names (regional names, spellings, Tamil). |
| `category`, `region` | yes | Names from the app's food categories and regions. |
| `state` | yes | `raw`, `cooked` or `ready`: what the per-100 g values describe. |
| `preparation`, `family`, `variety` | no | As in the app's food model. |
| `status` | yes | Must be `verified`. Sample, personal and recipe records are rejected. |
| `sourceId` | yes | Must be listed in `sources`. |
| `recordId` | yes | The record's identifier in the upstream dataset. |
| `url` | no | Link to the upstream record. |
| `matchNote` | no | Why this upstream record fits this food. |
| `nutrients` | yes | See below. |
| `servings` | no | See below. Every food also has a built-in 1 g serving. |
| `variants` | not allowed | Cooking multipliers are rejected; model each preparation as its own record. |

## Nutrients (per 100 g of the food in its stated state)

- The seven core nutrients (`energy`, `protein`, `carbohydrates`, `fat`,
  `fibre`, `sugar`, `sodium`) must each be **stated**: a number, or `null` when
  the source has no value.
- `null` means unknown. It is never converted to zero. A real zero is written
  as `0`.
- `energy` cannot be `null`: a record without energy cannot be logged.
- Micronutrients are optional. Leaving one out, or writing `null`, means
  unknown.
- Values must be finite, not negative, with at most 3 decimal places (the app
  stores thousandths of a unit).
- Sanity bounds per 100 g catch unit slips: energy up to 950 kcal, gram
  nutrients up to 100 g, milligram nutrients up to 100,000 mg, microgram
  nutrients up to 1,000,000 ug, and protein plus carbohydrate plus fat at most
  101 g.
- Nutrient names are the app's names (`energy`, `protein`, `iron`, `folate`,
  and so on). Unknown names are rejected.

Energy is not cross-checked against the macronutrients. A source value that
differs from a calculated value is not automatically wrong, so it is never
"corrected".

## Servings

Each household serving needs:

| Field | Required | Rule |
|---|---|---|
| `id` | yes | 1 to 32 characters: lowercase letters, digits, underscore; starts with a letter. `g` is reserved. Unique within the food. |
| `singularLabel`, `pluralLabel` | yes | For example "piece" and "pieces". |
| `grams` | yes | Above 0, at most 5000, at most 3 decimal places. |
| `weightBasis` | yes | `measured` or `estimated`. (`exact` is only for the built-in gram serving.) |
| `note` | yes | Where the weight came from. A bowl or a piece has no universal weight, so this is mandatory. |

## Skeleton

Angle-bracket items are placeholders. This is not valid JSON until they are
filled with real, sourced values.

```
{
  "schemaVersion": 1,
  "catalogueId": "<2-16 lowercase letters or digits>",
  "releaseId": "<year.month.number>",
  "publishedOn": "<yyyy-mm-dd>",
  "sources": [
    {
      "id": "<source id>", "name": "<dataset name>", "version": "<edition>",
      "licence": "<licence>", "licenceStatus": "cleared",
      "licenceEvidence": "<why reuse is permitted>", "retrievedOn": "<yyyy-mm-dd>"
    }
  ],
  "foods": [
    {
      "id": "<catalogueId>:<food_slug>", "name": "<name>",
      "category": "<category>", "region": "<region>", "state": "<raw|cooked|ready>",
      "status": "verified", "sourceId": "<source id>", "recordId": "<upstream id>",
      "nutrients": {
        "energy": <number>, "protein": <number or null>, "carbohydrates": <number or null>,
        "fat": <number or null>, "fibre": <number or null>, "sugar": <number or null>,
        "sodium": <number or null>
      }
    }
  ]
}
```

## Adding data

1. Confirm the source's licence and record the evidence. Do not include a
   source whose permission is pending or unresolved.
2. Write the release JSON with sourced values only. Leave unknown nutrients as
   `null`.
3. Parse it with `CatalogueRelease.parse` (the tests show how). Fix every
   reported problem; do not weaken the rules.
4. Publish corrections as a new `releaseId`.
