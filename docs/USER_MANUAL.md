# CHGLog User Manual

## Sign in

1. Open CHGLog from the Android personal or Work apps list.
2. Select **Continue with Google**.
3. Choose an approved company account.

Personal and unapproved domains cannot access the app. Globe accounts are
treated as WLN users; approved vendor accounts are onsite users.

## Search for a change

1. Enter the exact change number, for example `CHG0135067`.
2. Select **Search ACTIVE sheet**.
3. Review the title, objective, proponent, status, times, and available
   implementer details before continuing.

## Onsite check-in

1. Select **Continue to check in**.
2. Enter the onsite implementer's full name, company, and contact number.
3. Select **Submit check-in**.

The app records the authenticated email and login time automatically. Enter a
reachable contact number; the operation team may use it during implementation.

## Correct your details

Search the same CHG after it has been linked to your account. Select **Edit my
details**, correct the fields, and select **Save changes**. This updates the
existing record and Sheet details without changing the original login time.

## WLN user workflow

Globe WLN users see **Add to my activities** instead of the onsite form. Select
it to track the CHG. No onsite name, company, or contact is required, and the
existing Sheet details are not overwritten.

## Complete a hotline-assisted login

If Wireline logged the activity manually and it has not been linked to an
account, search the CHG and select **Complete manual login**. Confirm the onsite
details and submit. CHGLog keeps the original login time and WLN implementer,
then links the activity to your account.

## My activities

Select the history icon in the top app bar. The page shows your linked CHGs,
status, implementers, and check-in or check-out times.

- Today is selected by default.
- Use the date control to view another date.
- Activities started at or after 10 PM also appear on the following date.
- Records are retained for one month.

For delays or Wireline questions, select `(02) 7917-2873` and choose option 2.

## Notifications

Allow notification permission when prompted. CHGLog sends a notification when
an operator changes a linked activity to an approved status. If notifications
do not arrive, confirm that the work profile is active, CHGLog notifications are
enabled, and the device has internet access.

## Manual Sheet format for operators

Column T accepts independently optional labeled lines:

```text
Onsite implementer: Juan Dela Cruz
Company: Huawei
Contact: 09123456789
Email:
WLN implementer: Dagz
```

A WLN-only record may contain only:

```text
WLN implementer: Dagz
```

Enter P and T first, then set O to `login` to create the manual database record.
Later T-only corrections synchronize the manual details without generating a
status notification.

## Troubleshooting

| Problem | Action |
| --- | --- |
| Account rejected | Confirm its domain is approved by the administrator. |
| CHG not found | Verify all seven digits and that the CHG is on ACTIVE. |
| Wrong details | Search the CHG and use **Edit my details**. |
| Activity missing from history | Confirm it is linked to the same signed-in email. |
| No notification | Enable Android/work-profile notifications and internet. |
| App unavailable in Work apps | Ask IT to approve/install it through managed app distribution. |

