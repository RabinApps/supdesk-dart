## 0.2.0

### Removed

- **`ForbiddenException` and `SupDeskErrorCode.forbidden`.** SupDesk no longer returns the
  `forbidden` code — write access is available on every plan now, and the plan gate was the
  only thing that raised it. A 403 arriving from somewhere else (a proxy, a WAF) surfaces
  as the base `SupDeskApiException` with its status and body intact. Delete any
  `on ForbiddenException` clause; `on SupDeskApiException` covers it.

### Added

- `PostStatus.backlog`.
- `isPrivate` and `moderationStatus` on `Submission` and `Feedback`, plus the
  `ModerationStatus` union (`published`, `pending`, `spam`). Every post created through the
  API now runs the same spam assessment as one filed from the portal; a held post triggers
  no notifications and waits in Spam & moderation in the console.
- `SupDeskLocale.ar`, `.he` and `.hi` — eleven locales in total.

### Changed

- Writes no longer require a paid plan, and the dartdoc, README and examples say so. What
  is still metered is creation: `submissions.create` and `feedback.create` count against
  the monthly submission quota and raise `LimitReachedException` at the cap.

## 0.1.0

- Initial release.
- `SupDesk` client covering submissions, feedback, changelog, messages, waitlist,
  beta programs and testers, help center articles and article categories.
- Auto-paging `Page<T>` with `autoPaging()` streams over every remaining page.
- Typed exception hierarchy dispatched on the API's `error.code`, including the
  two distinct 429s (`rate_limited` vs `limit_reached`).
- Exponential backoff with jitter that honours `Retry-After` and never replays a
  metered `POST` by default.
- HMAC-SHA256 webhook signature verification with constant-time comparison.
