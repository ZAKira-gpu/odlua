# Propelo AI - UI Components Library

## 📦 Complete UI Components

All UI components have been created and are ready to use! This document provides an overview and usage examples.

### ✅ Base Components (Radix UI + shadcn/ui)

#### Form Controls
- **Button** - `components/ui/button.tsx`
- **Input** - `components/ui/input.tsx`
- **Textarea** - `components/ui/textarea.tsx`
- **Label** - `components/ui/label.tsx`
- **Checkbox** - `components/ui/checkbox.tsx`
- **Radio Group** - `components/ui/radio-group.tsx`
- **Switch** - `components/ui/switch.tsx`
- **Select** - `components/ui/select.tsx`
- **Slider** - `components/ui/slider.tsx`

#### Layout
- **Card** - `components/ui/card.tsx`
- **Dialog** - `components/ui/dialog.tsx`
- **Dropdown Menu** - `components/ui/dropdown-menu.tsx`
- **Tabs** - `components/ui/tabs.tsx`
- **Separator** - `components/ui/separator.tsx`
- **Scroll Area** - `components/ui/scroll-area.tsx`

#### Feedback
- **Badge** - `components/ui/badge.tsx`
- **Alert** - `components/ui/alert.tsx`
- **Toast** - `components/ui/toast.tsx`
- **Progress** - `components/ui/progress.tsx`
- **Skeleton** - `components/ui/skeleton.tsx`
- **Spinner** - `components/ui/spinner.tsx`

#### Overlay
- **Popover** - `components/ui/popover.tsx`
- **Tooltip** - `components/ui/tooltip.tsx`

#### Navigation
- **Avatar** - `components/ui/avatar.tsx`
- **Breadcrumbs** - `components/ui/breadcrumbs.tsx`

### ✅ Advanced Components

#### Data Display
- **Data Table** - `components/ui/data-table.tsx` - Sortable, filterable table
- **Empty State** - `components/ui/empty-state.tsx` - Show when no data
- **Pagination** - `components/ui/pagination.tsx` - Navigate through pages

#### Custom Components
- **Tag Input** - `components/ui/tag-input.tsx` - Multi-tag input
- **Command** - `components/ui/command.tsx` - Command palette/search
- **Form & Form Field** - `components/ui/form.tsx` - Form wrapper with validation

### ✅ Propelo-Specific Components

#### Business Logic Components
- **Status Badge** - `components/ui/status-badge.tsx`
  - Shows proposal status (Draft, Sent, Opened, Accepted, Rejected)
  
- **Insight Card** - `components/ui/insight-card.tsx`
  - Display job insights with icons and importance levels
  
- **Proposal Card** - `components/ui/proposal-card.tsx`
  - Complete proposal card with actions, stats, and status
  
- **Stat Card** - `components/ui/stat-card.tsx`
  - Statistics display with trends and icons
  
- **Pricing Card** - `components/ui/pricing-card.tsx`
  - Subscription pricing plans
  
- **Usage Tracker** - `components/ui/usage-tracker.tsx`
  - Track proposal usage with progress bar and warnings

#### Layout Components
- **Page Header** - `components/ui/page-layout.tsx`
  - Page title, description, and actions
  
- **Section** - `components/ui/page-layout.tsx`
  - Content sections with titles
  
- **Page Container** - `components/ui/page-layout.tsx`
  - Main content wrapper

#### Animation Components
- **FadeIn** - `components/ui/animations.tsx`
- **SlideIn** - `components/ui/animations.tsx`
- **ScaleIn** - `components/ui/animations.tsx`
- **StaggerChildren** - `components/ui/animations.tsx`

## 📝 Usage Examples

### Status Badge
\`\`\`tsx
import { StatusBadge } from "@/components/ui/status-badge";

<StatusBadge status="accepted" />
\`\`\`

### Insight Card
\`\`\`tsx
import { InsightCard, InsightsPanel } from "@/components/ui/insight-card";

<InsightsPanel insights={jobInsights} />
\`\`\`

### Proposal Card
\`\`\`tsx
import { ProposalCard } from "@/components/ui/proposal-card";

<ProposalCard
  proposal={proposal}
  onView={handleView}
  onDelete={handleDelete}
  onDuplicate={handleDuplicate}
  selected={selectedId === proposal.id}
/>
\`\`\`

### Stat Card
\`\`\`tsx
import { StatCard, StatsGrid } from "@/components/ui/stat-card";
import { FileText, Eye, CheckCircle, TrendingUp } from "lucide-react";

const stats = [
  {
    title: "Total Proposals",
    value: 156,
    icon: FileText,
    trend: { value: 12, isPositive: true },
  },
  {
    title: "Total Views",
    value: 892,
    icon: Eye,
    trend: { value: 8, isPositive: true },
  },
];

<StatsGrid stats={stats} />
\`\`\`

### Form with Validation
\`\`\`tsx
import { Form, FormField } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

<Form onSubmit={handleSubmit}>
  <FormField
    label="Job Title"
    required
    error={errors.title}
    hint="Enter the job posting title"
  >
    <Input placeholder="e.g. React Developer" />
  </FormField>
  
  <Button type="submit">Generate Proposal</Button>
</Form>
\`\`\`

### Page Layout
\`\`\`tsx
import { PageContainer, PageHeader, Section } from "@/components/ui/page-layout";
import { Breadcrumbs } from "@/components/ui/breadcrumbs";
import { Button } from "@/components/ui/button";

<PageContainer>
  <PageHeader
    title="Proposal History"
    description="View and manage all your proposals"
    breadcrumbs={
      <Breadcrumbs items={[
        { label: "Dashboard", href: "/dashboard" },
        { label: "History" }
      ]} />
    }
    actions={
      <Button>New Proposal</Button>
    }
  />
  
  <Section title="Recent Proposals">
    {/* Content */}
  </Section>
</PageContainer>
\`\`\`

### Animations
\`\`\`tsx
import { FadeIn, SlideIn, StaggerChildren } from "@/components/ui/animations";

<FadeIn delay={0.1}>
  <Card>Content appears with fade</Card>
</FadeIn>

<SlideIn direction="left" delay={0.2}>
  <Card>Content slides from left</Card>
</SlideIn>

<StaggerChildren staggerDelay={0.1}>
  {items.map((item) => (
    <motion.div variants={staggerChildVariants} key={item.id}>
      <Card>{item.content}</Card>
    </motion.div>
  ))}
</StaggerChildren>
\`\`\`

### Usage Tracker
\`\`\`tsx
import { UsageTracker } from "@/components/ui/usage-tracker";

<UsageTracker
  used={user.proposalsUsed}
  limit={user.proposalsLimit}
  label="Proposals"
  upgradeLink="/dashboard/subscription"
/>
\`\`\`

### Data Table
\`\`\`tsx
import { DataTable } from "@/components/ui/data-table";

const columns = [
  {
    key: "title",
    header: "Title",
    cell: (row) => <span className="font-medium">{row.title}</span>,
  },
  {
    key: "status",
    header: "Status",
    cell: (row) => <StatusBadge status={row.status} />,
    align: "center" as const,
  },
];

<DataTable data={proposals} columns={columns} loading={isLoading} />
\`\`\`

## 🎨 Styling

All components use:
- **Tailwind CSS** for styling
- **CSS variables** for theming
- **Propelo brand colors** (#0EA5E9 primary, #0369A1 secondary)
- **Responsive design** by default
- **Dark mode ready** (when implemented)

## 📦 Dependencies Installed

The following Radix UI packages have been added:
- @radix-ui/react-avatar
- @radix-ui/react-checkbox
- @radix-ui/react-dialog
- @radix-ui/react-dropdown-menu
- @radix-ui/react-label
- @radix-ui/react-popover
- @radix-ui/react-progress
- @radix-ui/react-radio-group
- @radix-ui/react-scroll-area
- @radix-ui/react-select
- @radix-ui/react-separator
- @radix-ui/react-slider
- @radix-ui/react-switch
- @radix-ui/react-tabs
- @radix-ui/react-toast
- @radix-ui/react-tooltip

Plus: cmdk (for Command component) and framer-motion (for animations)

## 🚀 Next Steps

Now you can:
1. Build dashboard pages using these components
2. Create the proposal generator UI
3. Build the proposal history page
4. Create the analytics dashboard
5. Build authentication pages

All components are production-ready and follow best practices for accessibility, performance, and maintainability!
