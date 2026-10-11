import React from 'react';
import type { Styles } from '@react-pdf/renderer';
import {
  mainPortfolioSectionOrder,
  type DocumentContent,
  type MainPortfolioSectionKind,
} from './model';
import { safePublicHref } from './public-document';

export type PortfolioPdfAssets = {
  regularFont: string;
  boldFont: string;
  stockIconSvg: Record<string, string>;
  avatarBytes?: Uint8Array;
};

const iconIds = new Set([
  'folder',
  'file-text',
  'panels-top-left',
  'home',
  'image',
  'camera',
  'user-round',
]);
type PdfStyle = Styles[string];
type PdfRenderer = typeof import('@react-pdf/renderer');
const body: PdfStyle = { fontSize: 11, lineHeight: 1.55, marginBottom: 8 };
const heading: PdfStyle = { fontSize: 15, fontWeight: 700, marginTop: 16, marginBottom: 8 };
const centered: PdfStyle = { ...body, textAlign: 'center' };

function jpegDataUri(bytes: Uint8Array): string {
  let binary = '';
  for (let offset = 0; offset < bytes.length; offset += 8192) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 8192));
  }
  return `data:image/jpeg;base64,${btoa(binary)}`;
}

// Разбираются только geometry primitives из семи собственных pinned assets.
// Пользовательский SVG/HTML или URL сюда не передаются.
function StockIcon({
  id,
  assets,
  renderer,
}: {
  id: string;
  assets: PortfolioPdfAssets;
  renderer: PdfRenderer;
}) {
  const { Svg, Path, Circle, Rect } = renderer;
  const selected = iconIds.has(id) ? id : 'folder';
  const source = assets.stockIconSvg[selected] ?? assets.stockIconSvg.folder;
  if (!source) throw new Error('Не удалось подготовить иконку проекта для PDF.');
  const shapes = [...source.matchAll(/<(path|rect|circle)\s+([^>]+)\/>/g)];
  if (!shapes.length) throw new Error('Иконка проекта имеет неподдерживаемый формат.');
  return (
    <Svg viewBox="0 0 24 24" width={20} height={20}>
      {shapes.map((match, index) => {
        const attributes = Object.fromEntries(
          [...match[2].matchAll(/([\w-]+)="([^"]*)"/g)].map((item) => [item[1], item[2]]),
        );
        const outline = {
          fill: 'none',
          stroke: '#151518',
          strokeWidth: 2,
          strokeLinecap: 'round' as const,
          strokeLinejoin: 'round' as const,
        };
        if (match[1] === 'path') return <Path key={index} d={attributes.d} {...outline} />;
        if (match[1] === 'circle')
          return (
            <Circle
              key={index}
              cx={Number(attributes.cx)}
              cy={Number(attributes.cy)}
              r={Number(attributes.r)}
              {...outline}
            />
          );
        return (
          <Rect
            key={index}
            x={Number(attributes.x ?? 0)}
            y={Number(attributes.y ?? 0)}
            width={Number(attributes.width)}
            height={Number(attributes.height)}
            rx={Number(attributes.rx ?? 0)}
            ry={Number(attributes.ry ?? attributes.rx ?? 0)}
            {...outline}
          />
        );
      })}
    </Svg>
  );
}

export async function createPortfolioPdfDocument(
  content: DocumentContent,
  assets: PortfolioPdfAssets,
) {
  const renderer = await import('@react-pdf/renderer');
  const { Document, Font, Image, Link, Page, Text, View } = renderer;
  Font.register({
    family: 'StackCardManrope',
    fonts: [
      { src: assets.regularFont, fontWeight: 400 },
      { src: assets.boldFont, fontWeight: 700 },
    ],
  });
  Font.registerHyphenationCallback((word) => [word]);
  const visible = new Set(
    content.blocks.filter((block) => block.visible).map((block) => block.kind),
  );
  const profile = content.profile;
  const projects = visible.has('featuredProjects') ? content.projects.filter((p) => p.visible) : [];
  const skills = visible.has('skills') ? content.skills.filter((s) => s.name.trim()) : [];
  const experience = visible.has('experience')
    ? content.experience.filter((e) =>
        [e.role, e.organization, e.period, e.description].some((v) => v.trim()),
      )
    : [];
  const education = visible.has('education')
    ? content.education.filter((e) =>
        [e.qualification, e.institution, e.period, e.description].some((v) => v.trim()),
      )
    : [];
  const contacts = content.links.filter(
    (l) =>
      l.visible &&
      l.publishAllowed &&
      visible.has(l.kind === 'github' ? 'github' : 'links') &&
      safePublicHref(l.url, l.kind),
  );
  const hasAvatar = visible.has('profile') && !!(profile.avatarPath || profile.avatarUrl);
  if (hasAvatar && !assets.avatarBytes?.length)
    throw new Error('Не удалось получить фотографию для PDF. Попробуйте ещё раз.');
  if (
    assets.avatarBytes?.length &&
    (assets.avatarBytes.length < 4 ||
      assets.avatarBytes[0] !== 0xff ||
      assets.avatarBytes[1] !== 0xd8 ||
      assets.avatarBytes.at(-2) !== 0xff ||
      assets.avatarBytes.at(-1) !== 0xd9)
  )
    throw new Error('Фотография имеет неподдерживаемый формат. Попробуйте выбрать её ещё раз.');
  const paragraph = (value: string, key: string, style = body) =>
    value.trim() ? (
      <Text key={key} style={style}>
        {value}
      </Text>
    ) : null;
  const title = (value: string) => (
    <Text style={heading} minPresenceAhead={40}>
      {value}
    </Text>
  );
  const href = (label: string, value: string, key: string) =>
    safePublicHref(value) ? (
      <Link
        key={key}
        src={value}
        style={{ ...body, color: '#151518', textDecoration: 'underline' }}
      >
        {label ? `${label} — ${value}` : value}
      </Link>
    ) : null;
  const sections: Record<MainPortfolioSectionKind, React.ReactNode> = {
    featuredProjects: (
      <>
        {projects.length > 0 && title('Проекты')}
        {projects.map((project) => (
          <React.Fragment key={project.id}>
            <View style={{ flexDirection: 'row', gap: 12, marginBottom: 8 }} minPresenceAhead={32}>
              <StockIcon id={project.iconId ?? 'folder'} assets={assets} renderer={renderer} />
              <Text style={{ ...body, fontWeight: 700, flex: 1, marginBottom: 0 }}>
                {project.title}
              </Text>
            </View>
            {paragraph(project.description, `${project.id}-description`)}
            {paragraph(project.contribution, `${project.id}-contribution`)}
            {paragraph(project.technologies.join(' · '), `${project.id}-technologies`)}
            {href('Проект', project.liveUrl, `${project.id}-live`)}
            {href('Исходный код', project.repositoryUrl, `${project.id}-source`)}
          </React.Fragment>
        ))}
      </>
    ),
    skills: (
      <>
        {skills.length > 0 && (
          <>
            {title('Навыки')}
            {paragraph(skills.map((s) => s.name).join(' · '), 'skills')}
          </>
        )}
      </>
    ),
    experience: (
      <>
        {experience.length > 0 && title('Опыт')}
        {experience.map((item) => (
          <React.Fragment key={item.id}>
            {paragraph(item.role, `${item.id}-role`)}
            {paragraph(
              [item.organization, item.period].filter((v) => v.trim()).join(' · '),
              `${item.id}-organization`,
            )}
            {paragraph(item.description, `${item.id}-description`)}
          </React.Fragment>
        ))}
      </>
    ),
    education: (
      <>
        {education.length > 0 && title('Образование')}
        {education.map((item) => (
          <React.Fragment key={item.id}>
            {paragraph(item.qualification, `${item.id}-qualification`)}
            {paragraph(
              [item.institution, item.period].filter((v) => v.trim()).join(' · '),
              `${item.id}-institution`,
            )}
            {paragraph(item.description, `${item.id}-description`)}
          </React.Fragment>
        ))}
      </>
    ),
    links: (
      <>
        {contacts.length > 0 && title('Контакты и ссылки')}
        {contacts.map((contact) => (
          <Link
            key={contact.id}
            src={contact.url}
            style={{ ...body, color: '#151518', textDecoration: 'underline' }}
          >
            {contact.label ? `${contact.label} — ${contact.url}` : contact.url}
          </Link>
        ))}
      </>
    ),
  };
  return (
    <Document title="Портфолио" creator="StackCard">
      <Page
        size="A4"
        wrap
        style={{ padding: 40, paddingBottom: 56, fontFamily: 'StackCardManrope', color: '#151518' }}
      >
        {visible.has('profile') && (
          <>
            {assets.avatarBytes?.length ? (
              <Image
                src={jpegDataUri(assets.avatarBytes)}
                style={{
                  width: 80,
                  height: 80,
                  borderRadius: 40,
                  alignSelf: 'center',
                  objectFit: 'cover',
                  marginBottom: 12,
                }}
              />
            ) : null}
            {paragraph(profile.name, 'name', { ...centered, fontSize: 22, fontWeight: 700 })}
            {paragraph(profile.headline, 'headline', centered)}
          </>
        )}
        {visible.has('about') && paragraph(profile.bio, 'bio', centered)}
        {visible.has('location') &&
          profile.publishLocation &&
          paragraph(profile.locationText, 'location', centered)}
        {mainPortfolioSectionOrder(content).map((kind) => (
          <React.Fragment key={kind}>{sections[kind]}</React.Fragment>
        ))}
        <Text
          fixed
          style={{ position: 'absolute', bottom: 24, right: 40, fontSize: 9, color: '#66666f' }}
          render={({ pageNumber, totalPages }) => `${pageNumber} / ${totalPages}`}
        />
      </Page>
    </Document>
  );
}

export async function renderPortfolioPdf(
  content: DocumentContent,
  assets: PortfolioPdfAssets,
): Promise<Blob> {
  const { pdf } = await import('@react-pdf/renderer');
  const blob = await pdf(await createPortfolioPdfDocument(content, assets)).toBlob();
  if (blob.type !== 'application/pdf' || blob.size === 0 || blob.size > 20 * 1024 * 1024)
    throw new Error('Не удалось создать PDF. Попробуйте ещё раз.');
  return blob;
}
