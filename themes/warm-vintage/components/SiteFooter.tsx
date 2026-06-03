import { QuartzComponent, QuartzComponentConstructor, QuartzComponentProps } from "./types"
import { siteConfig } from "../util/siteConfig"
// @ts-ignore
import style from "./styles/siteFooter.scss"

export default (() => {
  const SiteFooter: QuartzComponent = ({ cfg }: QuartzComponentProps) => {
    const year      = new Date().getFullYear()
    const copyright = siteConfig.copyright ?? `© ${year} ${cfg?.configuration?.pageTitle ?? ""}`
    const instagram = siteConfig.instagram || null
    const ebay      = siteConfig.ebay || null
    const etsy      = siteConfig.etsy || null

    return (
      <footer class="site-footer">
        <p class="site-footer-copy">{copyright}</p>
        {(instagram || ebay || etsy) && (
          <ul class="site-footer-links">
            {instagram && (
              <li>
                <a href={`https://instagram.com/${instagram}`} target="_blank" rel="noopener noreferrer">
                  Instagram
                </a>
              </li>
            )}
            {ebay && (
              <li>
                <a href={`https://ebay.ca/usr/${ebay}`} target="_blank" rel="noopener noreferrer">
                  eBay
                </a>
              </li>
            )}
            {etsy && (
              <li>
                <a href={`https://etsy.com/shop/${etsy}`} target="_blank" rel="noopener noreferrer">
                  Etsy
                </a>
              </li>
            )}
          </ul>
        )}
      </footer>
    )
  }

  SiteFooter.css = style
  return SiteFooter
}) satisfies QuartzComponentConstructor
