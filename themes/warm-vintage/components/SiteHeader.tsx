import { QuartzComponent, QuartzComponentConstructor, QuartzComponentProps } from "./types"
import { siteConfig } from "../util/siteConfig"
import { pathToRoot } from "../util/path"
// @ts-ignore
import style from "./styles/siteHeader.scss"

export default (() => {
  const SiteHeader: QuartzComponent = ({ cfg, fileData }: QuartzComponentProps) => {
    const title       = cfg?.configuration?.pageTitle ?? "Precious Finds"
    const logoHref    = pathToRoot(fileData.slug!)
    const pageCaption = fileData.frontmatter?.caption
    const tagline     = pageCaption ? String(pageCaption) : (siteConfig.tagline ?? null)

    return (
      <div class="site-header-wrap">
        <div class="site-header-bar">
          <div class="site-header-left" />
          <div class="site-header-center">
            <a href={logoHref} class="site-header-logo">
              {title}
              <span class="site-header-tld">.ca</span>
            </a>
            {tagline && <div class="site-header-tagline">{tagline}</div>}
          </div>
          <div class="site-header-right">
            <button class="site-header-icon-btn" aria-label="Search" data-shop-search="1">
              🔍
            </button>
            <button class="site-header-icon-btn" aria-label="Toggle dark mode" data-shop-darkmode="1">
              <span data-darkmode-icon="1">🌙</span>
            </button>
          </div>
        </div>
      </div>
    )
  }

  SiteHeader.css = style

  SiteHeader.afterDOMLoaded = `
    function initSiteHeader() {
      const dmBtn     = document.querySelector('[data-shop-darkmode]')
      const dmIcon    = document.querySelector('[data-darkmode-icon]')
      const searchBtn = document.querySelector('[data-shop-search]')

      function syncDarkmode() {
        const dark = document.documentElement.getAttribute('saved-theme') === 'dark'
        if (dmIcon) dmIcon.textContent = dark ? '☀️' : '🌙'
      }

      dmBtn?.addEventListener('click', () => {
        const cur  = document.documentElement.getAttribute('saved-theme') ?? 'light'
        const next = cur === 'dark' ? 'light' : 'dark'
        document.documentElement.setAttribute('saved-theme', next)
        localStorage.setItem('theme', next)
        window.dispatchEvent(new CustomEvent('themechange', { detail: { theme: next } }))
        syncDarkmode()
      })

      window.addEventListener('themechange', syncDarkmode)
      window.addCleanup?.(() => window.removeEventListener('themechange', syncDarkmode))

      searchBtn?.addEventListener('click', () => {
        document.querySelector('.search button')?.click()
      })

      syncDarkmode()
    }

    document.addEventListener('nav', initSiteHeader)
    initSiteHeader()
  `

  return SiteHeader
}) satisfies QuartzComponentConstructor
