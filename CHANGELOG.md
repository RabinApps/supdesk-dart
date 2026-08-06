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
