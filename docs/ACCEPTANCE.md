# Live acceptance checklist

Use three real accounts on the same Firebase project: administrator, employer and candidate.

1. Register employer; save company name and website. Confirm it cannot post before approval.
2. Admin approves company in Moderation. Employer posts a vacancy with a future deadline.
3. Admin finds pending vacancy in Vacancies and approves it. Candidate sees it in Explore.
4. Candidate fills profile, saves/unsaves role, tests search/type/field/mode and sort.
5. Candidate opens details and applies with an optional cover note. Confirm a second application is blocked.
6. Employer reviews name/email/headline/skills/education/experience and cover note in Applications. Move to Under Review, then Shortlisted. Candidate sees the updated stage without restart.
7. Candidate withdraws a shortlisted application. Employer cannot restore it. Selected and rejected applications cannot be withdrawn.
8. Employer closes the vacancy. Candidate discovery hides it; existing application snapshot remains readable. Reopen an approved unexpired vacancy to show it again.
9. Edit a vacancy. Confirm it returns to pending approval before candidate discovery.
10. Change employer company identity. Confirm company approval resets.
11. Candidate reports a listing. Admin opens it from Reports and resolves the report.
12. Admin suspends another account. It loses jobs/application access; reactivation restores access.
13. Restart app, confirm profile and appearance persist. Test a real gallery photo, oversized input and cancelled picker.
14. Check at 320px, 390px, tablet and desktop widths, large system text and keyboard open. Check dialogs and scrollable forms.
15. Disconnect/reconnect internet. Verify readable errors and eventual data synchronization. Firestore writes may wait for connectivity; avoid repeating an uncertain submission.

No CV uploads, Firebase Storage, chat, push notifications, background reminders, employer billing or external jobs API are included. This is a single-project hiring portal, not an independently audited production SaaS.
