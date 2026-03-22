# ONYX Design System - Complete Reference Guide

## Overview

ONYX is a premium enterprise security operations and intelligence command platform. The design system is built for high-density information environments while maintaining clarity, professionalism, and operational composure.

**Design Principles:**
- Premium dark enterprise aesthetic
- Calm under pressure
- Data-rich but readable
- Clear hierarchy and scan speed
- Professional, not flashy
- Authoritative and trustworthy

---

## Color System

### Base Surfaces (Deep Navy, Graphite, Near-Black Blue)

```css
--onyx-bg-base: #0a0d16;        /* Deepest background */
--onyx-bg-primary: #0d1117;     /* Main application background */
--onyx-bg-secondary: #12161f;   /* Secondary sections */
--onyx-bg-elevated: #161b26;    /* Raised surfaces (cards, panels) */
--onyx-bg-surface: #1a1f2e;     /* Interactive surfaces */
--onyx-bg-hover: #1e2432;       /* Hover states */
--onyx-bg-input: #0f1319;       /* Input fields */
```

### Borders and Dividers (Subtle, Refined)

```css
--onyx-border-subtle: #1f242e;   /* Very subtle dividers */
--onyx-border-default: #282d3a;  /* Standard borders */
--onyx-border-medium: #303847;   /* Medium emphasis borders */
--onyx-border-strong: #3a4152;   /* Strong emphasis borders */
```

### Text Hierarchy (Clear, High Contrast)

```css
--onyx-text-primary: #e8eaed;    /* Primary content */
--onyx-text-secondary: #b8bcc6;  /* Secondary content */
--onyx-text-tertiary: #8b8f9a;   /* Tertiary/metadata */
--onyx-text-disabled: #5a5e69;   /* Disabled states */
--onyx-text-placeholder: #4a4e59; /* Placeholder text */
```

### Primary Accent (Cool Blue/Cyan)

```css
--onyx-accent-primary: #3d8fff;        /* Primary accent */
--onyx-accent-primary-hover: #5ba3ff;  /* Hover state */
--onyx-accent-primary-active: #2478eb; /* Active state */
--onyx-accent-primary-subtle: #1a4573; /* Subtle accent */
--onyx-accent-primary-bg: #0d1f3a;     /* Accent background */
```

### Secondary Accent (Steel Blue)

```css
--onyx-accent-steel: #6b8aad;     /* Steel blue accent */
--onyx-accent-steel-bg: #1a2533;  /* Steel background */
```

### Semantic Status Colors

**Success (Green)**
```css
--onyx-status-success: #3dd68c;
--onyx-status-success-hover: #58dd9d;
--onyx-status-success-bg: #0d2d1f;
--onyx-status-success-border: #1a4a33;
```

**Warning (Amber)**
```css
--onyx-status-warning: #ffa726;
--onyx-status-warning-hover: #ffb74d;
--onyx-status-warning-bg: #2d2214;
--onyx-status-warning-border: #4a3820;
```

**Danger/Critical (Red)**
```css
--onyx-status-danger: #ff5252;
--onyx-status-danger-hover: #ff6b6b;
--onyx-status-danger-bg: #2d1414;
--onyx-status-danger-border: #4a2020;
```

**Intelligence (Violet)**
```css
--onyx-status-intel: #9d7df0;
--onyx-status-intel-hover: #b196f5;
--onyx-status-intel-bg: #1f1a33;
--onyx-status-intel-border: #332952;
```

**Info (Blue)**
```css
--onyx-status-info: #42a5f5;
--onyx-status-info-bg: #0d2333;
--onyx-status-info-border: #1a3d5a;
```

### Shadows (Subtle Depth)

```css
--onyx-shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.3);
--onyx-shadow-md: 0 4px 12px rgba(0, 0, 0, 0.4);
--onyx-shadow-lg: 0 8px 24px rgba(0, 0, 0, 0.5);
--onyx-shadow-xl: 0 12px 36px rgba(0, 0, 0, 0.6);
```

---

## Typography System

### Headings

```css
h1 {
  font-size: 1.875rem;  /* 30px */
  font-weight: 700;
  line-height: 1.3;
  letter-spacing: -0.02em;
}

h2 {
  font-size: 1.5rem;    /* 24px */
  font-weight: 600;
  line-height: 1.3;
  letter-spacing: -0.01em;
}

h3 {
  font-size: 1.125rem;  /* 18px */
  font-weight: 600;
  line-height: 1.4;
}

h4 {
  font-size: 1rem;      /* 16px */
  font-weight: 600;
  line-height: 1.5;
}
```

### Body Text

```css
label {
  font-size: 0.875rem;  /* 14px */
  font-weight: 500;
  line-height: 1.5;
}

button {
  font-size: 0.875rem;  /* 14px */
  font-weight: 500;
  line-height: 1.5;
}

input {
  font-size: 0.875rem;  /* 14px */
  font-weight: 400;
  line-height: 1.5;
}
```

### Font Family

```css
font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Inter', 'Helvetica Neue', Arial, sans-serif;
```

---

## Component Library

### 1. StatusChip

**Purpose:** Display status badges with semantic colors

**Variants:** `success`, `warning`, `critical`, `danger`, `intel`, `info`, `neutral`

**Sizes:** `sm`, `md`

**Usage:**
```tsx
import { StatusChip } from './components/onyx/StatusChip';

<StatusChip variant="success" size="sm">Operational</StatusChip>
<StatusChip variant="warning">3 Alerts</StatusChip>
<StatusChip variant="critical">Critical</StatusChip>
<StatusChip variant="intel">Intel</StatusChip>
```

**Props:**
- `variant`: StatusVariant (required)
- `children`: React.ReactNode (required)
- `className`: string (optional)
- `size`: 'sm' | 'md' (optional, default: 'md')

---

### 2. KPICard

**Purpose:** Display key performance indicators and metrics

**Usage:**
```tsx
import { KPICard } from './components/onyx/KPICard';
import { Activity } from 'lucide-react';

<KPICard
  label="Controller Load"
  value="73%"
  trend="up"
  trendValue="+5% vs avg"
  icon={<Activity className="w-4 h-4" />}
/>

<KPICard
  label="Threat Level"
  value="Elevated"
  status="warning"
  statusText="Level 3"
  icon={<AlertOctagon className="w-4 h-4" />}
/>
```

**Props:**
- `label`: string (required) - KPI label
- `value`: string | number (required) - KPI value
- `status`: StatusVariant (optional) - Status chip variant
- `statusText`: string (optional) - Status chip text
- `trend`: 'up' | 'down' | 'neutral' (optional) - Trend indicator
- `trendValue`: string (optional) - Trend description
- `className`: string (optional)
- `icon`: React.ReactNode (optional) - Icon element

---

### 3. SectionContainer

**Purpose:** Wrapper for content sections with optional title and actions

**Usage:**
```tsx
import { SectionContainer } from './components/onyx/SectionContainer';

<SectionContainer 
  title="Intelligence Feed" 
  subtitle="Live threat awareness"
  action={<OnyxButton size="sm">View All</OnyxButton>}
>
  {/* Content */}
</SectionContainer>

<SectionContainer noPadding>
  {/* Content without padding */}
</SectionContainer>
```

**Props:**
- `title`: string (optional) - Section title
- `subtitle`: string (optional) - Section subtitle
- `action`: React.ReactNode (optional) - Action element (button, etc.)
- `children`: React.ReactNode (required) - Section content
- `className`: string (optional)
- `noPadding`: boolean (optional, default: false)

---

### 4. OnyxButton

**Purpose:** Primary action buttons with consistent styling

**Variants:** `primary`, `secondary`, `tertiary`, `danger`

**Sizes:** `sm`, `md`, `lg`

**Usage:**
```tsx
import { OnyxButton } from './components/onyx/OnyxButton';
import { Zap, Database } from 'lucide-react';

<OnyxButton variant="primary" size="lg">
  <Zap className="w-4 h-4" />
  Generate Dispatch
</OnyxButton>

<OnyxButton variant="secondary" size="sm">
  <Database className="w-4 h-4" />
  Load Intel
</OnyxButton>

<OnyxButton variant="tertiary">Cancel</OnyxButton>

<OnyxButton variant="danger">Delete</OnyxButton>
```

**Props:**
- `variant`: 'primary' | 'secondary' | 'tertiary' | 'danger' (optional, default: 'secondary')
- `size`: 'sm' | 'md' | 'lg' (optional, default: 'md')
- `children`: React.ReactNode (required)
- `className`: string (optional)
- All standard button HTML attributes

**Design Notes:**
- Primary: Use for main actions (max 1 per section)
- Secondary: Standard actions and controls
- Tertiary: Low-emphasis actions, inline links
- Danger: Destructive actions

---

### 5. MetricBand

**Purpose:** Horizontal metric display for summary data

**Usage:**
```tsx
import { MetricBand } from './components/onyx/MetricBand';

<MetricBand
  metrics={[
    { label: 'Decisions', value: 1247 },
    { label: 'Executed', value: 1139 },
    { label: 'Denied', value: 89 },
    { label: 'Pending', value: 19 },
  ]}
/>

<MetricBand
  metrics={[
    { label: 'Uptime', value: '99.97', unit: '%' },
    { label: 'Throughput', value: '847', unit: 'ops/min' },
    { label: 'Latency', value: '12', unit: 'ms' },
  ]}
/>
```

**Props:**
- `metrics`: Array of { label: string, value: string | number, unit?: string }
- `className`: string (optional)

---

### 6. ControlGroup

**Purpose:** Group related controls with a title

**Usage:**
```tsx
import { ControlGroup } from './components/onyx/ControlGroup';

<ControlGroup title="Ingest & Source Operations">
  <div className="grid grid-cols-2 gap-3">
    <OnyxSelect placeholder="Select Source" options={...} />
    <OnyxInput placeholder="Enter URL" />
  </div>
</ControlGroup>
```

**Props:**
- `title`: string (required) - Group title
- `children`: React.ReactNode (required) - Group content
- `className`: string (optional)

---

### 7. IntelligencePanel

**Purpose:** Scrollable feed of intelligence items

**Usage:**
```tsx
import { IntelligencePanel, IntelligenceItem } from './components/onyx/IntelligencePanel';

const items: IntelligenceItem[] = [
  {
    id: '1',
    title: 'Elevated threat activity detected in Grid Sector 7-B',
    source: 'ThreatStream',
    timestamp: '14:32 GMT',
    priority: 'critical',
    priorityLabel: 'Critical',
    category: 'Physical Security'
  },
  // ... more items
];

<IntelligencePanel items={items} maxHeight="600px" />
```

**Props:**
- `items`: IntelligenceItem[] (required)
- `maxHeight`: string (optional, default: '400px')
- `className`: string (optional)

**IntelligenceItem Interface:**
```tsx
{
  id: string;
  title: string;
  source: string;
  timestamp: string;
  priority: StatusVariant;
  priorityLabel: string;
  category?: string;
}
```

---

### 8. DataTable

**Purpose:** Tabular data display with consistent styling

**Usage:**
```tsx
import { DataTable } from './components/onyx/DataTable';

<DataTable
  columns={[
    { key: 'event', label: 'Event Type', width: '40%' },
    { key: 'status', label: 'Status', width: '20%' },
    { key: 'duration', label: 'Duration', width: '20%' },
    { key: 'timestamp', label: 'Time', width: '20%' },
  ]}
  data={[
    { event: 'Live Feed Poll', status: <StatusChip>Success</StatusChip>, duration: '142ms', timestamp: '14:35:22' },
    // ... more rows
  ]}
/>
```

**Props:**
- `columns`: Array of { key: string, label: string, width?: string }
- `data`: Array of objects matching column keys
- `className`: string (optional)

---

### 9. OnyxSelect

**Purpose:** Dropdown select control

**Usage:**
```tsx
import { OnyxSelect } from './components/onyx/OnyxSelect';

<OnyxSelect
  options={[
    { value: 'threatstream', label: 'ThreatStream API' },
    { value: 'osint', label: 'OSINT Monitor' },
    { value: 'fusion', label: 'Intel Fusion' },
  ]}
  placeholder="Select Feed Source"
  onChange={(e) => console.log(e.target.value)}
/>
```

**Props:**
- `options`: Array of { value: string, label: string }
- `placeholder`: string (optional)
- `className`: string (optional)
- All standard select HTML attributes

---

### 10. OnyxInput

**Purpose:** Text input control

**Usage:**
```tsx
import { OnyxInput } from './components/onyx/OnyxInput';

<OnyxInput placeholder="Enter URL or endpoint" />
<OnyxInput type="password" placeholder="API Key" />
```

**Props:**
- `placeholder`: string (optional)
- `className`: string (optional)
- All standard input HTML attributes

---

### 11. LiveIndicator

**Purpose:** Animated indicator for live/real-time status

**Usage:**
```tsx
import { LiveIndicator } from './components/onyx/LiveIndicator';

<LiveIndicator />
```

**No props** - displays "Live" with pulsing green dot

---

## Layout Patterns

### Page Header Pattern

```tsx
<header className="border-b border-[var(--onyx-border-default)] bg-[var(--onyx-bg-secondary)]">
  <div className="px-8 py-5">
    <div className="flex items-start justify-between gap-8 mb-5">
      <div>
        <div className="flex items-center gap-3 mb-2">
          <Shield className="w-7 h-7 text-[var(--onyx-accent-primary)]" />
          <h1>Page Title</h1>
        </div>
        <div className="flex items-center gap-3 text-sm text-[var(--onyx-text-tertiary)]">
          <LiveIndicator />
          <span>Metadata</span>
        </div>
      </div>
      <div className="flex items-center gap-2">
        {/* Actions */}
      </div>
    </div>
  </div>
</header>
```

### Grid Layouts

**6-Column KPI Grid:**
```tsx
<div className="grid grid-cols-6 gap-4">
  <KPICard label="Metric 1" value={100} />
  <KPICard label="Metric 2" value={200} />
  {/* ... */}
</div>
```

**2-Column Content Layout:**
```tsx
<div className="grid grid-cols-3 gap-6">
  <div className="col-span-2">
    {/* Main content */}
  </div>
  <div>
    {/* Sidebar */}
  </div>
</div>
```

### Spacing Guidelines

- Container padding: `px-8` (32px)
- Section margin: `mb-6` (24px)
- Card gap: `gap-4` (16px) or `gap-6` (24px)
- Internal padding: `p-5` or `p-6` (20px or 24px)
- Tight spacing: `gap-2` or `gap-3` (8px or 12px)

---

## Usage Guidelines

### Color Usage

**Do:**
- Use semantic colors for status (success, warning, danger, intel)
- Use primary accent for interactive elements and key actions
- Use text hierarchy for visual importance
- Use subtle borders for separation

**Don't:**
- Don't use too many accent colors in one view
- Don't use bright colors for large surfaces
- Don't rely on color alone for critical information

### Typography Usage

**Do:**
- Use uppercase for labels and metadata (with `tracking-wide` or `tracking-widest`)
- Use tabular numbers for metrics (`tabular-nums`)
- Use clear hierarchy with h1-h4
- Use medium/semibold weights for emphasis

**Don't:**
- Don't use too many font sizes in one component
- Don't use all caps for long text
- Don't use light weights (400 or less) for small text

### Component Composition

**Do:**
- Group related controls in ControlGroup
- Use SectionContainer for logical sections
- Use KPICard for metrics summary
- Use StatusChip sparingly for key status indicators

**Don't:**
- Don't nest SectionContainers deeply
- Don't overuse status chips (they should stand out)
- Don't mix too many component styles

### Information Density

**Do:**
- Use progressive disclosure (summary → detail)
- Group dense data in tables or metric bands
- Use collapsible sections for optional data
- Provide clear visual hierarchy

**Don't:**
- Don't show everything at once
- Don't scatter related information
- Don't create long unbroken lists

---

## Complete Example: Dispatch Command Page

See `/src/app/App.tsx` for a full implementation example showing:

1. **Page Header** with title, metadata, and primary actions
2. **Command Summary** with 6-column KPI grid
3. **Control Workspace** with grouped controls
4. **Intelligence Feed** with scrollable panel
5. **System Telemetry** with data table and metrics
6. **Activity Log** with timeline items

---

## Implementation Notes

### Tailwind CSS Variables

All ONYX colors are defined as CSS custom properties and can be used with Tailwind:

```tsx
className="bg-[var(--onyx-bg-elevated)] text-[var(--onyx-text-primary)]"
```

### Icons

Recommended: **lucide-react** package

```tsx
import { Shield, Activity, AlertTriangle } from 'lucide-react';

<Shield className="w-5 h-5 text-[var(--onyx-accent-primary)]" />
```

Common sizes:
- Small icons: `w-3.5 h-3.5` or `w-4 h-4`
- Medium icons: `w-5 h-5`
- Large icons: `w-6 h-6` or `w-7 h-7`

### Shadows

Apply shadows with inline styles:

```tsx
style={{ boxShadow: 'var(--onyx-shadow-sm)' }}
style={{ boxShadow: 'var(--onyx-shadow-md)' }}
```

---

## Design Philosophy

**ONYX is designed to be:**
- **Premium**: High-quality, polished, executive-grade
- **Operational**: Built for active security environments
- **Calm**: Not flashy, not overwhelming
- **Readable**: High contrast, clear hierarchy
- **Structured**: Organized, predictable, consistent
- **Authoritative**: Professional, trustworthy, serious

**ONYX avoids:**
- Consumer SaaS aesthetics
- Excessive animations and glows
- Sci-fi gimmicks
- Finance dashboard clichés
- Visual clutter and chaos

---

## File Structure

```
/src/
  /styles/
    theme.css                         # Color system & typography
  /app/
    App.tsx                           # Example implementation
    /components/
      /onyx/
        StatusChip.tsx                # Status badges
        KPICard.tsx                   # KPI metric cards
        SectionContainer.tsx          # Section wrapper
        OnyxButton.tsx                # Button component
        MetricBand.tsx                # Horizontal metrics
        ControlGroup.tsx              # Control grouping
        IntelligencePanel.tsx         # Intelligence feed
        DataTable.tsx                 # Data table
        OnyxSelect.tsx                # Dropdown select
        OnyxInput.tsx                 # Text input
        LiveIndicator.tsx             # Live status indicator
```

---

## Getting Started

1. **Copy design system files** from the file structure above
2. **Import theme.css** in your root application
3. **Use components** by importing from `/components/onyx/`
4. **Follow color tokens** from the color system section
5. **Reference App.tsx** for layout patterns

---

## Version

ONYX Design System v1.0
Last updated: March 4, 2026

---

**For questions or contributions, refer to the original design specification at `/src/imports/onyx-design-system.md`**
