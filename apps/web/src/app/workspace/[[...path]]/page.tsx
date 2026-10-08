import { Workspace } from '@/components/workspace';
export const metadata = {
  title: 'Рабочая область',
  robots: { index: false, follow: false },
};
export default async function WorkspacePage({ params }: { params: Promise<{ path?: string[] }> }) {
  const { path } = await params;
  return <Workspace initialView={path?.join('/') ?? 'home'} />;
}
