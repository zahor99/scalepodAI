import { auth } from 'thepopebot/auth';
import { ClusterLogsPage } from 'thepopebot/cluster';

export default async function ClusterLogsRoute({ params }) {
  const session = await auth();
  const { clusterId } = await params;
  return <ClusterLogsPage session={session} clusterId={clusterId} />;
}
