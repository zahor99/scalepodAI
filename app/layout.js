import './globals.css';
import '../theme.css';
import { ThemeProvider, FeaturesProvider } from 'thepopebot/chat';

export const metadata = {
  title: 'ThePopeBot',
  description: 'AI Agent',
};

export const viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  viewportFit: 'cover',
};

const features = {
  codeWorkspace: !!process.env.CLAUDE_CODE_OAUTH_TOKEN,
  clusterWorkspace: !!process.env.CLAUDE_CODE_OAUTH_TOKEN,
};

export default function RootLayout({ children }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="min-h-screen bg-background text-foreground antialiased">
        <FeaturesProvider features={features}>
          <ThemeProvider>
            {children}
          </ThemeProvider>
        </FeaturesProvider>
      </body>
    </html>
  );
}
