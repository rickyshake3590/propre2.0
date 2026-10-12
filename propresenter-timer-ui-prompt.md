# ProPresenter Timer UI — Round 1 Prompt

## 1. Role & High-Level Task

You are a React UI engineer building a modern, polished timer display component inspired by ProPresenter. Your task is to create a static React component (no real timer logic, no click handlers) that mockups the three timer modes users will control on stage: Countdown Timer, Altar Call Timer, and Countup Timer.

---

## 2. Dynamic Spec Content

### Timer Modes (One visible at a time)

**Countdown Timer**
- Display: Large time in white text (MM:SS.cs format, e.g., 12:34.56)
- Secondary display: Current time below (e.g., 1:23 PM) in smaller, muted gray text
- Use case: Main stage countdown (event start, sermon end, etc.)
- Color: White primary text, gray secondary text
- Auto-start: No (manual start)

**Altar Call Timer**
- Display: Large time in yellow/gold text (MM:SS.cs format)
- Label: "ALTAR CALL" text above the main time
- Secondary display: Current time below (e.g., 1:23 PM) in smaller, muted gray text
- Use case: Invitation/response period at end of service
- Color: Bright yellow/gold primary text, gray secondary text
- Auto-start: Yes (indicated visually, but not functional in Round 1)

**Countup Timer**
- Display: Large time in red text (MM:SS.cs format)
- Secondary display: Current time below (e.g., 1:23 PM) in smaller, muted gray text
- Use case: Elapsed time tracking
- Color: Bright red primary text, gray secondary text
- Auto-start: Yes (indicated visually, but not functional in Round 1)

### Supporting UI Elements

**Mode Selector**
- Three buttons or tabs: "Countdown" | "Altar Call" | "Countup"
- Only one timer shows at a time; selecting a button switches which timer displays
- Selected state is visually distinct (highlight, underline, or background color change)
- Position: Above or below the main timer display (designer's choice, but must be clear)

**Small Timer (Always Visible)**
- Small countdown timer in white text, positioned bottom-right corner
- Displays MM:SS (e.g., 5:42)
- Visible alongside whichever main timer is active
- Muted size/opacity to avoid competing with main display

**Time Display Variants** (Static mockups showing optional features)
- Show one example of how text can replace time (e.g., "GO" instead of 00:00.00)
- Show one example of different text sizing in the UI settings area (optional, minimal UI)
- Show one example of custom color selection (use a simple color swatch or hex input mockup—non-functional)

---

## 3. Detailed Task Instructions

**Output Requirement:** A single React component exported as default.

**Component Structure:**
1. A container/wrapper with full height (vh) or suitable aspect ratio for on-stage display
2. Dark background (near-black or charcoal, like ProPresenter's stage background)
3. Mode selector (buttons/tabs) to switch between the three timers
4. Main timer display area (centered, large text)
5. Small secondary timer (bottom-right, always visible)
6. Optional UI mockup showing color/text/size customization (static, non-functional buttons/inputs)

**Styling Constraints:**
- Use modern CSS (inline styles, CSS-in-JS, or Tailwind—designer's choice)
- Typography: Large, bold, highly readable font (e.g., monospace or sans-serif with strong weight)
- Contrast: All text must be high-contrast against dark background
- Responsiveness: Adapt gracefully to different screen sizes (don't let text overflow)
- No animations or transitions (static mockup only)

**Content & Text:**
- Use **hardcoded example times** for each timer (Countdown: 12:34.56, Altar Call: 8:45.32, Countup: 3:21.78)
- Hardcoded current time (e.g., 1:23 PM) for the secondary display
- Mode labels: "Countdown Timer", "Altar Call", "Countup Timer"
- Auto-start indicators: Add a small badge or label (e.g., "Auto-start on") for Altar Call and Countup—do not make it functional, just indicate the feature exists

**No Functional Requirements (Static Only):**
- Buttons/tabs do not actually work on click (no state change, no timer advancing)
- Color picker, text input, size slider are visual mockups only (no onChange handlers)
- Timers do not count down or up

---

## 4. Examples

### Example 1: Countdown Mode View
```
┌─────────────────────────────────┐
│ [Countdown] [Altar Call] [Countup]│
│                                  │
│                                  │
│              12:34.56            │
│                                  │
│             1:23 PM              │
│                                  │
│                                  │
│                          5:42    │  (small timer, bottom-right)
└─────────────────────────────────┘
```

### Example 2: Altar Call Mode View
```
┌─────────────────────────────────┐
│ [Countdown] [Altar Call] [Countup]│
│                                  │
│           ALTAR CALL             │
│                                  │
│              8:45.32             │
│                                  │
│             1:23 PM              │
│                                  │
│        (Auto-start badge)        │
│                          5:42    │  (small timer, bottom-right)
└─────────────────────────────────┘
```

### Example 3: Countup Mode View
```
┌─────────────────────────────────┐
│ [Countdown] [Altar Call] [Countup]│
│                                  │
│                                  │
│              3:21.78             │
│                                  │
│             1:23 PM              │
│                                  │
│        (Auto-start badge)        │
│                          5:42    │  (small timer, bottom-right)
└─────────────────────────────────┘
```

### Example 4: Settings Mockup (Optional, Bottom or Side Panel)
```
┌─────────────────────────────────┐
│ Color: [● Yellow] [Hex Input]    │
│ Text Size: [———●————] (16px)     │
│ Display Text: "GO" (if enabled)  │
└─────────────────────────────────┘
```

---

## 5. Critical Instructions (Repeated)

**MUST DO:**
- Output a functional React component (not a description or skeleton)
- Export as default export
- Include all three timer modes, selectable via mode buttons
- Display the small timer always in the bottom-right corner
- Use hardcoded, realistic example times (not placeholder values like 00:00)
- Ensure text is readable and high-contrast on dark background
- Add visual indicators for auto-start (Altar Call and Countup only)

**MUST NOT:**
- Add working click handlers or state management for timer logic
- Make timers actually count or advance
- Include a color picker that actually changes colors
- Add animations, transitions, or keystroke responses
- Use light backgrounds or low-contrast colors
- Create a full settings panel with functional controls

**SCOPE FOR ROUND 1:**
- Static UI mockup only
- Three timer modes visible one at a time
- Mode selector that looks like it could work but is non-functional
- Settings area (optional) that shows customization options visually only

---

## 6. Anti-Hallucination Guidance

### Genuine Ambiguities Resolved

**Q: Should the time display be MM:SS.cs or just MM:SS?**
A: Use MM:SS.cs (centiseconds) to match ProPresenter's precision display in the images. Show both formats in examples.

**Q: What text replaces time in "text mode"?**
A: Use "GO" or "READY" as the example replacement. You're only showing one variant—don't enumerate all possibilities.

**Q: How large should the small timer be relative to the main timer?**
A: The small timer should be 1/4 to 1/6 the visual size of the main timer. It should not distract from the main display.

**Q: Should I include slide/timer management UI (preparing multiple timers)?**
A: No. Round 1 shows only the display component with mode selector. Slide preparation UI comes in a later round.

**Q: Can I add animations or visual feedback?**
A: No. This is a static mockup. No CSS animations, transitions, or hover effects. The component is frozen in time.

**Q: Should the color be #FFD700 or #FFFF00 for yellow?**
A: Designer's choice—either gold or bright yellow is acceptable. Pick one and be consistent. If uncertain, use #FFD700 (gold) as it matches the Altar Call imagery better.

**Q: How wide should the component be?**
A: Design for a 16:9 or 4:3 aspect ratio (typical stage display). Full width/height of a container is fine. No fixed pixel width required.

---

## 7. Acceptance Criteria

✅ Component renders without errors  
✅ All three timer modes are present and selectable (visually, not functionally)  
✅ Mode selector clearly indicates which timer is active  
✅ Small timer is visible in bottom-right, always present  
✅ Text is white, yellow, or red depending on timer mode  
✅ Secondary time display (e.g., 1:23 PM) is visible and muted  
✅ Auto-start badges appear on Altar Call and Countup modes  
✅ Example times are hardcoded and realistic  
✅ Dark background and high-contrast text  
✅ No functional click handlers or timer logic  
✅ Ready to screenshot/mockup for stakeholder review  

---

## 8. Next Steps (After Round 1 Approval)

- **Round 2:** Add functional timer logic (countdown/countup, start/pause/reset buttons)
- **Round 3:** Add settings panel with color picker, text size slider, custom text input
- **Round 4:** Add slide preparation / timer sequence management
- **Round 5:** Integrate with ProPresenter API or export format

**This round focuses on the display layer only.**
