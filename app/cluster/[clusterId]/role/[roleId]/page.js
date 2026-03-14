import { auth } from 'thepopebot/auth';
import { ClusterPage } from 'thepopebot/cluster';

export default async function ClusterRoleRoute({ params }) {
  const session = await auth();
  const { clusterId, roleId } = await params;
  return <ClusterPage session={session} clusterId={clusterId} roleId={roleId} />;
}
