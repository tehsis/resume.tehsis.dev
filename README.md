# Pablo Terradillos Resume

Static resume website generated from `Pablo Terradillos - Resume.md`.

## Preview locally

Open `index.html` directly in a browser, or run a local static file server:

```sh
python3 -m http.server 8000
```

Then visit <http://localhost:8000>.

No server-side backend, build step, or package dependencies are required.

## Update the HTML

Regenerate `index.html` from `Pablo Terradillos - Resume.md` with:

```sh
./update-html.sh
```

The script requires Node.js.

## Update the PDF

Regenerate `Pablo Terradillos - Resume.pdf` from `index.html` with:

```sh
./update-pdf.sh
```

The script requires Google Chrome at `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`.

## Deployment

GitHub Pages is configured through `.github/workflows/pages.yml` and publishes the repository root on pushes to `main`.

The custom domain is configured in `CNAME` as `resume.tehsis.dev`.
