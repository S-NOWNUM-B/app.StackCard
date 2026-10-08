'use client';
import { Button, Header } from '@/components/ui';
export default function ErrorPage({ reset }: { reset: () => void }) {
  return (
    <>
      <Header />
      <main id="main" className="container stack">
        <h1>Не удалось загрузить страницу</h1>
        <p>Проверьте подключение и повторите попытку.</p>
        <Button onClick={reset}>Повторить</Button>
      </main>
    </>
  );
}
