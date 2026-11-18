import type { Metadata } from 'next';
import { Header, LinkButton } from '@/components/ui';

export const metadata: Metadata = { title: 'Страница недоступна' };
export default function NotFound() {
  return (
    <>
      <Header />
      <main id="main" className="container stack">
        <h1>Страница недоступна</h1>
        <p>Ссылка не найдена или публикация отозвана</p>
        <LinkButton href="/">На главную</LinkButton>
      </main>
    </>
  );
}
