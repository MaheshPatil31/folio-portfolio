# folio

A responsive portfolio builder with an editorial public portfolio, an owner dashboard, profile and social link editors, project management, image previews, and account settings.

## Run it

Requirements: Node.js 20 or newer and npm.

```sh
npm install
npm run dev
```

The app opens at the local Vite URL. There are no seeded or placeholder people: visitors see the product landing page, and every account gets a private, empty profile to fill in. Account creation, sign-in, profile search, uploads, and saving require the Supabase configuration below.

## Configure persistent accounts and uploads

1. Create a Supabase project.
2. Copy `.env.example` to `.env.local` and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` from the project's API settings. These are the public project URL and publishable key; never put a secret or service role key in a browser app.
3. Run `supabase/schema.sql` in the Supabase SQL editor. It creates the profiles table and signup trigger, row-level security policies, a safe public portfolio lookup, a search function that lists published profiles only, image storage policies, and a database-backed account deletion function. New accounts stay unpublished until the owner turns on their public page.
4. In Supabase Authentication settings, set the site URL and allowed redirect URLs to your local app and production domain. Configure email templates and SMTP for production email verification and password reset delivery.
5. Restart the dev server after changing environment variables.

Project and profile images are limited to 5 MB and common web image types. Authenticated uploads go to the `portfolio-images` bucket under a user-specific folder. Public pages use `get_public_portfolio`; profile search uses `search_public_profiles`. These return only published portfolio fields. Account rows can only be read directly by their owner. The dashboard uses the Supabase anon key with signed-in user sessions and does not need a service role key.

## Deploy for free

Cloudflare Pages works for this static Vite app. Push the project to a Git repository, create a Pages project from that repository, set the build command to `npm run build`, and set the output directory to `dist`. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` as build environment variables. Pages serves the SPA fallback for routes such as `/u/your-name` and `/search`. Then add the deployed domain to Supabase Authentication's site URL and allowed redirect URLs.

Supabase's free tier includes Postgres, authentication, and 1 GB of storage, but free projects pause after seven days of inactivity. It is suitable for an initial launch; check current plan limits before relying on it for continuous production traffic.

## Google sign-in later

The sign-in dialog includes a reserved Google sign-in affordance. To add the provider later, enable Google in Supabase Authentication → Providers, configure its OAuth client and redirect URL, then add a `supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: window.location.origin } })` button to `AuthDialog`. Keep the OAuth client secret in Supabase provider settings.

## Build

```sh
npm run build
npm run preview
```

For production hosting, configure the host to serve the SPA entry for `/dashboard/*` and `/u/*` paths. Use HTTPS and configure a production SMTP provider before inviting real users.
