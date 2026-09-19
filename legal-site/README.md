# Legal site (Vercel)

Static Terms of Use and Privacy Policy for Scanella. Vercel should deploy
**only this folder**, not the Flutter app.

After deploy, the pages are:

- https://canela.vercel.app
- https://canela.vercel.app/terms
- https://canela.vercel.app/privacy

(If `canela` is taken, name the Vercel project `scanella` instead.)

## Deploy only these files

1. Push this repo (the `legal-site/` folder is already on GitHub).
2. Open [vercel.com](https://vercel.com) and sign in with GitHub.
3. **Add New… → Project** and import **`rakpa/scan2`**.
4. Before you click Deploy, set:
   - **Project Name:** `canela` (this makes `canela.vercel.app`)
   - **Framework Preset:** Other
   - **Root Directory:** `legal-site`  ← this is the important one
   - Leave Build Command and Output Directory empty
5. Click **Deploy**.

Vercel will publish only `legal-site/`. It will not build Flutter.

Later pushes to `main` that change files inside `legal-site/` will auto-update
the site. Changes to the iOS/Android app do not affect it.

## If you want a separate GitHub repo instead

1. Create a new empty GitHub repo (for example `canela-legal`).
2. Copy only the files in this folder into that repo (not the Flutter app).
3. Import that repo on Vercel. Root Directory can stay `.`

## App Store / Play Console

Use these URLs in the store forms:

- Privacy Policy: `https://canela.vercel.app/privacy`
- Terms of Use: `https://canela.vercel.app/terms`
- Support email: `support@scanella.com`

## Store badges

`app-store-badge.svg` is Apple's own artwork. The Google Play badge is not in
the repo yet: download the English badge from
<https://play.google.com/intl/en_us/badges> and save it as
`google-play-badge.png` here. It then appears next to the App Store badge with
no code change — until it exists, an `onerror` on the `<img>` removes it so the
page never shows a broken image.

Neither store allows a redrawn badge, so use their supplied files unmodified.
Neither badge is a link yet; wrap each in an `<a>` once the listings are live.

The support address also appears in the footer of every page here, in the
Privacy "Questions" and Terms "Contact" sections, and in the app (Settings →
Contact support, Help → Still stuck, About). It is defined once in
`lib/core/branding.dart` as `AppIdentity.supportEmail`; change it there and in
these three pages together.
