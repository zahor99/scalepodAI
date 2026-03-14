import { redirect } from 'next/navigation';

export default function ClustersRoot() {
  redirect('/clusters/list');
}
