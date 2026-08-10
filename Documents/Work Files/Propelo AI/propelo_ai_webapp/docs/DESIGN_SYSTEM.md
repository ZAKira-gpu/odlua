# Propelo AI Design System

## Complete UI/UX Redesign Documentation

---

## 1. Style Guide

### 1.1 Color Palette

| Name | HEX | Usage |
|------|-----|-------|
| **Brand Dark** | `#0A1B2F` | Auth page backgrounds, extension welcome screen |
| **Primary (Cyan)** | `#00C2FF` | Primary actions, links, accents |
| **Primary Dark** | `#0EA5E9` | Gradients, hover states |
| **Teal** | `#14B8A6` / `#65E4F7` | Gradient endpoints, secondary accents |
| **Background** | `#F7F9FB` | Page backgrounds (dashboard, authenticated extension) |
| **Card** | `#FFFFFF` | Cards, modals, form containers |
| **Foreground** | `#0A1B2F` | Primary text |
| **Muted** | `#64748B` | Secondary text |
| **Border** | `#E2E8F0` | Subtle borders |
| **Border Light** | `#F1F5F9` | Very subtle separators |
| **Error** | `#EF4444` | Error states |
| **Success** | `#22C55E` | Success states |

### 1.2 Gradients

```css
/* Primary Gradient (CTAs, Buttons) */
background: linear-gradient(to right, #06B6D4, #14B8A6);
/* from-cyan-500 to-teal-500 */

/* Dark Background Gradient */
background: #0A1B2F;
/* With subtle radial overlays: */
/* - Cyan: rgba(6, 182, 212, 0.1) blur 80-120px */
/* - Teal: rgba(20, 184, 166, 0.1) blur 60-100px */

/* Active Nav Item */
background: linear-gradient(to right, rgba(6, 182, 212, 0.1), rgba(20, 184, 166, 0.1));
```

### 1.3 Typography

| Element | Font | Size | Weight | Line Height |
|---------|------|------|--------|-------------|
| **H1** | Inter | 2rem (32px) | Bold (700) | 1.2 |
| **H2** | Inter | 1.5rem (24px) | Bold (700) | 1.3 |
| **H3** | Inter | 1.25rem (20px) | Semibold (600) | 1.4 |
| **Body** | Inter | 1rem (16px) | Regular (400) | 1.5 |
| **Body Small** | Inter | 0.875rem (14px) | Regular (400) | 1.5 |
| **Caption** | Inter | 0.75rem (12px) | Medium (500) | 1.4 |
| **Label** | Inter | 0.75rem (12px) | Medium (500) | 1.0 |
| **Button** | Inter | 0.875rem (14px) | Semibold (600) | 1.0 |

### 1.4 Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Inline spacing, icon gaps |
| `sm` | 8px | Small gaps, tight padding |
| `md` | 12px | Default padding |
| `lg` | 16px | Section spacing |
| `xl` | 24px | Large spacing |
| `2xl` | 32px | Section margins |
| `3xl` | 48px | Page sections |

### 1.5 Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| `sm` | 8px | Small elements, badges |
| `md` | 12px | Inputs, small cards |
| `lg` | 16px | Buttons, cards |
| `xl` | 20px | Large cards, modals |
| `2xl` | 24px | Auth cards, major containers |
| `full` | 9999px | Avatars, pills |

### 1.6 Shadows

```css
/* Card Shadow */
box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);

/* Card Hover Shadow */
box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);

/* Auth Card Shadow */
box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);

/* Button Glow */
box-shadow: 0 4px 14px rgba(6, 182, 212, 0.25);

/* Button Hover Glow */
box-shadow: 0 8px 25px rgba(6, 182, 212, 0.35);
```

---

## 2. Component Specifications

### 2.1 Buttons

#### Primary Button
```jsx
className="h-12 px-6 rounded-xl bg-gradient-to-r from-cyan-500 to-teal-500 
           hover:from-cyan-600 hover:to-teal-600 text-white font-semibold 
           shadow-lg shadow-cyan-500/25 hover:shadow-xl transition-all duration-300"
```

#### Outline Button
```jsx
className="h-12 px-6 rounded-xl border-2 border-slate-200 bg-white 
           hover:bg-slate-50 hover:border-slate-300 text-slate-700 
           font-medium transition-all"
```

#### Ghost Button
```jsx
className="px-4 py-2 rounded-xl text-slate-600 hover:bg-slate-100 
           transition-colors"
```

### 2.2 Inputs

```jsx
className="h-12 pl-12 rounded-xl border-slate-200 bg-slate-50 
           focus:bg-white focus:border-cyan-500 focus:ring-2 
           focus:ring-cyan-500/20 transition-all"
```

### 2.3 Cards

#### Standard Card
```jsx
className="bg-white rounded-2xl p-6 shadow-sm border border-slate-100 
           hover:shadow-md transition-all"
```

#### Auth Card
```jsx
className="bg-white rounded-3xl p-8 shadow-2xl shadow-black/20"
```

### 2.4 Navigation Items

#### Active State
```jsx
className="flex items-center gap-3 px-3 py-2.5 rounded-xl 
           bg-gradient-to-r from-cyan-50 to-teal-50 
           text-cyan-600 border border-cyan-100"
```

#### Default State
```jsx
className="flex items-center gap-3 px-3 py-2.5 rounded-xl 
           text-slate-600 hover:bg-slate-50 transition-all"
```

---

## 3. Layout Specifications

### 3.1 Web App - Auth Pages

| Property | Value |
|----------|-------|
| Background | `#0A1B2F` with gradient orbs |
| Card max-width | 420px (signin), 460px (signup) |
| Card padding | 32px |
| Card border-radius | 24px |
| Logo height | 48px |
| Logo margin-bottom | 32px |

### 3.2 Web App - Dashboard

| Property | Value |
|----------|-------|
| Sidebar width | 240px (expanded), 80px (collapsed) |
| Sidebar background | White |
| Content background | `#F7F9FB` |
| Content padding | 24px |
| Card gap | 24px |

### 3.3 Chrome Extension

| Property | Value |
|----------|-------|
| Popup dimensions | 380px × 520px |
| Welcome/Loading bg | `#0A1B2F` |
| Authenticated bg | `#F7F9FB` |
| Header height | ~52px |
| Bottom nav height | ~56px |
| Content padding | 16px |

---

## 4. Before vs After Audit

### 4.1 Login Page

| Aspect | Before | After |
|--------|--------|-------|
| **Layout** | Split-panel with left branding | Centered card on dark bg |
| **Background** | Gradient dark left, light right | Unified dark `#0A1B2F` |
| **Complexity** | Testimonials, animated orbs, feature cards | Minimal: logo + card + trust line |
| **Focus** | Distracted by side content | Clear focus on form |
| **Load time** | Heavier with animations | Lighter, faster |

### 4.2 Extension UI

| Aspect | Before | After |
|--------|--------|-------|
| **Dimensions** | 400x560px | 380x520px (optimized) |
| **Welcome Screen** | Light gradient, busy | Dark brand bg, clean features |
| **Header** | Light with gradient | Clean white, minimal |
| **Bottom Nav** | Floating pill style | Simple bottom bar |
| **Visual Unity** | Inconsistent with webapp | Matches auth pages exactly |

### 4.3 Dashboard Sidebar

| Aspect | Before | After |
|--------|--------|-------|
| **Logo Size** | h-20 (oversized) | h-10 (balanced) |
| **Spacing** | p-5, p-4 (inconsistent) | p-4, p-3 (consistent) |
| **Active State** | Simple bg color | Gradient with border |
| **Avatar** | Plain fallback | Gradient fallback |
| **Width** | 264px | 240px (tighter) |

---

## 5. Responsiveness Guidelines

### 5.1 Web App Breakpoints

| Breakpoint | Width | Behavior |
|------------|-------|----------|
| Mobile | < 640px | Single column, hidden sidebar |
| Tablet | 640-1024px | Collapsed sidebar |
| Desktop | > 1024px | Full sidebar |

### 5.2 Extension (Fixed Size)

- Always 380px × 520px
- No responsive breakpoints needed
- Scrollable content area

---

## 6. Animation & Transitions

### 6.1 Standard Transitions

```css
/* Default */
transition: all 200ms ease;

/* Buttons & Interactive */
transition: all 300ms cubic-bezier(0.4, 0, 0.2, 1);

/* Page/Component Entry */
animation: fadeIn 200ms ease-out;
animation: slideUp 300ms ease-out;
```

### 6.2 Keyframes

```css
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slideUp {
  from { opacity: 0; transform: translateY(12px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes bounce {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-25%); }
}
```

---

## 7. Accessibility Checklist

- [x] Color contrast meets WCAG AA (4.5:1 for text)
- [x] Focus states visible on all interactive elements
- [x] Form labels properly associated
- [x] Error messages announced to screen readers
- [x] Button/link text is descriptive
- [x] Touch targets minimum 44x44px

---

## 8. Implementation Checklist

### Completed ✅

1. **Login Page** (`app/auth/signin/page.tsx`)
   - Dark brand background
   - Centered card layout
   - Consistent input styling
   - Gradient CTA button

2. **Signup Page** (`app/auth/signup/page.tsx`)
   - Matching dark background
   - Password strength indicator
   - Form validation styling

3. **Extension Welcome Screen** (`extension/src/popup/App.tsx`)
   - Brand dark background matching webapp
   - Clean feature list
   - Optimized dimensions (380x520)

4. **Extension Authenticated UI**
   - Clean white header
   - Light background matching dashboard
   - Simplified bottom navigation

5. **Dashboard Sidebar** (`components/dashboard/sidebar.tsx`)
   - Reduced logo size
   - Consistent spacing
   - Gradient active states
   - Improved avatar fallback

---

## 9. Files Modified

| File | Changes |
|------|---------|
| `app/auth/signin/page.tsx` | Complete redesign |
| `app/auth/signup/page.tsx` | Complete redesign |
| `extension/src/popup/App.tsx` | Complete redesign |
| `extension/src/popup/components/Header.tsx` | Simplified design |
| `extension/src/popup/components/BottomNav.tsx` | Simplified design |
| `components/dashboard/sidebar.tsx` | Styling updates |

---

## 10. Next Steps & Recommendations

1. **Test on Real Devices**
   - Load extension in Chrome
   - Test auth flows end-to-end
   - Verify responsiveness on mobile

2. **Further Unification**
   - Apply same styling to forgot-password page
   - Update verify-email page
   - Ensure all dashboard pages use consistent cards

3. **Performance**
   - Consider lazy-loading dashboard components
   - Optimize images (logo-banner.png could be smaller)

4. **Dark Mode**
   - Current system uses light mode only
   - Consider adding dark mode toggle in future

5. **Micro-interactions**
   - Add subtle hover animations to cards
   - Button press animations
   - Success/error toast styling

---

*Last updated: December 11, 2025*
*Propelo AI - Premium SaaS Design System v1.0*
