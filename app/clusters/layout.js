import { auth } from 'thepopebot/auth';
import { ClustersLayout } from 'thepopebot/cluster';

export default async function Layout({ children }) {
  const session = await auth();
  return <ClustersLayout session={session}>{children}</ClustersLayout>;
}
