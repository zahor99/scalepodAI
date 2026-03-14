import { auth } from 'thepopebot/auth';
import { RunnersPage } from 'thepopebot/chat';

export default async function RunnersRoute() {
  const session = await auth();
  return <RunnersPage session={session} />;
}
