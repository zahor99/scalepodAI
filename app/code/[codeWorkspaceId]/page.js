import { auth } from 'thepopebot/auth';
import { CodePage } from 'thepopebot/code';

export default async function CodeRoute({ params }) {
  const session = await auth();
  const { codeWorkspaceId } = await params;
  return <CodePage session={session} codeWorkspaceId={codeWorkspaceId} />;
}
