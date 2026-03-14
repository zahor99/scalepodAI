import { auth } from 'thepopebot/auth';
import { PullRequestsPage } from 'thepopebot/chat';

export default async function PullRequestsRoute() {
  const session = await auth();
  return <PullRequestsPage session={session} />;
}
