import { auth } from 'thepopebot/auth';
import { ClusterConsolePage } from 'thepopebot/cluster';

export default async function ClusterConsoleRoute({ params }) {
  const session = await auth();
  const { clusterId } = await params;
  return <ClusterConsolePage session={session} clusterId={clusterId} />;
}
