# Theme 2 — Full Build Reference

> **App:** PnP React Native Firebase Auth Kit (`com.geekyhawks.pnp.rn`)
> **Theme 2** is one of seven selectable auth UI themes. It is the **maroon → purple horizontal‑gradient** design with a rounded white "sheet" form. This document maps the *entire* Theme 2 build: its screens, styling, navigation wiring, state, and the Firebase service chain underneath it.

---

## 1. Where Theme 2 lives

```
src/screens/login2/
├── landing/
│   ├── Landing2Screen.js      # entry screen (SIGN IN / SIGN UP choice)
│   └── styles.js
├── login/
│   ├── Login2Screen.js        # email + password sign in
│   └── styles.js
├── signup/
│   ├── Signup2Screen.js       # email + password + confirm + terms
│   └── styles.js
└── forgot/
    ├── ForgotPassword2Screen.js  # email -> reset link
    └── styles.js
```

Theme 2 is **self‑contained presentation** — all four screens own their layout/styling and delegate every real operation to shared layers (`services/`, `firebase/`, `redux/`, `helpers/`, `components/`, `config/`).

---

## 2. Entry point — how you reach Theme 2

The **Choice screen** lists all themes. The "Theme 2" button navigates to `Landing2`:

`src/screens/choice/ChoiceScreen.js`
```js
const openLogin2 = () => {
    navigation.navigate(ScreenNames.Landing2);
}
// ...
<TouchableOpacity style={styles.button} onPress={openLogin2}>
    <Text style={styles.buttonText}>Theme 2</Text>
</TouchableOpacity>
```

Runtime path to see it: **App Intro → Choose Theme → "Theme 2" → Landing2**.

---

## 3. Navigation graph (Theme 2 subset)

All four screens are registered in the **unauthenticated** stack `loginScreens()` inside `src/navigators/AppNavigator.js`:

```js
<Stack.Screen name={ScreenNames.Landing2} component={Landing2Screen} />
<Stack.Screen name={ScreenNames.Login2}   component={Login2Screen} />
<Stack.Screen name={ScreenNames.Signup2}  component={Signup2Screen} />
<Stack.Screen name={ScreenNames.Forgot2}  component={ForgotPassword2Screen} />
```

Route name constants (`src/config/Constants.js`):
```js
Landing2: "Landing2",
Login2:   "Login2",
Signup2:  "Signup2",
Forgot2:  "Forgot2",
```

### In‑theme navigation flow

```
                 ┌──────────────────────┐
                 │     Landing2Screen   │
                 │  (SIGN IN / SIGN UP) │
                 └─────────┬───────┬────┘
              SIGN IN ─────┘       └───── SIGN UP
                  │                          │
                  ▼                          ▼
          ┌───────────────┐          ┌────────────────┐
          │  Login2Screen │◄────────►│ Signup2Screen  │
          │               │  "Sign   │                │
          │  "Sign up" ───┼──up/in"──┤  back/goBack   │
          └───────┬───────┘          └────────────────┘
                  │ "Forgot Password?"
                  ▼
        ┌──────────────────────┐
        │ ForgotPassword2Screen│  ── Login/back ──► goBack()
        └──────────────────────┘
```

- **Landing2** → `Login2` (SIGN IN) | `Signup2` (SIGN UP)
- **Login2** → `Forgot2` (Forgot Password?) | `Signup2` (Sign up)
- **Signup2** → `goBack()` (Sign in / already have an account)
- **Forgot2** → `goBack()` (after reset email sent, or "Login")

On **successful login/signup**, no manual navigation is performed — `auth().onAuthStateChanged` in `AppNavigator` fires, swaps the whole tree to the logged‑in / create‑profile stack, and the theme's accent color is pushed to Redux (see §6).

---

## 4. The four screens in detail

Every screen shares the same shell:
```jsx
<View style={commonStyles.container}>
  <PnPStatusBar hideAppBar statusBarColor={"#661e3c"} />
  <LinearGradient
    start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }}
    colors={['#b61737', '#8b1c3c', '#661e3c', '#401b3a', '#2a1737']}
    style={styles.content}>
     ...
  </LinearGradient>
</View>
```
A **5‑stop left‑to‑right gradient** (bright maroon → deep purple) is the signature of Theme 2.

### 4.1 Landing2Screen — `landing/Landing2Screen.js`
Purpose: brand splash + entry choice.
- Logo `Images.login1Logo` + heading **"PLUG N PLAY"**.
- **"Welcome Back"** title.
- Two pill buttons: outlined **SIGN IN** (`reverseButton*`) → `Login2`; solid white **SIGN UP** → `Signup2`.
- "Login with Social Media" row: Facebook / Google / Instagram icons in white circular touchables (**decorative — no onPress handlers wired**).

### 4.2 Login2Screen — `login/Login2Screen.js`
Purpose: email/password sign in. Headers **"Hello" / "Sign in!"** over a rounded white form sheet.

State: `email, password, showPassword, isEmailReady, emailError, passwordError, loading`.

Validation in `onLoginPressed()`:
| Field | Rule | Error |
|---|---|---|
| email | non‑empty | "Please enter your email" |
| email | `isEmailValid()` regex | "Please enter a valid email" |
| password | non‑empty | "Please enter your password" |
| password | `length >= 6` | "Password needs to be 6 characters long" |

On pass:
```js
setLoading(true);
await loginWithEmailAndPassword(email, password);   // services/UserService
dispatch(themeUpdated({ themePrimaryColor: "#8b1c3c" }));  // theme accent
```
UI details: email shows a green `tick` when valid; password has show/hide eye toggle (`showPassword`/`hidePassword`); "Forgot Password?" → `Forgot2`; spinner (`CActivityIndicator`, color `#8b1c3c`) replaces the button while loading; footer "Don't have account? Sign up" → `Signup2`. Errors surfaced via `showAlertDialog`.

### 4.3 Signup2Screen — `signup/Signup2Screen.js`
Purpose: registration. Headers **"Nice to have you." / "Sign up here!"**.

State: `email, password, confirmPassword, showPassword, showConfirmPassword, termsSelected, isEmailReady, loading, errors{}` (object keyed by field).

Validation in `onSignupPressed()`:
| Field | Rule | Error |
|---|---|---|
| email | non‑empty / `isEmailValid()` | "Enter your Email" / "Enter a valid Email" |
| password | non‑empty / `>= Constants.passwordMinLength` (6) | "Enter your Password" / "Password should be minimum of 6 chars" |
| confirmPassword | non‑empty / `=== password` | "Enter Confirm Password" / "Passwod and Confirm Password do not match" *(typo in source)* |
| terms | `termsSelected === true` | "You need to agree to Terms and Conditions" |

On pass:
```js
setLoading(true);
await signUpWithEmailAndPassword(email, password);   // services/UserService
dispatch(themeUpdated({ themePrimaryColor: "#661e3c" }));
```
Extra UI: custom checkbox (`commonStyles.checkbox` / `checkboxSelected`, tinted `#8b1c3c`) + "I agree to **Terms and Conditions.**" link → `openUrlInBrowser(Urls.termsAndConditions)`. Footer "Already have an account? Sign in" → `goBack()`.

> ⚠️ The confirm‑password eye icon uses `showPassword` (not `showConfirmPassword`) for its image source — a minor source bug carried as‑is.

### 4.4 ForgotPassword2Screen — `forgot/ForgotPassword2Screen.js`
Purpose: password reset. Headers **"Forgot Password?" / "Enter Details"**.

> Note: this screen's `styles.js` uses a **flat red `#9f0000`** background/accents instead of the maroon `#8b1c3c` used by Login/Signup — visually the odd one out within Theme 2.

State: `email, isEmailReady, emailError, loading`.
Flow `onForgotPressed()`: validate email → `sendPasswordResetEmail(email)` → success dialog "Email Sent!" → `navigation.goBack()`. Submit button label is **"Submit"**; spinner color here is `#9f0000`.

---

## 5. Styling system

Each screen has a local `styles.js`. Shared building blocks come from `src/styles/`:
- `CommonStyles.js` → `container`, `fullWidth`, `alignCenter`, `rowContainer`, `checkbox`, `checkboxSelected`, `errorText`.
- `Colors.js`, `Dimensions.js` → used by `signup/styles.js` (`Colors.black`, `Dimensions.normalMargin`).

### Theme 2 color tokens
| Token | Hex | Used for |
|---|---|---|
| Gradient stop 1 | `#b61737` | bright maroon (left) |
| Gradient stop 2 / primary accent | `#8b1c3c` | buttons, labels, Login/Signup bg |
| Gradient stop 3 / status bar | `#661e3c` | status bar, signup accent |
| Gradient stop 4 | `#401b3a` | mid purple |
| Gradient stop 5 | `#2a1737` | deep purple (right) |
| Forgot screen accent | `#9f0000` | flat red (forgot only) |
| Surface | `#ffffff` | form sheet, button text on dark |
| Placeholder text | `#5C5C5C` | input placeholders |
| Muted text | `#969696` | "Don't have account?" |

### Signature layout pattern (Login / Signup / Forgot)
- Dark gradient fills the screen; two header texts sit top‑left (`marginStart: '10%'`, `marginTop: '20%'`).
- A **white sheet** (`formContainer`) is absolutely pinned to the bottom at 75% screen height with `borderTopStartRadius/EndRadius: 40`, pushed down by `marginTop: 'auto'`.
- Inputs are 80%‑width rows with a single `borderBottomWidth: 1` underline + right‑side icon (tick / eye).
- Primary button: 80% width, `borderRadius: 30`, accent fill, white bold 20px text.

---

## 6. State management (Redux)

Theme 2 writes exactly one piece of global state: the **accent color** that the logged‑in tab bar later reads.

`src/redux/ThemeSlice.js`
```js
const initialThemeState = { themePrimaryColor: "" }
reducers: {
  themeUpdated(state, action) {
    state.themePrimaryColor = action.payload.themePrimaryColor
  }
}
export const { themeUpdated } = themeStateSlice.actions
```

- Login2 dispatches `themeUpdated({ themePrimaryColor: "#8b1c3c" })`.
- Signup2 dispatches `themeUpdated({ themePrimaryColor: "#661e3c" })`.

Consumed in `AppNavigator.js` → `TabNavigator`:
```js
const themeState = useSelector((state) => state.themeState);
tabBarActiveTintColor: themeState.themePrimaryColor
  ? themeState.themePrimaryColor
  : Colors.primaryForegroundColor,
```
So choosing Theme 2 and signing in carries the maroon accent into the main app's bottom tab bar.

(Auth/session state lives in a separate `authState` slice, driven by `onAuthStateChanged`.)

---

## 7. Service & Firebase chain

Theme 2 screens never touch Firebase directly — they call `services/UserService.js`, which wraps `firebase/Auth.js` (the `@react-native-firebase/auth` modular API).

```
Login2Screen.onLoginPressed
  └─ UserService.loginWithEmailAndPassword(email, password)
       └─ firebase/Auth.authLoginWithEmailAndPassword
            └─ signInWithEmailAndPassword(getAuth(), email, password)

Signup2Screen.onSignupPressed
  └─ UserService.signUpWithEmailAndPassword(email, password)
       └─ firebase/Auth.authSignUpWithEmailAndPassword
            └─ createUserWithEmailAndPassword(getAuth(), email, password)
       └─ setSignupDetails(SignUpMethods.email, email, ...)   // for later profile creation

ForgotPassword2Screen.onForgotPressed
  └─ UserService.sendPasswordResetEmail(email)
       └─ firebase/Auth.authSendPasswordResetEmail
            └─ sendPasswordResetEmail(getAuth(), email)
```

`UserService` maps raw Firebase error codes to friendly strings, e.g.:
- `auth/email-already-in-use` → "This Email already exists"
- `auth/invalid-credential` → "Invalid email or password"
- `auth/user-not-found` → "No such account" / "No such email"

After a successful auth event, `AppNavigator.onAuthStateChanged` → `setupUserAfterLogin()` fetches/creates the Firestore user record and routes to **CreateProfile** (if onboarding incomplete) or the **logged‑in tab stack**.

---

## 8. Shared dependencies used by Theme 2

| Dependency | Source | Role in Theme 2 |
|---|---|---|
| `PnPStatusBar` | `components/statusBar/PnPStatusBar` | status bar color, hide app bar |
| `CActivityIndicator` | `components/activityIndicator/CActivityIndicator` | inline loading spinner |
| `LinearGradient` | `react-native-linear-gradient` | the maroon→purple background |
| `isEmailValid`, `isNullOrEmpty`, `showAlertDialog`, `openUrlInBrowser` | `helpers/HelperFunctions` | validation, alerts, links |
| `Images` | `config/Images` | `login1Logo`, `facebook`, `google`, `instagram`, `tick`, `showPassword`, `hidePassword` |
| `Constants`, `ScreenNames`, `Urls` | `config/Constants` | route names, password length, T&C url |
| `themeUpdated` | `redux/ThemeSlice` | persists accent color |
| `loginWithEmailAndPassword`, `signUpWithEmailAndPassword`, `sendPasswordResetEmail` | `services/UserService` | auth operations |

Image assets resolve to PNGs in `src/assets/` (e.g. `src/assets/login1Logo.png`, `tick.png`, `showPassword.png`, `hidePassword.png`, `facebook.png`, `google.png`, `instagram.png`).

---

## 9. Dependency map (one glance)

```
ChoiceScreen ──"Theme 2"──► Landing2Screen ──► Login2Screen ─┬─► Forgot2Screen
                                  └─► Signup2Screen ◄─────────┘
        │                 │                │                 │
        ▼                 ▼                ▼                 ▼
   styles.js (per screen)  PnPStatusBar / LinearGradient / CActivityIndicator
        │                 │
        ▼                 ▼
   HelperFunctions     UserService ──► firebase/Auth ──► @react-native-firebase/auth
        │                 │
        ▼                 ▼
   config/* (Constants, Images)   redux/ThemeSlice ──► AppNavigator TabNavigator accent
```

---

## 10. To run / view Theme 2 live

Working build copy lives at `C:\fak` (short path, used to dodge the Windows 260‑char limit). The app is already installed on emulator `emulator-5554`.

1. Start Metro: from `C:\fak` → `npx react-native start`
2. `adb reverse tcp:8081 tcp:8081`
3. Launch: `adb shell monkey -p com.geekyhawks.pnp.rn -c android.intent.category.LAUNCHER 1`
4. In‑app: complete the intro → **Choose Theme** → tap **Theme 2** → you land on `Landing2Screen`.

> **Firebase caveat:** the repo ships a *placeholder* `google-services.json`. The Theme 2 UI renders and validates fully, but the actual sign‑in / sign‑up / reset calls will fail until a real `google-services.json` (Firebase Console, app `com.geekyhawks.pnp.rn`) is dropped into `android/app/`.

---

## 11. File index (paths in original project)

| File | Lines | Responsibility |
|---|---|---|
| `src/screens/choice/ChoiceScreen.js` | `openLogin2`, button @ L93‑97 | Theme 2 entry button |
| `src/screens/login2/landing/Landing2Screen.js` | 93 | SIGN IN / SIGN UP choice |
| `src/screens/login2/landing/styles.js` | 72 | landing styling (`#9f0000` base) |
| `src/screens/login2/login/Login2Screen.js` | 187 | email/password sign in |
| `src/screens/login2/login/styles.js` | 113 | login styling (`#8b1c3c`) |
| `src/screens/login2/signup/Signup2Screen.js` | 248 | registration + terms |
| `src/screens/login2/signup/styles.js` | 133 | signup styling + checkbox |
| `src/screens/login2/forgot/ForgotPassword2Screen.js` | 136 | password reset |
| `src/screens/login2/forgot/styles.js` | 112 | forgot styling (`#9f0000`) |
| `src/navigators/AppNavigator.js` | L108‑118 | route registration |
| `src/config/Constants.js` | L8‑11 | route name constants |
| `src/redux/ThemeSlice.js` | 21 | accent‑color state |
| `src/services/UserService.js` | L11‑40, L170‑182 | auth operations |
| `src/firebase/Auth.js` | 86 | Firebase auth wrappers |
