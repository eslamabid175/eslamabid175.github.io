# Copilot Instructions for Portfolio Website

## Project Overview
This is a **static portfolio website** for Eslam Aped, a Flutter/Backend Developer. It's hosted on GitHub Pages at `eslamabid175.github.io`. The site showcases professional experience, projects, and resume using vanilla HTML/CSS/JS.

## Architecture

### File Structure
- **Root HTML pages**: `index.html` (home), `projects.html`, `resume.html`, `contact.html`
- **Styling**: Single CSS file at `css/styles.css` (Bootstrap 5.2.3 + custom styles)
- **Assets**: `assets/` contains `profile.png`, `favicon.png`, resume files, and project screenshots
- **Resume**: `Eslam-Abed-Flutter-Developer-Resume.html` and `.pdf` versions in `assets/resume/`

### Key Dependencies (CDN-loaded)
- Bootstrap 5.2.3 (bundled in `styles.css`)
- Bootstrap Icons 1.8.1
- Plus Jakarta Sans font (Google Fonts)
- AOS (Animate On Scroll) library

## Design System

### Color Palette
```css
--bs-primary: #1e30f3    /* Blue - primary brand color */
--bs-secondary: #e21e80  /* Pink - accent color */
```
Gradient: `linear-gradient(135deg, #1e30f3 0%, #e21e80 100%)`

### Common CSS Classes
- `.gradient-text` - Blue-to-pink gradient text effect
- `.bg-gradient-primary-to-secondary` - Gradient background
- `.feature-card`, `.project-card` - Card components with hover effects
- `.tech-badge`, `.skill-tag` - Small pill-style labels
- `.floating` - Floating animation keyframe

## Conventions

### HTML Structure
- All pages use consistent `<head>` with meta tags, favicon, fonts, and Bootstrap icons CDN
- Navigation is inline in each HTML file (no templating system)
- Use Bootstrap grid classes (`container`, `row`, `col-*`) for layout
- Use `data-aos` attributes for scroll animations

### Adding New Content
1. **New project**: Add to `projects.html` using existing `.project-card` structure
2. **Screenshots**: Place in `assets/screenshots/{company}/{app}/` following existing pattern
3. **Resume updates**: Update both `.html` and `.md` versions in `assets/resume/`

### Styling Patterns
- Custom styles are added inline in `<style>` blocks within HTML files
- Prefer extending Bootstrap utilities over writing new CSS
- Hover effects use `transform: translateY(-Xpx)` and `box-shadow` transitions
- Border-radius: 16px for cards, 25px for buttons/pills

## Development Workflow

### Local Development
```bash
# Simple HTTP server (no build step required)
python -m http.server 8000
# Or use VS Code Live Server extension
```

### Deployment
Push to `main` branch → GitHub Pages automatically deploys

### Testing
- Test all pages at different viewport widths (responsive design)
- Verify all external links (App Store, Play Store, LinkedIn, etc.)
- Check AOS animations load correctly

## Important Notes
- **No JavaScript framework** - This is a static site with minimal JS
- **No build process** - Files are served as-is
- Keep resume synced between HTML and Markdown versions
- Screenshots are organized by company: `cogens/`, `3i-vision/`, `freelance/`
