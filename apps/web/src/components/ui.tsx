import Link from 'next/link';
import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from 'react';
export type ButtonVariant = 'primary' | 'secondary' | 'quiet' | 'danger';
export function Button({
  variant = 'primary',
  className = '',
  type = 'button',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant }) {
  return <button type={type} className={`button ${variant} ${className}`} {...props} />;
}
export function LinkButton({
  href,
  children,
  variant = 'secondary',
  className = '',
}: {
  href: string;
  children: ReactNode;
  variant?: ButtonVariant;
  className?: string;
}) {
  return (
    <Link className={`button ${variant} ${className}`} href={href}>
      {children}
    </Link>
  );
}
export function Field({
  label,
  textarea = false,
  helper,
  ...props
}: Omit<InputHTMLAttributes<HTMLInputElement>, 'onChange'> & {
  label: string;
  textarea?: boolean;
  helper?: string;
  onChange?: (event: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
}) {
  return (
    <label className="field">
      <span>{label}</span>
      {textarea ? (
        <textarea {...(props as React.TextareaHTMLAttributes<HTMLTextAreaElement>)} />
      ) : (
        <input {...props} />
      )}{' '}
      {helper && <small className="muted">{helper}</small>}
    </label>
  );
}
export function Icon({ name, size = 24 }: { name: string; size?: number }) {
  return (
    <span className="icon" style={{ width: size, height: size }} aria-hidden="true">
      <img src={`/icons/lucide/${name}.svg`} alt="" width={size} height={size} />
    </span>
  );
}
export function TechnologyBadges({ items }: { items: string[] }) {
  return (
    <div className="badges">
      {items.map((item, i) => {
        const key = item.toLowerCase();
        return (
          <span className="badge" key={item + i}>
            {['flutter', 'dart', 'react', 'typescript'].includes(key) && (
              <span className="technology-icon">
                <img src={`/icons/technology/${key}.svg`} alt="" width={18} height={18} />
              </span>
            )}
            {item}
          </span>
        );
      })}
    </div>
  );
}
export function Header({
  context = 'marketing',
  links,
  actions,
}: {
  context?: 'marketing' | 'auth' | 'workspace' | 'public';
  links?: { label: string; href: string }[];
  actions?: ReactNode;
}) {
  const nav =
    links ??
    (context === 'marketing'
      ? [
          { href: '/#features', label: 'Возможности' },
          { href: '/download', label: 'Приложение' },
        ]
      : context === 'auth'
        ? [{ href: '/', label: 'На главную' }]
        : []);
  return (
    <header className="web-header">
      <div className="header-primary">
        <Link className="brand" href="/" aria-label="StackCard — на главную">
          <span className="wordmark">
            <img
              className="brand-dark"
              src="/branding/stackcard-v2-wordmark-accent.svg"
              alt="StackCard"
            />
            <img
              className="brand-light"
              src="/branding/stackcard-v2-wordmark-ink.svg"
              alt="StackCard"
            />
          </span>
        </Link>
        {context === 'marketing' && <LinkButton href="/sign-in">Войти</LinkButton>}
        {actions}
      </div>
      {nav.length > 0 && (
        <nav className="header-navigation" aria-label="Главная навигация">
          {nav.map((n) => (
            <Link className="button quiet" key={n.href} href={n.href}>
              {n.label}
            </Link>
          ))}
        </nav>
      )}
    </header>
  );
}
export function Notice({ children, error = false }: { children: ReactNode; error?: boolean }) {
  return (
    <p className={`notice ${error ? 'error' : ''}`} role={error ? 'alert' : 'status'}>
      {children}
    </p>
  );
}
