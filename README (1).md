# AssistBridge BPO

Full-stack Business Process Outsourcing platform built with **Next.js 14 App Router**, **Tailwind CSS**, and **Supabase**.

## Quick Start

### 1. Install dependencies
```bash
npm install
```

### 2. Configure environment
```bash
cp .env.local.example .env.local
```
Edit `.env.local` with your Supabase credentials:
```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### 3. Set up database
1. Create a project at https://supabase.com
2. Go to **SQL Editor** and run `supabase-schema.sql`
3. Then run `supabase-schema-addendum.sql`
4. Enable **Email Auth** under Authentication → Providers

### 4. Create demo users (Supabase Dashboard → Authentication → Users)
| Email | Password | Metadata |
|-------|----------|----------|
| admin@assistbridge.com | admin123 | `{"role":"admin"}` |
| client@demo.com | client123 | `{"role":"client"}` |
| staff@demo.com | staff123 | `{"role":"staff"}` |

### 5. Run
```bash
npm run dev
```
Open http://localhost:3000

---

## Project Structure

```
src/
├── app/
│   ├── page.tsx                    Homepage
│   ├── about/                      About page
│   ├── services/                   Services listing
│   ├── pricing/                    Pricing plans
│   ├── contact/                    Contact form
│   ├── careers/                    Job listings + application
│   ├── request-service/            Service request form
│   ├── login/ signup/              Authentication
│   ├── dashboard/
│   │   ├── admin/                  11 admin pages
│   │   ├── client/                 7 client pages
│   │   ├── staff/                  6 staff pages
│   │   └── settings/               Shared settings
│   └── api/                        13 API routes
├── components/
│   ├── layout/    Navbar, Footer, PublicLayout
│   ├── dashboard/ DashboardLayout, DashboardSidebar
│   ├── ui/        Modal, StatsCard, DataTable, Badge, GlobalSearch
│   └── notifications/ NotificationsDropdown
├── lib/
│   ├── supabase/  client.ts, server.ts, middleware.ts
│   └── utils/     formatters, badge helpers, debounce
├── hooks/         useTasks, useMessages, useClients, useStaff...
└── types/         All TypeScript interfaces
```

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Framework | Next.js 14 (App Router) |
| Styling | Tailwind CSS |
| Database | Supabase (PostgreSQL) |
| Auth | Supabase Auth |
| Storage | Supabase Storage |
| Security | Row Level Security (RLS) |
| Language | TypeScript |

## Deploy to Vercel
```bash
npx vercel --prod
```
Add the same environment variables in Vercel project settings.
