# App Startup Performance Notes

This note records the likely launch-time bottlenecks in the current startup flow and the fixes worth considering. It focuses on the path from app icon tap to the first visible `Haberler` frames in `MasterView`.

## Current Flow

The normal app startup path is:

1. Android opens `MainActivity`.
2. Android shows `LaunchTheme` and `@drawable/launch_background` while the Flutter engine starts.
3. Flutter enters `main()` in `lib/main.dart`.
4. `runApp(const MyApp())` builds `MaterialApp`.
5. `MaterialApp.home` is `_StartupShell`.
6. `_StartupShell` immediately builds `const MasterView()` as the bottom layer.
7. `AppStartupController.instance.start()` is scheduled with `WidgetsBinding.instance.addPostFrameCallback(...)`.
8. `MasterView` starts on tab index `0`, so the initial visible tab is `NewsTabView` / `Haberler`.

The agreement check is part of `AppStartupController._performStartup()`. It happens after Firebase initialization and only after checking whether `FirebaseAuth.instance.currentUser` already exists.

## Main Findings

### Agreement Check

The agreement check is performed on app open, but it is not the main first-frame blocker.

Reasoning:

- `MasterView` is already placed under `_StartupShell` before startup work completes.
- Startup is triggered via a post-frame callback in `MyApp.initState()`, so the app does not intentionally wait for the agreement check before building the first Flutter UI.
- The check itself is a `SharedPreferences` read in `_hasStoredAgreementAcceptance()`.

Impact:

- It can delay the app reaching the `ready` state.
- It can cover `MasterView` with `AgreementsPage` if acceptance is missing.
- It delays authenticated API refreshes because those wait for `AppStartupController.canUseAuthenticatedApis`.

### Heavy First Flutter Frame

The first Flutter frame builds `MasterView` directly, not a tiny placeholder shell.

Reasoning:

- `_StartupShell` always includes `const MasterView()` at the bottom of its `Stack`.
- `MasterView` builds a full `Scaffold`, drawer, `NestedScrollView`, `SliverAppBar`, `TabBar`, animated background layers, and the first active tab.

Impact:

- If the device is slower, the user may keep seeing the native Android launch background until this full tree is ready to paint.
- The `Haberler` shimmer cannot appear before Flutter has produced this first master-view frame.

Potential fix:

- Keep `MasterView`, but simplify the very first frame. For example, gate expensive decorative/background layers until after a first-frame or short post-frame flag.
- Alternatively, introduce a very lightweight Flutter startup shell for the first frame, then swap in `MasterView` after one frame. This is a more visible behavior change, so it should be used carefully.

### Too Much Post-Frame Work Starts Together

Several async tasks start immediately after the first frame:

- `AppStartupController.instance.start()`
- `MasterView._checkBadges()`
- `MasterView._startPermissionReminder()`
- `MasterView._scheduleUpdateCheck()`
- `NewsTabView._loadInitialData()`

Reasoning:

- `MasterView.initState()` schedules badge checks and update scheduling in a post-frame callback.
- `NewsTabView.initState()` also schedules cached data loading in a post-frame callback.
- Startup initialization begins in a separate post-frame callback from `MyApp`.

Impact:

- These tasks do not block the first frame directly, but they compete immediately after it.
- Cache reads, JSON decoding, Firebase initialization, notification setup, and state updates can cluster during the moment when the UI should be settling.

Potential fixes:

- Delay non-visual work like badge checks by a short duration, for example 300-800 ms after the first frame.
- Start only the data needed for the visible `Haberler` skeleton/content first.
- Move update checks and notification setup farther away from the first interaction window.
- Batch state updates in `_checkBadges()` so it does not call `setState()` after each individual badge result.

### Badge Check Is More Expensive Than It Looks

`MasterView._checkBadges()` performs several sequential reads:

- Last viewed news from `TabBadgeService`.
- Cached news from `NewsFetcher`.
- Last viewed events.
- Cached events from `EventRepository`.
- Last viewed notifications.
- Saved notifications from `SimpleNotifications`.
- Last viewed community.
- Cached community posts from `CommunityRepository`.

Reasoning:

- These are local reads, but most go through `SharedPreferences`.
- Some reads decode cached JSON.
- The method can call `setState()` multiple times.

Impact:

- This work is not needed to paint the initial skeleton or initial cached news list.
- It can add main-isolate pressure right after launch.

Potential fixes:

- Run badge checks after initial news cache hydration.
- Load all last-viewed timestamps with one `SharedPreferences.getInstance()` call, or add a `TabBadgeSnapshot` method.
- Parallelize independent cache reads with `Future.wait`.
- Compute all unread booleans first, then call one `setState()`.

### News Cache Loading Can Skip Or Stall The Shimmer

`NewsTabView` starts with `_isInitialLoading = true`, and the shimmer branch exists in `_buildLoadingState(...)`.

Reasoning:

- If cached news exists, `_loadInitialData()` sets `_isInitialLoading = false` quickly.
- If cached news does not exist, `_isInitialLoading` can stay true until an authenticated background refresh succeeds.
- Background refresh waits for `AppStartupController.canUseAuthenticatedApis`, then applies `startupDeferral(_backgroundRefreshDelay)`.

Impact:

- With cache: shimmer may appear for only a blink or not be noticeable.
- Without cache: shimmer should remain, but it may be hidden behind native launch time, agreement overlay, or a subtle skeleton color.
- If the user expects a visible animated shimmer, the current path does not guarantee one.

Potential fixes:

- Make the skeleton highlight more visible in `AppSkeleton`.
- Keep a minimum shimmer display time, for example 250-400 ms, if a visible loading transition is desired.
- Parallelize `NewsFetcher().getCachedNews()` and `MasterNewsWidgetsRepository().getCachedWidgets()` in `_loadInitialData()`.
- If cache is empty, consider starting the first authenticated news fetch as soon as auth is ready without the extra 3-second background refresh delay.

### Faculty Fetch Starts Early

`NewsTabView._loadInitialData()` starts `_loadFaculties()` after cache load.

Reasoning:

- Faculty data is useful for filters, but it is not required to draw the first skeleton or first cached news cards.
- `fetchFaculties()` performs a network request.

Impact:

- It adds early network and callback work during startup.

Potential fixes:

- Defer faculty fetch until the filter UI is opened.
- Or schedule it after the first news content has painted.

### Notification Initialization Is Mostly Deferred, But Still Startup-Adjacent

`MasterView._handleStartupChanged()` initializes notifications after Firebase is ready, using `startupDeferral(_notificationsInitDelay)`.

Reasoning:

- The code intentionally defers notification initialization by up to the startup warmup window.
- `AppStartupController._performStartup()` also calls `SimpleNotifications.ensureInitialized()` without awaiting it.

Impact:

- This is better than blocking launch, but notification setup can still run during the early app session.
- On some platforms notification setup can touch native APIs and channels.

Potential fixes:

- Keep notification setup deferred.
- Consider removing or further delaying the early `SimpleNotifications.ensureInitialized()` call from startup if it is not required before notification initialization.

## Recommended Fix Order

1. Make `_checkBadges()` cheaper:
   - Delay it slightly.
   - Use one final `setState()`.
   - Parallelize independent reads.

2. Parallelize initial news cache reads:
   - Load cached news and cached master widgets together in `_loadInitialData()`.

3. Improve shimmer visibility:
   - Increase `AppSkeleton` highlight contrast.
   - Optionally enforce a short minimum loading display time.

4. Reduce early non-essential work:
   - Defer faculty fetching until filters are needed.
   - Keep update checks and notification setup outside the first few seconds.

5. Profile the first frame:
   - Run Flutter DevTools performance profiling on a cold start.
   - Compare native launch background duration, first Flutter frame time, and first `NewsTabView` content update time.

## Expected Result

These changes should make startup feel smoother by letting the first visible `Haberler` frame settle before secondary work begins. The most likely visible improvement is not from removing the agreement check, but from reducing the work clustered immediately after the first frame and making the skeleton state easier to see when it is actually active.
