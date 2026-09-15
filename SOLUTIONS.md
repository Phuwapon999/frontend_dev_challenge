## Part A — Bug tickets

### RES-101 · Search shows results for the wrong query

**Root cause**:

- This was a race condition caused by asynchronous network requests. When a user types a search query quickly — e.g. "s", "su", "sush", "sushi" — the app fires off several requests back to back. Because the fake API's network latency varies, an older request (e.g. "su") can finish and return *after* the latest one ("sushi"). The original code would then overwrite the latest results with the stale "su" response, so the UI displayed results that didn't match what was actually in the search box.

**Fix**:

- Added a class-level `_latestSearchQuery` variable to track what the most recent search term is. Every time `_search` runs, it updates this variable. When the API call finishes (after `await`), the code checks whether the `currentQuery` for that specific request still matches `_latestSearchQuery`. Only if they match is the code allowed to update `results` and turn off `isLoading`.

**Alternative considered & rejected**:

- Debouncing the input (waiting 300–500ms before firing the API call) was rejected. While it's a good way to reduce server load, it doesn't directly solve the race condition — if the first request happens to be abnormally delayed on the network and returns after the second request, the bug can still occur.

**Edge cases**:

1. Whitespace: handled with `query.trim()` at the start of the function, so repeatedly hitting the spacebar isn't treated as a distinct new query.
2. Flickering loading state: if an older request throws an exception into `catch`, or finishes later than expected, blindly setting `isLoading.value = false` could close the loading spinner while a newer request is still pending. So the code checks `_latestSearchQuery == currentQuery` before turning off the loading state in the final step / `finally` block as well.
3. Typing then quickly deleting everything: caught by checking `query.isEmpty` up front. If the query is empty, the app clears all state, resets `hasSearched`, and returns immediately without sending an unnecessary request to the API.

---

### RES-102 · Crash after leaving My Orders

**Root cause**:

- The `PickupCountdown` widget in `pickup_countdown.dart` uses `Timer.periodic` to count down and calls `setState()` every second, but the State class was missing a `dispose()` method to cancel the timer when the user leaves the screen. This left the timer running in the background, still trying to update the UI of a screen that had already been destroyed, producing the "`setState()` called after `dispose()`" error and a memory leak.

**Fix**:

- Added a `dispose()` method to `_PickupCountdownState` that calls `_timer?.cancel();` before calling `super.dispose();`. Also made sure the timer created in `initState` is properly assigned to the `_timer` variable, so the timer's lifecycle correctly ends together with the widget's.

**Alternative considered & rejected**:

- Using `if (!mounted) return;` before calling `setState()` was firmly rejected. While it prevents the crash, it only hides the symptom — the timer would keep silently looping every second forever, consuming CPU and causing an even worse memory leak if the screen is opened repeatedly.

**Edge cases**:

- Rapidly entering and leaving the screen: guarded against crashes by using `_timer?.cancel()` with the `?` operator, to safely handle the case where the screen is disposed before `initState` has even finished creating the timer, or where the variable is still null.

---

### RES-103 · Requests pile up the longer you browse

**Root cause**:

- A memory leak caused by a listener crossing lifecycles: `DealController` binds to `CartService` via an `ever()` call. When the user closes the screen, `DealController` cannot be garbage collected because `CartService` still holds a reference to its `_recheckAvailability` function. As a result, every time the cart changes, all these old, "dead" controllers get woken up and fire duplicate API calls simultaneously.

**Fix**:

- Captured the `Worker` returned by `ever()` and called `_cartWorker?.dispose()` inside the `GetxController`'s `onClose()` method, to fully detach the listener when the user leaves that screen.

**Alternative considered & rejected**:

- Checking `if (Get.isRegistered<DealController>())` inside `ever()` was rejected because it only treats the symptom — the listener would still be hanging onto memory.

**Edge cases**:

- If the user adds or removes items while the product detail screen is still open, `_cartWorker` continues to update state in real time as normal, and is only safely disposed of once the user presses Back (pops) out of that screen.

---

### RES-104 · Duplicate deals in the home feed

**Root cause**:

- A race condition between the refresh function and the load-more function. When the user scrolls to the bottom while `loadMore` is still awaiting a response, and then immediately pulls to refresh, two requests end up running in parallel. If `loadMore`'s page-2 data arrives after the refresh, it gets appended to the freshly refreshed page-1 data, causing duplicate items, cross-page data mixing, and an inaccurate item count.

**Fix**:

- Solved with a request ID tracking technique: an `int _currentRequestId = 0` is incremented every time a refresh occurs. Both functions capture the `requestId` at the time they were called into a local variable before firing the API `await`. Once the data returns, the code checks `if (requestId != _currentRequestId)`. If they don't match, it means a refresh happened in the meantime, so the system discards that batch of data and returns immediately, preventing stale data from overwriting or being appended to newer data.

**Alternative considered & rejected**:

- Checking `if (_page == 1)` inside `loadMore` to detect a page reset was rejected, because if `refreshDeals`'s request finishes first, `_page` would already be back to `1`, allowing `loadMore` to slip past the check and still append page-2 data onto page 1 as before.

**Edge cases**:

- Inside `loadMore`, `_isFetchingMore = false` is set before returning early when the request ID doesn't match, to prevent the loading state from getting stuck and blocking the user from loading further pages in the future.

---

### RES-105 · Home feed is janky and memory keeps climbing

**Root cause**:

1. `Obx` wrapped the entire `ListView` widget, while the controller's `offset` value kept updating continuously as the user scrolled. This forced Flutter to rebuild the entire home screen up to 60 times per second while scrolling.
2. The deal list was built using `...controller.visibleDeals.map(...)` inside a plain `ListView`, forcing the system to render every single product card into memory up front, even ones that weren't yet visible.
3. The image-loading widget in `the_network_image.dart` cached full-resolution images in memory without any downscaling, draining RAM when scrolling through many images.

**Fix**:

- Restructured from a plain `ListView` to a `CustomScrollView` using `SliverList`, so product cards are only rendered when they scroll into view. Also split the single large `Obx` into smaller, targeted ones wrapping only the `FilterChip` and `FloatingActionButton`, so scrolling no longer triggers list rebuilds.

**Alternative considered & rejected**:

- Using a single `ListView.builder` for everything was rejected, because the Home screen has a Flash Deals header and Filter section with a different look from the product list. Trying to handle this with index-based if/else checks inside `ListView.builder` would make the code hard to read and maintain. Using `CustomScrollView` with Slivers is the cleaner, more correct approach.

**Edge cases**:

- Fast scrolling: even with Slivers rendering only what's on screen, quickly fetching images over the network can cause temporary blank spaces. Adding a grey shimmer placeholder while images load helps keep the experience smooth and avoids visual jank.

**Performance Evidence (DevTools)**:
* **Before Fix:** Frame rate drops and visible jank — lots of red bars from widgets being rebuilt repeatedly.
  ![Before Performance](PerformanceEvidence/res-105-before-performance.png)

* **After Fix:** Smooth, non-janky scrolling — the red bars are clearly gone, since cards are only rebuilt when they enter the viewport.
  ![After Performance](PerformanceEvidence/res-105-after-performance.png)

---

### RES-106 · Wrong pickup times; "Pickup today" filter misses deals

**Root cause**:

- The app took time data from the API — in ISO-8601 UTC format — and parsed it directly into a `DateTime` object via `DateTime.parse()`, without converting it to the user's local time. This caused displayed times to be off from reality — e.g., in Thailand, which is UTC+7, pickup times would be off by 7 hours. This discrepancy also broke the "Pickup today" filter, since a UTC timestamp could still fall on "yesterday" relative to the user's local calendar.

**Fix**:

- Appended `.toLocal()` to `DateTime.parse(...)` inside the `fromJson` factory in the pickup window model, so Dart correctly calculates the offset and converts UTC to the device's local time zone before the value is stored, displayed, or compared.

**Alternative considered & rejected**:

- Manually adding a fixed offset, e.g. `.add(Duration(hours: 7))`, was rejected as a hardcoded approach that would immediately break if the user opened the app in a different time zone, or in a country observing Daylight Saving Time. The built-in `.toLocal()` function, purpose-built for this, is the correct and most robust solution.

**Edge cases**:

- Leaving the app open overnight or across time zones: since time is converted via `.toLocal()` at the moment data is received from the API, if a user leaves the app open past midnight, the "Pickup today" label may not update automatically. The user needs to pull-to-refresh so the system recalculates the date/time condition against the current local time.

---

### RES-107 · Deep link opens to a crash

**Root cause**:

- The app crashed immediately when opened via a deep link (e.g. from a push notification), because code in `DealDetailsController`'s `onInit` read `Get.arguments` and force-cast it with `as DealModel` unconditionally. When opened via deep link, no object is passed through memory, so `arguments` is `null`, causing a type-cast error and a crash. Additionally, the UI wasn't designed to handle an asynchronous loading state at all.

**Fix**:

1. Updated the argument-handling logic to support two paths: `if (args is DealModel)` for normal navigation, and reading `Get.parameters['id']` to call the API (`dealRepo.fetchById`) for deep links.
2. Introduced a state machine (`enum DealLoadState`) to manage the screen's state: `loading`, `ready`, and `error`.
3. Updated the UI (`DealDetailsScreen`) to respond to `loadState`, adding a loading screen while waiting on the API, and an error screen with a Retry button to handle failed loads.

**Alternative considered & rejected**:

- Using just a simple boolean (`isLoading`) was rejected. While it would prevent a crash while waiting for data, it doesn't cover the case where the API call fails. Using an enum-based `DealLoadState` alongside proper error UI and a retry mechanism is safer and gives a better user experience.

**Edge cases**:

- Non-existent product ID (invalid/expired): if a deep link supplies the ID of a deleted or malformed product, the app doesn't crash — the logic transitions to `DealLoadState.error` and shows a "We couldn't load this deal" message instead of letting the app hang or crash.

---

## Part B — Features

### F-1 · Live flash-sale countdowns

**Approach**:

- Built a separate `LiveCountdownBadge` widget using `StreamBuilder<DateTime>` to scope rebuilds to just the countdown text every second, without affecting the rest of the card. This allows more than 100 cards with countdowns to render without dropping frame rate.

- Used `StreamBuilder<bool>` combined with `.distinct()` to detect the expired state, turning the card grey and disabling taps the moment time runs out. `.distinct()` guarantees the card only rebuilds once for the color change, not every second.

- Added a `Timer.periodic` inside `CartService`, running in the background at the global session level, checking every second for expired cart items. If an expired item is found, it's removed from `items` immediately, `items.refresh()` is called to force the cart UI to update in real time, and a `Get.snackbar` clearly notifies the user.

**Alternative considered & rejected**:

- Using a single `Timer` with `setState` or an `Obx` wrapping the whole screen was rejected, since it would force a full-screen rebuild every second, violating the project's performance requirements.

**Edge cases**:

- Item expires while still in the cart: handled by the global `Timer.periodic` in `CartService` checking the cart every second. If an expired item is found, `removeWhere` removes it, `items.refresh()` updates the cart UI in real time, and a snackbar clearly notifies the user.

- Time zone drift: `DateTime.now().difference(...)` calculations work correctly and seamlessly since the data model was already fixed (as part of RES-106) to convert UTC to the device's local time zone.

---

### F-2 · Impression tracking

**Approach**:

- Built a `DealImpressionTracker` widget wrapping each product card, using `VisibilityDetector` to check whether `visibleFraction >= 0.5`. If met, it starts a 1-second timer without calling `setState()`, avoiding rebuilds that would hurt frame rate.

- Built a `_batchQueue` in `AnalyticsService`. When the first event comes in, a 15-second timer starts; once 10 events accumulate or 15 seconds pass (whichever comes first), the batch is packaged and sent to `FakeApiService.sendAnalyticsBatch`, then the queue is cleared.

**Verification**:

- Tested by going to Home → ⋮ → Analytics debug. After looking at a card for more than 1 second, a `deal_impression` entry appears immediately, with full properties: `deal_id`, `source`, `position`.

- Checked the Debug Console for log output confirming the API call, e.g. `POST /analytics/batch events=10`, when the batch condition is met.

**Edge cases**:

- `onVisibilityChanged` checks immediately: if visibility drops below the 50% threshold before the 1-second timer completes, `_timer?.cancel()` is called, preventing a junk event from being queued.

- Duplicate-view prevention: implemented via a `Set<int> _seenDealIds` in `AnalyticsService`, ensuring a given deal is only ever recorded once per app session, even if the user scrolls up and down repeatedly.

- With the 15-second timer starting after the first event, pipeline latency is minimized, reducing the risk of losing impression data if the user backgrounds or closes the app suddenly.

---

### F-3 · Stock reservations with optimistic UI

**Approach**:

- When the user taps to add an item, the UI updates immediately to show it in the cart, then the `reserveDeal` API is called in the background. If a stock conflict occurs (API returns a 409 error), the system rolls back by immediately removing the item from the cart and showing a snackbar notification.

- Added `reservationId` and `expiresAt` fields to `CartItemModel`, and built a widget showing a 5-minute countdown per item on the cart screen.

- When the user removes an item, or reduces its quantity to 0, the `releaseReservation` API is called to return the stock to the central system immediately.

**Deliberately underspecified — my decision**:

- What happens when a reservation expires while still in the app: decided to keep the item in the cart, but change the UI — the card turns grey, the quantity +/- buttons become a trash icon, and the Checkout button is locked.

- Reasoning: to avoid confusing the user by having an item silently disappear from their cart for no apparent reason. Showing the expired state and requiring the user to explicitly remove it reduces confusion, especially right before checkout.

**Edge cases**:

- Catches a 410 error ("Reservation Expired") from `orderRepo.checkout()` to prevent checking out with stock that has already expired, showing a notification asking the user to review their cart again.

---

### AI usage log

**Tools used**

- **Claude**:
  - RES-101: analyzed the root cause of the search race condition; reviewed self-written fix code
  - RES-104: analyzed the root cause of duplicate deals; helped design the race-condition fix pattern (request generation guard)
  - RES-107: analyzed the root cause of the deep-link crash; helped fix `DealDetailsController` / `DealDetailsScreen`
  - Helped structure `solutions.md`

- **Gemini**:
  - Part A (tickets actually used): root-cause analysis, log analysis
  - Part B (features actually used): advice on DevTools profiling

**Examples of AI giving incorrect or misleading suggestions**

**Example 1 — RES-104**

**AI suggested**: Increment `_page++` before calling `fetchDeals()`, then decrement it (`_page--`) in the `catch` block if the request fails — a rollback pattern.

**Why it was a problem**: This mutates state (`_page`) before knowing whether the request actually succeeds. If a concurrent call comes in while still awaiting, this creates a greater risk of inconsistent state.

**How I caught it**: Comparing it against an alternative, I found that if the `_page` mutation is deferred until *after* the fetch succeeds — using a local variable like `nextPage` to hold the value in the meantime — no rollback is needed at all, and it's safer.

**What I did instead**: Switched to a "commit state only on success" (mutate-after-success) pattern instead of mutate-then-rollback.

**Example 2 — RES-107**

**AI suggested**: The crash was caused by a race condition during cold start — the catalog hadn't finished loading yet when the deep link was resolved — or alternatively a type mismatch between the `id` in the URI (a String) and the `id` stored in the catalog (an int).

**Why it was a problem**: Neither explanation was the actual root cause. The real bug was much simpler: the deep-link handler called `Get.toNamed(route)` without passing `arguments:` at all, making `Get.arguments` simply `null`, and the controller unconditionally wrote `deal = Get.arguments as DealModel`. There was no catalog issue, no race condition, and no type coercion involved whatsoever.

**How I caught it**: I had to actually look at `onInit`, the deep-link dialog handler, and the real route table before the true cause became clear.

**What I did instead**: Discarded the race-condition and type-mismatch theories entirely, and based the fix only on what the code actually showed — branching between `Get.arguments is DealModel` and the deep-link fetch-by-id case.

---

### Design questions

**Q1**:

- A `GetxController` exists outside the Flutter widget tree; its lifecycle is managed by GetX's dependency injection system, meaning it can remain alive in memory longer than the widget that created it — even after that widget has been destroyed — unless it's explicitly deleted or properly bound to route bindings. In contrast, a widget's `State` is fully tied to the UI tree, and its `dispose()` method is guaranteed to be called when that widget is removed.

- This mismatch is exactly what caused the memory leak in RES-103: when `DealController` was closed and removed from the screen, it remained alive in memory because it had bound an `ever()` listener to `CartService`. In short, the UI's state had "died," but the controller was still alive — causing redundant background API calls to fire every time the cart changed.

**Q2**

- Wrapping `Obx` around a large subtree — e.g. an entire screen or an entire `ListView` — significantly hurts performance, because `Obx` automatically tracks every observable variable read within it. If any one of those variables changes, it forces the *entire* subtree under that `Obx` to rebuild.

- As seen in RES-105, wrapping the whole `CustomScrollView` in `Obx` while reading a rapidly-changing variable like `scrollOffset` forced Flutter to rebuild the entire product list up to 60 times per second while scrolling. The correct approach is to scope rebuilds as narrowly as possible — e.g. wrapping `Obx` only around the specific `Text`, `FilterChip`, or `FloatingActionButton` that actually needs to react to that state.

**Q3**

- For catching a time-zone bug like RES-106, we can't rely on manual testing on a single physical device, because the developer's machine's current time zone might happen to coincide with the logic and mask the bug. I would write automated unit tests that explicitly simulate different time-zone environments.

---

### Time spent

- Total time spent: approximately 8 hours

1. Part A (Bug fixing): approximately 4 hours
2. Part B (Features): approximately 3 hours
3. Documentation & cleanup: approximately 1 hour

**What's unfinished**:

- Comprehensive automated testing (unit tests and widget tests) was skipped due to time constraints. The current optimistic-UI rollback only uses a simple snackbar notification. An offline retry queue was cut from scope for now.