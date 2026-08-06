/// Shared workflow status across submissions and feedback.
///
/// Declared as an extension type over [String] rather than an `enum`: a status
/// SupDesk adds server-side stays representable and comparable instead of
/// crashing a client that predates it, while the documented values still
/// autocomplete.
extension type const PostStatus(String value) {
  /// Newly filed, not yet triaged.
  static const PostStatus open = PostStatus('open');

  /// Accepted and scheduled.
  static const PostStatus planned = PostStatus('planned');

  /// Being worked on.
  static const PostStatus inProgress = PostStatus('in_progress');

  /// Shipped.
  static const PostStatus done = PostStatus('done');

  /// Every documented value.
  static const List<PostStatus> values = [open, planned, inProgress, done];
}

/// What kind of thing a submission describes.
extension type const SubmissionType(String value) {
  /// Something is broken.
  static const SubmissionType bug = SubmissionType('bug');

  /// Something is missing.
  static const SubmissionType feature = SubmissionType('feature');

  /// Every documented value.
  static const List<SubmissionType> values = [bug, feature];
}

/// Languages SupDesk accepts for end-user notification emails and content.
///
/// Named `SupDeskLocale` rather than `Locale` so it never collides with
/// `dart:ui`'s or `package:intl`'s.
extension type const SupDeskLocale(String value) {
  /// English.
  static const SupDeskLocale en = SupDeskLocale('en');

  /// German.
  static const SupDeskLocale de = SupDeskLocale('de');

  /// Spanish.
  static const SupDeskLocale es = SupDeskLocale('es');

  /// French.
  static const SupDeskLocale fr = SupDeskLocale('fr');

  /// Italian.
  static const SupDeskLocale it = SupDeskLocale('it');

  /// Japanese.
  static const SupDeskLocale ja = SupDeskLocale('ja');

  /// Russian.
  static const SupDeskLocale ru = SupDeskLocale('ru');

  /// Chinese.
  static const SupDeskLocale zh = SupDeskLocale('zh');

  /// Every documented value.
  static const List<SupDeskLocale> values = [en, de, es, fr, it, ja, ru, zh];
}

/// Publication state of a changelog entry.
extension type const ChangelogStatus(String value) {
  /// Not visible to end users.
  static const ChangelogStatus draft = ChangelogStatus('draft');

  /// Queued for a future publish date.
  static const ChangelogStatus scheduled = ChangelogStatus('scheduled');

  /// Live.
  static const ChangelogStatus published = ChangelogStatus('published');

  /// Every documented value.
  static const List<ChangelogStatus> values = [draft, scheduled, published];
}

/// Whether a support conversation is still accepting replies.
extension type const ThreadStatus(String value) {
  /// Accepting replies.
  static const ThreadStatus open = ThreadStatus('open');

  /// Resolved.
  static const ThreadStatus closed = ThreadStatus('closed');

  /// Every documented value.
  static const List<ThreadStatus> values = [open, closed];
}

/// Who wrote a message in a thread.
extension type const MessageSender(String value) {
  /// The person who opened the thread.
  static const MessageSender endUser = MessageSender('end_user');

  /// Someone on the workspace team.
  static const MessageSender member = MessageSender('member');

  /// SupDesk itself.
  static const MessageSender system = MessageSender('system');

  /// Every documented value.
  static const List<MessageSender> values = [endUser, member, system];
}

/// Where a signup sits in the waitlist queue.
extension type const WaitlistStatus(String value) {
  /// Still queued.
  static const WaitlistStatus waiting = WaitlistStatus('waiting');

  /// Sent an invitation.
  static const WaitlistStatus invited = WaitlistStatus('invited');

  /// Accepted the invitation.
  static const WaitlistStatus joined = WaitlistStatus('joined');

  /// Every documented value.
  static const List<WaitlistStatus> values = [waiting, invited, joined];
}

/// Publication state of a help center article.
extension type const ArticleStatus(String value) {
  /// Not visible in the help center.
  static const ArticleStatus draft = ArticleStatus('draft');

  /// Live.
  static const ArticleStatus published = ArticleStatus('published');

  /// Retired but retained.
  static const ArticleStatus archived = ArticleStatus('archived');

  /// Every documented value.
  static const List<ArticleStatus> values = [draft, published, archived];
}

/// Whether a beta tester has accepted their invitation.
extension type const BetaTesterStatus(String value) {
  /// Invited, not yet accepted.
  static const BetaTesterStatus invited = BetaTesterStatus('invited');

  /// Participating.
  static const BetaTesterStatus joined = BetaTesterStatus('joined');

  /// Every documented value.
  static const List<BetaTesterStatus> values = [invited, joined];
}
