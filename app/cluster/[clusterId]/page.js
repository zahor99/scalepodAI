import { auth } from 'thepopebot/auth';
import { ClusterPage } from 'thepopebot/cluster';

export default async function ClusterRoute({ params }) {
  const session = await auth();
  const { clusterId } = await params;
  return <ClusterPage session={session} clusterId={clusterId} />;
}
