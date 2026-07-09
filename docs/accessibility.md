# Accessibility reference (macOS, VoiceOver-first)

A single, developer-focused reference for building a native macOS NAS admin client that is accessible to VoiceOver first. It covers the SwiftUI accessibility API, the AppKit `NSAccessibility` layer you drop to when SwiftUI falls short, how real VoiceOver users drive and test the app, and the bridging pitfalls where the two frameworks meet. Snippets are copy-pasteable; strings outside SwiftUI `Text` are wrapped in `String(localized:)` per project rules.

## Table of contents
1. [SwiftUI accessibility](#swiftui-accessibility)
2. [AppKit accessibility](#appkit-accessibility)
3. [VoiceOver behaviors and testing](#voiceover-behaviors-and-testing)
4. [Bridging SwiftUI and AppKit, and pitfalls](#bridging-swiftui-and-appkit-and-pitfalls)
5. [Quick recipes](#quick-recipes)
6. [Sources](#sources)

---

## SwiftUI accessibility

SwiftUI presents one cross-platform API that lowers to `NSAccessibility` roles on macOS (vs `UIAccessibility` on iOS). Touch-only concepts (Magic Tap, two-finger scrub, the rotate-gesture rotor, `.isTabBar`) have no macOS gesture; the VoiceOver *rotor* and *actions menu* are reached by keyboard/trackpad (VO-U, VO-Command-Space) instead. Modifiers below are macOS 12+ unless noted; the priority/`isToggle` bits need macOS 14+.

### Labels, hints, values

- **`accessibilityLabel`** — short name VoiceOver speaks (overrides inferred text).
- **`accessibilityHint`** — secondary phrase describing the *result* of acting, spoken after a pause. On macOS, hints only speak if the user enabled them in VoiceOver Utility (off by default).
- **`accessibilityValue`** — current value of an element whose label stays constant.

```swift
Image(systemName: "trash")
    .accessibilityLabel("Supprimer le partage") // auto-localizes in a Text/LocalizedStringKey context

Button("Redémarrer") { restart() }
    .accessibilityHint("Redémarre le NAS immédiatement")

Slider(value: $ratio, in: 0...1)
    .accessibilityLabel("Quota")
    .accessibilityValue("\(Int(ratio * 100)) pour cent")
```

### Traits

`accessibilityAddTraits` / `accessibilityRemoveTraits` attach or strip semantic roles/state so VoiceOver announces "en-tête", "bouton", "sélectionné", etc. SwiftUI is state-driven, so compute the set inline. Common: `.isHeader`, `.isButton`, `.isSelected`, `.isLink`, `.isImage`, `.isModal`, `.isToggle` (macOS 14+), `.isSummaryElement`, `.updatesFrequently`, `.playsSound`, `.startsMediaSession`, `.allowsDirectInteraction`. `.isTabBar` is iOS-only.

```swift
Text("Volumes").accessibilityAddTraits(.isHeader)

Text(share.name)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
```

### Grouping and hiding

- **`accessibilityElement(children:)`** — turn a container into one focus stop: `.ignore` (default; you supply the label), `.combine` (merge children into one element), `.contain` (keep children as a navigable group).
- **`accessibilityHidden(true)`** — remove a decorative/redundant element from the tree.

```swift
VStack(alignment: .leading) { Text(share.name); Text(share.path) }
    .accessibilityElement(children: .combine)   // one swipe stop reading both lines

Image("logo").accessibilityHidden(true)
```

### Focus: `@AccessibilityFocusState`

Read where VoiceOver focus is, and move it programmatically — the core of the "reposition focus on every screen change" rule. Bind with `.accessibilityFocused($flag)` (Bool) or `.accessibilityFocused($enumState, equals: value)`.

```swift
enum Field { case host, password }
@AccessibilityFocusState private var focus: Field?

var body: some View {
    VStack {
        TextField("Adresse du NAS", text: $host)
            .accessibilityFocused($focus, equals: .host)
        SecureField("Mot de passe", text: $password)
            .accessibilityFocused($focus, equals: .password)
    }
    .onAppear { focus = .host }                                  // land focus on entry
    .onChange(of: loginError) { if $0 != nil { focus = .password } }
}
```

### Announcements: `AccessibilityNotification`

Push spoken/behavioral events imperatively; call `.post()` from `async` code or `onChange`.

- **`.Announcement(_:)`** — speak a transient message (loading finished, error). Most reliable when your app is frontmost.
- **`.ScreenChanged(_:)`** — major view swapped in; iOS-first, on macOS it mainly resets/moves the VO cursor.
- **`.LayoutChanged(_:)`** — part of the current view changed; often the more meaningful one on macOS.
- **`.PageScrolled(_:)`** — announce a paging scroll position.

```swift
AccessibilityNotification.Announcement(String(localized: "Connexion réussie")).post()

// macOS 14+ priority variant (queue vs. interrupt) via AttributedString:
var msg = AttributedString(String(localized: "Chargement des volumes…"))
msg.accessibilitySpeechAnnouncementPriority = .low   // .default / .high
AccessibilityNotification.Announcement(msg).post()
```

### Custom actions

`accessibilityAction` adds one action (default, named, `.escape`, or the iOS-only `.magicTap`); `accessibilityActions` groups several. On macOS these surface in the VO actions menu (VO-Command-Space) — there is no swipe gesture.

```swift
row
  .accessibilityAction(named: "Démonter") { unmount(share) }
  .accessibilityActions {
      Button("Renommer") { rename(share) }
      Button("Supprimer") { delete(share) }
  }
```

### Custom content

Attach extra labeled detail VoiceOver reveals on demand instead of reading every time; `importance: .high` forces immediate speech, `.default` defers to the "More Content" rotor. Reuse keys via `AccessibilityCustomContentKey`.

```swift
extension AccessibilityCustomContentKey { static let used = AccessibilityCustomContentKey("Espace utilisé") }

volumeRow
  .accessibilityElement(children: .ignore)
  .accessibilityLabel(volume.name)
  .accessibilityCustomContent(.used, volume.usedString, importance: .high)
  .accessibilityCustomContent("Système de fichiers", volume.fsType)   // deferred by default
```

### Custom rotor

Define a rotor so users jump straight to a subset of elements (e.g. only volumes with errors). On macOS open the rotor with VO-U, then arrow keys pick the custom entry. Tag targets with `accessibilityRotorEntry(id:in:)`; drive scrolling from the entry closure.

```swift
@Namespace private var ns

List {
    ForEach(volumes) { v in
        VolumeRow(v).accessibilityRotorEntry(id: v.id, in: ns).id(v.id)
    }
}
.accessibilityRotor("Volumes en erreur") {
    ForEach(volumes) { v in
        if v.hasError {
            AccessibilityRotorEntry(v.name, v.id, in: ns) { proxy.scrollTo(v.id) }
        }
    }
}
// Convenience form for a simple list:
.accessibilityRotor("Tous les volumes", entries: volumes, entryLabel: \.name)
```

### Traversal order, representation, synthetic children

- **`accessibilitySortPriority`** — override traversal order within a container (higher value visited first; default 0).
- **`accessibilityRepresentation`** — borrow the entire a11y behavior of a standard control for a custom-drawn view; the proxy is never rendered, only used to build the tree.
- **`accessibilityChildren`** — give a single opaque view (a `Shape`, a `Canvas` chart) synthetic child elements to navigate *without* replacing the parent (unlike `accessibilityRepresentation`, which replaces the whole subtree).

```swift
Image(systemName: isOn ? "checkmark.square.fill" : "square")
    .onTapGesture { isOn.toggle() }
    .accessibilityRepresentation { Toggle(isOn: $isOn) { Text("Notifications par e-mail") } }

BarChartShape(dataPoints: points)
    .fill(.blue)
    .accessibilityLabel("Trafic réseau")
    .accessibilityChildren {
        HStack(alignment: .bottom) {
            ForEach(points) { p in
                RoundedRectangle(cornerRadius: 4)
                    .accessibilityLabel(p.label)
                    .accessibilityValue(Text(p.value.formatted()))
            }
        }
    }
```

---

## AppKit accessibility

AppKit exposes accessibility through the informal **`NSAccessibility` protocol** (`NSAccessibilityProtocol` in Swift). Every `NSView`, `NSControl`, `NSWindow`, and `NSCell` conforms and ships sensible defaults, so most work is *overriding* or *setting* individual properties. The property-based API is current (macOS 10.10+); the old string-key API (`accessibilityAttributeValue(_:)`) is legacy. Because conformance is informal, you can implement any member on an `NSView` subclass without declaring the protocol — the client discovers it at runtime. Adopting a *role-based* protocol (e.g. `NSAccessibilityButton`) is still recommended: it warns on missing methods and lets role / `isAccessibilityElement` be inferred.

Coordinates/threading: `accessibilityFrame` is in **screen coordinates with a bottom-left origin** (Cocoa convention). All members are called on the main thread.

### Core properties

Each has a paired getter/`set…` method; assign the property or call the setter.

- **`accessibilityLabel`** — short, localized human name. What VoiceOver speaks to identify the element. No control-type suffix ("Ajouter", not "Bouton Ajouter"), start capitalized, no trailing period.
- **`accessibilityRole`** — an `NSAccessibilityRole` (`.button`, `.staticText`, `.slider`…) telling VoiceOver *what kind* of thing this is. `accessibilityRoleDescription` gives a custom human phrase for unusual uses.
- **`accessibilityValue`** — the changing state VoiceOver reads after the label.
- **`accessibilityHelp`** — tooltip-like context describing the *result* of using the control. Only when the label isn't self-explanatory.

```swift
let button = NSButton()
button.setAccessibilityRole(.button)
button.setAccessibilityLabel(String(localized: "Redémarrer"))
button.setAccessibilityValue(nil)                          // buttons have no value
button.setAccessibilityHelp(String(localized: "Redémarre le NAS"))
```

### Element vs. container, tree, frame

- **`isAccessibilityElement`** — whether the VoiceOver cursor stops here or skips through to children. Plain `NSView` defaults to `false` (container); controls default to `true`. Set `false` on grouping/background views.
- **`accessibilityChildren` / `accessibilityParent`** — the tree VoiceOver navigates; AppKit derives it from the view hierarchy, override when one view draws several focusable things. `accessibilityAddChildElement(_:)` appends a child *and* sets its parent.
- **`accessibilityFrame`** — screen-coordinate rectangle for the focus ring and trackpad hit-testing. For `NSAccessibilityElement` subclasses set `accessibilityFrameInParentSpace` instead, so the element tracks its superview.

```swift
containerView.isAccessibilityElement = false   // skip the wrapper, expose its children
override func accessibilityChildren() -> [Any]? { badgeElements }
```

### Gesture-to-method map (verified)

- **VO-Space** (Control-Option-Space) — performs the default action → **`accessibilityPerformPress() -> Bool`** (`NSAccessibilityPressAction`). Return `true` if handled.
- **VO-Shift-M** — opens the shortcut/context menu → **`accessibilityPerformShowMenu() -> Bool`** (`NSAccessibilityShowMenuAction`). This is a *different* code path from mouse `menu(for:)` — see the pitfall in the bridging section.
- **Actions rotor** — lists and runs **`NSAccessibilityCustomAction`** items from `accessibilityCustomActions`.
- **Custom rotor** — selecting it and swiping down/up navigates **`NSAccessibilityCustomRotor`** results via the search delegate's `.next` / `.previous`.

```swift
override func accessibilityPerformPress() -> Bool { toggleFolder(); return true }
```

### `NSAccessibilityCustomAction` — the Actions rotor

A named, discoverable extra action on one element (Delete, Rename, Share). Create with `init(name:handler:)` (`() -> Bool`) or target/selector, then assign the array to `accessibilityCustomActions`.

```swift
let rename = NSAccessibilityCustomAction(name: String(localized: "Renommer")) { [weak self] in
    self?.beginRename(); return true
}
let delete = NSAccessibilityCustomAction(name: String(localized: "Supprimer")) { [weak self] in
    self?.deleteItem(); return true
}
rowElement.accessibilityCustomActions = [rename, delete]
```

### `NSAccessibilityCustomRotor`

A custom rotor entry that jumps between related elements scattered across the UI (e.g. "error rows"). Construct with `init(label:itemSearchDelegate:)` (or `init(rotorType:itemSearchDelegate:)`), expose via `accessibilityCustomRotors`. The delegate implements `rotor(_:resultFor:) -> ItemResult?`; `SearchParameters` carries `currentItem` and `searchDirection` (`.previous` / `.next`).

```swift
final class ErrorRotorDelegate: NSObject, NSAccessibilityCustomRotorItemSearchDelegate {
    let errorRows: [NSAccessibilityElement]
    init(rows: [NSAccessibilityElement]) { errorRows = rows }

    func rotor(_ rotor: NSAccessibilityCustomRotor,
               resultFor p: NSAccessibilityCustomRotor.SearchParameters)
    -> NSAccessibilityCustomRotor.ItemResult? {
        let current = p.currentItem?.targetElement as? NSAccessibilityElement
        let idx = current.flatMap { errorRows.firstIndex(of: $0) }
        let next = (p.searchDirection == .next)
            ? (idx.map { $0 + 1 } ?? 0)
            : (idx.map { $0 - 1 } ?? errorRows.count - 1)
        guard errorRows.indices.contains(next) else { return nil }
        return NSAccessibilityCustomRotor.ItemResult(targetElement: errorRows[next])
    }
}

let rotor = NSAccessibilityCustomRotor(label: String(localized: "Erreurs"),
                                       itemSearchDelegate: delegate)
view.accessibilityCustomRotors = [rotor]
```

### Subclassing `NSAccessibilityElement`

When focusable content has **no backing `NSView`** (one view draws many pieces — a canvas of icons, custom-drawn cells), create one element per piece and return them from the parent's `accessibilityChildren`. Use `accessibilityElementWithRole(_:frame:label:parent:)`, or subclass to add behavior. Set `accessibilityFrameInParentSpace` so it follows the parent; gate writable properties through `isAccessibilitySelectorAllowed(_:)`.

```swift
final class IconElement: NSAccessibilityElement {
    override func accessibilityPerformPress() -> Bool { open(); return true }
}

let icon = IconElement()
icon.accessibilityRole = .button
icon.setAccessibilityLabel(fileName)
icon.accessibilityParent = self
icon.accessibilityFrameInParentSpace = iconRect   // tracks the superview
accessibilityAddChildElement(icon)
```

### `NSTableView` and `NSOutlineView`

Both are already accessible; you mainly enrich labels and expose the right structure. Roles VoiceOver expects:

- The table has role **`.table`** (`NSAccessibilityTable`); an outline has **`.outline`** (`NSAccessibilityOutline`).
- Each row is role **`.row`** (`NSAccessibilityRow`); VoiceOver announces "row 3 of 12".
- Inside a row, cells carry role **`.cell`** (cell-based tables) or, for view-based tables, the cell view's own controls (`.staticText`, `.button`…) are the elements.
- An expandable outline row exposes a **`.disclosureTriangle`**; VoiceOver reads its expanded/collapsed state and toggles the branch via `accessibilityPerformPress()`. `accessibilityDisclosureLevel` gives indentation depth.

For **view-based** tables (the modern default), set accessibility on the cell view's subviews — that is what VoiceOver actually reads — rather than fighting the row/cell protocols. See the [Quick recipes](#quick-recipes). For a fully custom (non-`NSView`) grid, adopt `NSAccessibilityTable` / `NSAccessibilityRow` and return `accessibilityRows()`, `accessibilityColumns()`, `accessibilitySelectedRows()`.

---

## VoiceOver behaviors and testing

VoiceOver maintains its own cursor that moves independently of, but can sync to, keyboard focus. You don't call VoiceOver APIs directly on macOS — you annotate views with labels, values, traits, and actions, and VoiceOver reads the resulting accessibility tree. Below is what a blind user actually does, and what your code must satisfy.

### The VO modifier

Most commands are prefixed by **VO = Control-Option** (Caps Lock is an optional alternative). "VO-Space" = Control-Option-Space. Users often engage **VO-; (semicolon)** to lock the modifier on. Toggle VoiceOver with **Command-F5**. Function-key commands usually also need Fn.

### Key commands to design for

- **VO-Left/Right/Up/Down Arrow** — moves the cursor element by element. Needs a sensible reading order; hide decorative/duplicate elements with `.accessibilityHidden(true)`.
- **VO-Space** — performs the default action (click, toggle, activate, expand). Any custom control must expose a default action (a `Button`, `.accessibilityAction {}`, or the `.isButton` trait), or VO-Space does nothing.
- **VO-Shift-M** — opens the contextual/shortcut menu (right-click equivalent). SwiftUI `.contextMenu` is exposed automatically; hand-rolled AppKit menus are not (see pitfalls).
- **VO-U (rotor)** — a filtered index of the current context (Headings, Links, Form Controls, Landmarks, Tables, custom rotors). Depends on correct traits and any custom rotors you define. The **Item Chooser (VO-I)** is a searchable list of everything on screen.
- **VO-Command-Space (actions rotor / Actions menu)** — the menu of *custom* actions on the focused element; the macOS surface for `.accessibilityAction(named:)` / `.accessibilityActions {}`. Use it to collapse per-row buttons into named actions. Adding these gives the element the `.isButton` trait. (`.accessibilityAdjustableAction` handles increment/decrement, driven by VO-Up/Down.)
- **VO-Shift-Down / VO-Shift-Up Arrow** — "interact with" / "stop interacting with" a group, scroll area, table, or nested container. `.accessibilityElement(children:)` grouping affects how deep the user must drill.
- **Reading/control**: **Control** alone pauses/resumes speech; **VO-A** reads from the cursor; **VO-Shift-N** reads the hint; **VO-Q / VO-Shift-Q** toggle Quick Nav (arrow-only navigation).

### Announcements: queued vs. interrupted, without spamming

For state changes with no visible focus move (loading finished, error appeared, background upload completed), post `AccessibilityNotification.Announcement("…").post()`. Since macOS 14 you control ordering by setting `accessibilitySpeechAnnouncementPriority` on an `AttributedString`:

- **`.high`** — interrupts current speech and cannot itself be interrupted. Reserve for critical, task-blocking errors.
- **default** (no priority) — interrupts current speech but yields to a newer utterance.
- **`.low`** — queued; spoken after current speech, dropped if superseded. Use for non-urgent progress/status.

Best practices:

- Prefer *moving focus* over announcing — if focus lands on new content, VoiceOver reads it automatically and a separate announcement would talk over it.
- Don't fire on every incremental update (per-percent progress). Debounce; announce milestones (started, failed, done).
- Use `.low` for non-urgent messages; save `.high` for rare interrupt-worthy events. Multiple default-priority posts clobber each other.
- Announcements posted immediately after a view appears can be dropped; a short delay before posting is the standard workaround. Keep strings in `String(localized:)`.

### Focus management expectations

VoiceOver users rely on focus landing predictably on every screen/context change; a silent reset to the top leaves them lost.

- **New screen / navigation push**: move focus to the logical start (title/header).
- **Sheet / dialog / popover opens**: move focus into the presented content; focus is otherwise generally trapped there until dismissed.
- **Dismissal**: return focus to the control that triggered the presentation.
- **Validation errors / async results**: move focus to the first error or the newly loaded content.

Drive this with `@AccessibilityFocusState` + `.accessibilityFocused(_:equals:)`; SwiftUI writes the state back to `nil` when the user moves focus themselves. See the [Quick recipes](#quick-recipes).

### Testing

Two layers, and the manual one is non-negotiable.

**1. Real VoiceOver.** Turn it on (Command-F5) and drive the app with only the keyboard. Verify: every element reachable by VO-arrow in a sensible order; every control announces a meaningful label, role/trait, value, and (where useful) hint; VO-Space activates what it should; custom actions appear under VO-Command-Space; nothing is silent (no mute spinners/errors); focus lands correctly on each screen/context change; announcements fire once, at the right priority, without talking over the user. Automated audits can't judge the *experience*.

**2. Accessibility Inspector** (Xcode → Open Developer Tool), pointed at your running Mac app:
- **Inspector tab** — select any element to see its computed label, value, traits, hint; step through elements. Catches missing/wrong labels fast.
- **Audit tab** — **Run Audit** statically flags issues on the current screen (element descriptions, hit-region size, contrast, element detection, parent/child relationships, actions). A floor, not a certificate — it won't catch bad focus order.
- **Settings tab** — toggle conditions (increased contrast, reduce motion, larger text) live.

**3. Automated audits in UI tests.** `XCUIApplication.performAccessibilityAudit()` runs the same engine inside XCTest and fails on issues; scope with `performAccessibilityAudit(for:)` (e.g. `.contrast`) and catch the thrown error to filter. Wire into key flows in CI so a new unlabeled control or contrast drop fails the build. Apple is explicit that audits do **not** substitute for real VoiceOver testing.

---

## Bridging SwiftUI and AppKit, and pitfalls

### One accessibility tree, two frameworks

VoiceOver never sees your views — it sees the **Accessibility Tree**, a parallel hierarchy in reading order with decorative views pruned. SwiftUI derives it declaratively; AppKit generates it from the drawn `NSView` hierarchy plus your overrides. When you mix them, a SwiftUI subtree can be the *parent* of AppKit elements bridged in through `NSViewRepresentable`, so the two are stitched into one tree VoiceOver walks continuously. Each side keeps its own rules, and the seams are where bugs appear.

### Making an `NSViewRepresentable` accessible

The biggest pitfall: **SwiftUI accessibility modifiers do not propagate into the wrapped `NSView`.** `.accessibilityLabel(...)` on the representable does not set the AppKit view's label — configure it on the `NSView` itself in `makeNSView`/`updateNSView`.

```swift
struct WaveformView: NSViewRepresentable {
    func makeNSView(context: Context) -> WaveformNSView {
        let v = WaveformNSView()
        v.setAccessibilityElement(true)
        v.setAccessibilityRole(.image)                          // pick a real role
        v.setAccessibilityLabel(String(localized: "Forme d'onde"))
        return v
    }
    func updateNSView(_ v: WaveformNSView, context: Context) {
        v.setAccessibilityValue(context.coordinator.valueText)  // keep it in sync
    }
}
```

Two gotchas: a plain custom `NSView` is **not** an accessibility element by default — VoiceOver skips it until you set `isAccessibilityElement`/`setAccessibilityElement(true)` and a role. And AppKit labels are plain `String`, so wrap every label/value/help in `String(localized:)`; they won't auto-localize like SwiftUI `Text`.

### Describing a bridged view with SwiftUI semantics

If the wrapped `NSView` already has good native accessibility (e.g. a real `NSTableView`), it flows into the tree automatically — don't fight it. If it's custom-drawn and you'd rather describe it with SwiftUI, use **`.accessibilityRepresentation`**: SwiftUI renders your real (bridged) view but builds the a11y element from a throwaway standard control you supply.

```swift
WaveformView()
    .accessibilityRepresentation {
        Slider(value: $position, in: 0...duration) { Text("Position de lecture") }
    }
```

The `Slider` is never drawn — SwiftUI extracts only its label, value, traits, and adjust actions and grafts them onto the bridged view. Complement with `.accessibilityElement(children:)` and `.accessibilityActions { … }`.

### Why SwiftUI `List` is weak on macOS vs `NSTableView`

On iOS `List` is excellent; on macOS it's a frequent regression, so serious Mac apps bridge a real `NSTableView`/`NSOutlineView` for rows-of-items admin UIs:

- **Keyboard navigation is unreliable** — Tab loops and arrow-key row-to-row movement frequently don't behave like a native table (documented even in Apple's own SwiftUI apps). Disqualifying for a keyboard-and-VoiceOver-first app.
- **Selection / `contextMenu` feedback is thin** — `.contextMenu` on a row gives no selection callback or "menu applies to row N" affordance, so a VoiceOver user can lose track of which row a menu targets.
- **Rotor / row-model semantics** (row/column counts, selection as an accessibility concept, "N of M") that `NSTableView` exposes for free are not reliably surfaced by macOS `List`.

`NSTableView` ships decades-tuned VoiceOver support and Full Keyboard Access. Trade-off: once bridged, its accessibility is AppKit's job.

### Announcements from non-View code (view models)

You don't need a `View` to speak. `AccessibilityNotification.Announcement` (macOS 14+) can be posted from a `@MainActor` view model — the right place to announce "Chargement…", "3 dossiers partagés chargés", or an error. Use an `AttributedString` for priority, wrap text in `String(localized:)`, and add a small delay so the announcement isn't cut off by the triggering focus/layout change.

```swift
@MainActor
func announce(_ message: String,
              priority: AttributedString.SpeechAnnouncementPriority = .high) {
    var text = AttributedString(message)          // message already String(localized:)
    text.accessibilitySpeechAnnouncementPriority = priority
    Task {
        try? await Task.sleep(for: .milliseconds(100))
        AccessibilityNotification.Announcement(text).post()
    }
}
```

Pitfalls: posting with no delay right as the screen changes often gets swallowed; a bare `String` gives no priority control. Pre-14 AppKit fallback: `NSAccessibility.post(element: NSApp.mainWindow as Any, notification: .announcementRequested, userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])`.

### Restoring focus after in-view navigation

When content changes *within* a screen (detail pane swaps, a row is deleted, a sheet dismisses) VoiceOver does **not** move focus for you — new content appears unfocused and focus can silently jump to the top. Drive it with `@AccessibilityFocusState`; the ~0.1s delay is load-bearing because the target element may not exist in the tree yet in the same runloop tick.

```swift
enum Field: Hashable { case list, detail, title }
@AccessibilityFocusState private var focus: Field?

Text(item.name).accessibilityFocused($focus, equals: .title)

// after the navigation/state change, nudge focus:
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focus = .title }
```

Inside a bridged `NSView`, the AppKit equivalent is making the view first responder and/or posting `NSAccessibility.post(element: view, notification: .focusedUIElementChanged)`.

### The VO-Shift-M pitfall: `accessibilityPerformShowMenu()` vs a right-click-only `NSMenu`

The subtle one, right at the SwiftUI↔AppKit seam. In AppKit you expose a context menu via the view's `menu` property, `menu(for:)`, or `rightMouseDown` — all driven by a **mouse event**. VoiceOver's **VO-Shift-M** does not synthesize a mouse click; it sends the `showMenu` accessibility action, which lands in **`accessibilityPerformShowMenu()`** — a *different* code path. So a custom `NSView` that vends its menu only through `menu(for:)` shows nothing for a VoiceOver user. This is a real, recurring bug (JetBrains IJPL-130384, Mozilla bug 1625832, AppleVis reports).

The fix: override `accessibilityPerformShowMenu()` and pop up the *same* menu. There's no `NSEvent` in the accessibility path, so don't use `NSMenu.popUpContextMenu(_:with:for:)` (it wants an event) — use `popUp(positioning:at:in:)`.

```swift
final class RowNSView: NSView {
    override func menu(for event: NSEvent) -> NSMenu? { makeContextMenu() }   // mouse path

    override func accessibilityPerformShowMenu() -> Bool {                    // VoiceOver path
        guard let menu = makeContextMenu() else { return false }             // false => VO says unavailable
        let anchor = NSPoint(x: bounds.midX, y: bounds.midY)
        menu.popUp(positioning: nil, at: anchor, in: self)
        return true
    }

    private func makeContextMenu() -> NSMenu? { /* build shared NSMenu */ }
}
```

Return `true` when you actually showed a menu, `false` when there's nothing. Keep both paths sharing one `makeContextMenu()`. Broader lesson: **prefer SwiftUI's `.contextMenu`** — it wires the show-menu action automatically; the moment you hand-roll an AppKit menu, `accessibilityPerformShowMenu()` is mandatory.

### Project checklist

- Custom-drawn `NSView` in a representable: set `isAccessibilityElement`, a role, and a `String(localized:)` label/value; SwiftUI modifiers won't reach it.
- Prefer `.accessibilityRepresentation { standardControl }` to describe a bridged view.
- For rows-of-items admin screens, bridge `NSTableView`/`NSOutlineView` rather than fighting macOS `List`.
- Announce load/error from the `@MainActor` view model via `AccessibilityNotification.Announcement` with an `AttributedString` priority and a ~100 ms delay.
- Re-place focus with `@AccessibilityFocusState` (plus the small delay) on every in-screen navigation.
- Any AppKit context menu must also implement `accessibilityPerformShowMenu()`, or it's mouse-only and invisible to VoiceOver.

---

## Quick recipes

### Announce loading and error to VoiceOver

```swift
@MainActor
func announce(_ message: String,
              priority: AttributedString.SpeechAnnouncementPriority) {
    var text = AttributedString(message)                 // already String(localized:)
    text.accessibilitySpeechAnnouncementPriority = priority
    Task {
        try? await Task.sleep(for: .milliseconds(100))   // avoid being swallowed
        AccessibilityNotification.Announcement(text).post()
    }
}

announce(String(localized: "Chargement des volumes…"), priority: .low)   // non-urgent, queued
announce(String(localized: "Échec de la connexion au NAS"), priority: .high) // blocking error, interrupts
```

### Move focus on a screen change with `@AccessibilityFocusState`

```swift
enum Field: Hashable { case title, firstError }
@AccessibilityFocusState private var focus: Field?

var body: some View {
    VStack(alignment: .leading) {
        Text(screenTitle).accessibilityAddTraits(.isHeader)
            .accessibilityFocused($focus, equals: .title)
        if let error { Text(error).accessibilityFocused($focus, equals: .firstError) }
    }
    .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focus = .title } // delay is load-bearing
    }
    .onChange(of: error) { if $0 != nil { focus = .firstError } }
}
```

### Add a custom VoiceOver action

SwiftUI (surfaces under VO-Command-Space):

```swift
shareRow
  .accessibilityElement(children: .combine)
  .accessibilityLabel(share.name)
  .accessibilityAction(named: "Démonter") { unmount(share) }
  .accessibilityActions {
      Button("Renommer") { rename(share) }
      Button("Supprimer") { delete(share) }
  }
```

AppKit equivalent:

```swift
let unmount = NSAccessibilityCustomAction(name: String(localized: "Démonter")) { [weak self] in
    self?.unmount(); return true
}
rowElement.accessibilityCustomActions = [unmount]
```

### Contextual menu that also works with VO-Shift-M

```swift
final class RowNSView: NSView {
    override func menu(for event: NSEvent) -> NSMenu? { makeContextMenu() }   // right-click / Control-click

    override func accessibilityPerformShowMenu() -> Bool {                    // VO-Shift-M
        guard let menu = makeContextMenu() else { return false }
        menu.popUp(positioning: nil,
                   at: NSPoint(x: bounds.midX, y: bounds.midY),
                   in: self)                                                  // no NSEvent -> popUp, not popUpContextMenu
        return true
    }

    private func makeContextMenu() -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "Renommer"), action: #selector(rename), keyEquivalent: "")
        menu.addItem(withTitle: String(localized: "Supprimer"), action: #selector(remove), keyEquivalent: "")
        return menu
    }
}
```

### Accessible `NSTableView` cell (view-based)

```swift
func tableView(_ tableView: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
    let cell = tableView.makeView(withIdentifier: id, owner: self) as! NSTableCellView
    let item = items[row]
    cell.setAccessibilityElement(true)
    cell.setAccessibilityRole(.cell)
    cell.textField?.stringValue = item.displayName
    cell.textField?.setAccessibilityRole(.staticText)
    cell.textField?.setAccessibilityLabel(item.displayName)   // set a11y on the subviews VoiceOver reads
    return cell
}
```

---

## Sources

Apple — SwiftUI accessibility
- https://developer.apple.com/documentation/swiftui/view-accessibility
- https://developer.apple.com/documentation/swiftui/accessibilityfocusstate
- https://developer.apple.com/documentation/swiftui/accessibilitynotification
- https://developer.apple.com/documentation/swiftui/accessibilityrotorcontent
- https://developer.apple.com/documentation/swiftui/view/accessibilityrotor(_:entries:)
- https://developer.apple.com/documentation/swiftui/view/accessibilityrepresentation(representation:)
- https://developer.apple.com/documentation/swiftui/view/accessibilitychildren(children:)
- https://developer.apple.com/documentation/swiftui/list/accessibilitycustomcontent(_:_:importance:)
- https://developer.apple.com/documentation/swiftui/view/accessibilityaction(_:_:)
- https://developer.apple.com/documentation/swiftui/nsviewrepresentable
- https://developer.apple.com/documentation/accessibility/accessibilitynotification/announcement

Apple — AppKit accessibility
- https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol
- https://developer.apple.com/documentation/appkit/nsaccessibility
- https://developer.apple.com/documentation/appkit/nsaccessibility-c.protocol/accessibilitylabel
- https://developer.apple.com/documentation/appkit/nsaccessibility-c.protocol/accessibilityrole
- https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/1535339-setaccessibilityvalue
- https://developer.apple.com/documentation/appkit/nsaccessibilityrole
- https://developer.apple.com/documentation/appkit/nsaccessibilitycustomaction
- https://developer.apple.com/documentation/appkit/nsaccessibilitycustomaction/2870120-init
- https://developer.apple.com/documentation/appkit/nsaccessibilitycustomaction/handler
- https://developer.apple.com/documentation/appkit/nsaccessibilitycustomrotor
- https://developer.apple.com/documentation/appkit/nsaccessibilitycustomrotor/2876333-init
- https://developer.apple.com/documentation/appkit/nsaccessibilitycustomrotor/2876299-init
- https://developer.apple.com/documentation/appkit/nsaccessibilitycustomrotoritemsearchdelegate
- https://developer.apple.com/documentation/appkit/nsaccessibilitytable
- https://developer.apple.com/documentation/appkit/nsaccessibility-swift.struct/action/showmenu
- https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/EnhancingtheAccessibilityofStandardAppKitControls.html
- https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/ImplementingAccessibilityforCustomControls.html
- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/Articles/DisplayContextMenu.html
- https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.8.sdk/System/Library/Frameworks/AppKit.framework/Versions/C/Headers/NSAccessibility.h

Apple — testing, videos, VoiceOver guide
- https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app
- https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app
- https://developer.apple.com/videos/play/wwdc2020/10116/
- https://developer.apple.com/videos/play/wwdc2021/10119/
- https://developer.apple.com/videos/play/wwdc2023/10035/
- https://developer.apple.com/videos/play/wwdc2023/10036/
- https://developer.apple.com/videos/play/wwdc2024/10073/
- https://support.apple.com/guide/voiceover/general-commands-cpvokys01/mac
- https://support.apple.com/guide/voiceover/navigation-commands-cpvokys04/mac
- https://support.apple.com/guide/voiceover/control-your-mac-with-keyboard-commands-vo2681/mac
- https://support.apple.com/en-euro/guide/voiceover/mchlp2734/mac

Community articles and references
- https://swiftwithmajid.com/2021/09/23/accessibility-focus-in-swiftui/
- https://swiftwithmajid.com/2021/09/14/accessibility-rotors-in-swiftui/
- https://swiftwithmajid.com/2021/10/06/custom-accessibility-content-in-swiftui/
- https://swiftwithmajid.com/2021/09/01/the-power-of-accessibility-representation-view-modifier-in-swiftui/
- https://swiftwithmajid.com/2022/05/25/the-power-of-accessibilityChildren-view-modifier-in-swiftui/
- https://swiftwithmajid.com/2021/04/15/accessibility-actions-in-swiftui/
- https://www.avanderlee.com/swiftui/accessibility-uikit-developers/
- https://www.avanderlee.com/swiftui/voiceover-navigation-improvement-tips/
- https://www.createwithswift.com/accessibility-actions/
- https://www.createwithswift.com/understanding-accessibility-rotors-and-how-to-use-them/
- https://www.createwithswift.com/understanding-the-accessible-user-interface/
- https://www.createwithswift.com/making-a-view-accessible-using-the-accessibility-representation-modifier/
- https://mjtsai.com/blog/2024/04/15/nstableview-with-swiftui/
- https://github.com/cvs-health/ios-swiftui-accessibility-techniques/blob/main/iOSswiftUIa11yTechniques/Documentation/AccessibilityNotifications.md
- https://appt.org/en/docs/swiftui/samples/accessibility-announcement
- https://medium.com/@juny./implementing-voice-control-activation-with-28b236be0ab1
- https://gist.github.com/matthewreagan/fb5a2138815fddd59561
- https://dequeuniversity.com/screenreaders/voiceover-keyboard-shortcuts
- https://www.applevis.com/guides/complete-list-voiceover-keyboard-shortcuts-available-macos
- https://www.applevis.com/guides/beginners-guide-using-macos-voiceover

Known bugs (VO-Shift-M / context-menu pitfall)
- https://youtrack.jetbrains.com/issue/IJPL-130384/VoiceOver-cant-read-right-click-context-menu-on-MacOS
- https://bugzilla.mozilla.org/show_bug.cgi?id=1625832
- https://www.applevis.com/bugs/ios/show-context-menu-voiceover-rotors-action-menu-several-places-system-wide-does-nothing