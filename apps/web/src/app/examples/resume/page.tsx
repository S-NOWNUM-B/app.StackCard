import { permanentRedirect } from 'next/navigation';

// Отдельного резюме больше нет (ADR 0005): старый адрес ведёт на пример основного портфолио и PDF.
export default function ExampleResumePage() {
  permanentRedirect('/examples/portfolio#pdf');
}
