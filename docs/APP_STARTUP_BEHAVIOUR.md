# App Startup Behaviour

This note describes what happens from tapping the app icon to the first few frames of the master view.

## Short Version

The app does not show the old Flutter `SplashPage` during normal startup. The native platform launch background is visible only until Flutter draws its first frame. The first Flutter UI is `_StartupShell`, which immediately builds `MasterView` and then layers startup status UI on top when needed.

## Timeline

1. The user taps the app icon.
2. Android launches `MainActivity`, which is the default Flutter activity in `android/app/src/main/kotlin/me/orbitium/akademiz/MainActivity.kt`.
3. While the Flutter engine is starting, Android shows `LaunchTheme` from `android/app/src/main/res/values/styles.xml`. Its window background is `@drawable/launch_background`, currently a plain light background.
4. Flutter enters `main()` in `lib/main.dart`.
5. `WidgetsFlutterBinding.ensureInitialized()` prepares the Flutter binding.
6. `runApp(const MyApp())` builds the app.
7. `MyApp` builds `MaterialApp` with `home: const _StartupShell()`.
8. `_StartupShell` immediately paints a `Stack` whose bottom layer is `const MasterView()`.
9. `MyApp.initState()` schedules `AppStartupController.instance.start()` with `WidgetsBinding.instance.addPostFrameCallback(...)`. This means Firebase startup work begins after the first Flutter frame has been scheduled, rather than blocking that first frame.

## First Master View Frames

`MasterView` starts on tab index `0`, so the initial title is `Haberler` and the first active tab is `NewsTabView`.

During `MasterView.initState()`:

- A three-tab `TabController` is created for News, Events, and Community.
- The initial tab is marked active in `_activatedTabs`.
- A post-frame callback starts badge checks, notification permission reminder scheduling, startup-state handling, and the delayed update check.
- Notification initialization and update checking are deferred through `AppStartupController.startupDeferral(...)` so they do not compete with the first few seconds of startup.

During the first `NewsTabView` frame:

- `_isInitialLoading` starts as `true`.
- The page renders skeleton loading content through `_buildLoadingState(...)`.
- After the first frame, `_loadInitialData()` reads cached news and cached master news widgets from local storage.
- If cached news exists, the skeleton is replaced with cached content quickly.
- Authenticated network refreshes wait until `AppStartupController.canUseAuthenticatedApis` is true.

## Startup Controller States

`AppStartupController` moves through these states:

- `idle`: before startup begins.
- `booting`: Firebase initialization is running. `_StartupShell` shows a thin top progress stripe over `MasterView`.
- `waitingForAgreement`: Firebase is ready, but the user has no stored agreement acceptance. `_StartupShell` overlays `AgreementsPage`.
- `ready`: the app can use authenticated APIs.
- `failed`: startup failed. `_StartupShell` overlays a retry UI with the last error.

After Firebase initializes, the controller:

- Registers the Firebase Messaging background handler.
- Starts simple notification setup without awaiting it.
- Checks whether there is already a Firebase user.
- If there is no user, checks whether the agreements were accepted in `SharedPreferences`.
- If accepted, marks startup ready. If not, waits for the agreements flow.

Authenticated API calls use `ensureAuthenticatedSession()`. If startup is ready enough and there is no current Firebase user, it signs in anonymously before returning true.

## Important Consequences

- The perceived first screen is the master view, not a separate splash route.
- The old `lib/pages/splash_page.dart` and `lib/widgets/image_splash.dart` are not part of the current `MaterialApp.home` startup path.
- Cached content is preferred for the first visible news data.
- Heavy startup work is intentionally pushed just after the first frame or deferred by the 10-second startup warmup window.
- Agreement and error states are overlays on top of `MasterView`, not replacement routes.
