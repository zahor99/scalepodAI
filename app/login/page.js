import { getPageAuthState } from 'thepopebot/auth';
import { AsciiLogo, SetupForm, LoginForm } from 'thepopebot/auth/components';

export default async function LoginPage() {
  const { needsSetup } = await getPageAuthState();

  return (
    <main className="min-h-screen flex flex-col items-center justify-center p-8">
      <AsciiLogo />
      {needsSetup ? <SetupForm /> : <LoginForm />}
    </main>
  );
}
