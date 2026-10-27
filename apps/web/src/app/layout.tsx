import type { Metadata } from 'next';
import Script from 'next/script';
import './globals.css';
export const metadata: Metadata = {
  title: {
    default: 'StackCard — портфолио разработчика',
    template: '%s · StackCard',
  },
  description:
    'Одно портфолио разработчика: проекты из GitHub, настоящий PDF и публикация по постоянной ссылке',
  icons: {
    icon: {
      url: '/branding/stackcard-v2-app-icon-mono-dark.svg',
      type: 'image/svg+xml',
    },
  },
  robots: { index: true, follow: true },
};
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ru" data-theme="light" data-scroll-behavior="smooth" suppressHydrationWarning>
      <body>
        <Script
          id="stackcard-preferences"
          strategy="beforeInteractive"
          dangerouslySetInnerHTML={{
            __html:
              "try{document.documentElement.dataset.reducedMotion=localStorage.getItem('stackcard.reducedMotion')==='true'?'true':'false'}catch{}",
          }}
        />
        <a className="skip-link" href="#main">
          К содержимому
        </a>
        {children}
      </body>
    </html>
  );
}
