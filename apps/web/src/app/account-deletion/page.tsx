import type { Metadata } from 'next';
import { AccountDeletionRecovery } from '@/components/account-settings';
import { Header } from '@/components/ui';

export const metadata: Metadata = {
  title: 'Удаление аккаунта | StackCard',
  robots: { index: false, follow: false },
};

export default function AccountDeletionPage() {
  return (
    <>
      <Header context="auth" />
      <main id="main" className="auth-container stack">
        <AccountDeletionRecovery />
      </main>
    </>
  );
}
